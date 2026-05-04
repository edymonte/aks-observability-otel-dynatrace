'use strict';

// ─────────────────────────────────────────────────────────────────────────────
// OPENTELEMETRY SETUP
// Deve ser inicializado ANTES de qualquer outro require.
// O SDK configura automaticamente traces e métricas via variáveis de ambiente:
//   OTEL_EXPORTER_OTLP_ENDPOINT  → endereço do OTEL Collector HTTP (ex: http://otel-collector:4318)
//   OTEL_SERVICE_NAME            → nome lógico deste serviço no Dynatrace
//   OTEL_RESOURCE_ATTRIBUTES     → atributos extras (ex: deployment.environment=production)
// ─────────────────────────────────────────────────────────────────────────────
const { NodeSDK } = require('@opentelemetry/sdk-node');
const { getNodeAutoInstrumentations } = require('@opentelemetry/auto-instrumentations-node');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-http');
const { OTLPMetricExporter } = require('@opentelemetry/exporter-metrics-otlp-http');
const { PeriodicExportingMetricReader } = require('@opentelemetry/sdk-metrics');
const { Resource } = require('@opentelemetry/resources');
const { SEMRESATTRS_SERVICE_NAME, SEMRESATTRS_SERVICE_VERSION } = require('@opentelemetry/semantic-conventions');

const sdk = new NodeSDK({
  // Resource: identifica este serviço no Dynatrace / Jaeger / etc.
  resource: new Resource({
    [SEMRESATTRS_SERVICE_NAME]: process.env.OTEL_SERVICE_NAME || 'otel-demo-app',
    [SEMRESATTRS_SERVICE_VERSION]: '1.0.0',
    'deployment.environment': process.env.DEPLOYMENT_ENV || 'development',
  }),

  // Exporter de Traces → OTLP HTTP para o Collector (porta 4318)
  // O SDK lê OTEL_EXPORTER_OTLP_ENDPOINT automaticamente e adiciona /v1/traces.
  // NÃO passar url explícita aqui — o SDK trata url explícita como endpoint completo
  // (sem adicionar o signal path), o que quebra o envio de traces.
  traceExporter: new OTLPTraceExporter(),

  // Exporter de Métricas → OTLP HTTP para o Collector, exportando a cada 30s
  // Idem: o SDK adiciona /v1/metrics ao OTEL_EXPORTER_OTLP_ENDPOINT automaticamente.
  metricReader: new PeriodicExportingMetricReader({
    exporter: new OTLPMetricExporter(),
    exportIntervalMillis: 30_000,
  }),

  // Auto-instrumentações: HTTP, Express, gRPC, DNS, etc.
  instrumentations: [getNodeAutoInstrumentations()],
});

sdk.start();

// Graceful shutdown: garante que os dados em buffer sejam enviados antes de encerrar
process.on('SIGTERM', () => {
  sdk.shutdown().finally(() => process.exit(0));
});

// ─────────────────────────────────────────────────────────────────────────────
// APPLICATION
// ─────────────────────────────────────────────────────────────────────────────
const express = require('express');
const axios = require('axios');
const { trace, metrics, context, SpanStatusCode } = require('@opentelemetry/api');

const app = express();
const PORT = process.env.PORT || 3000;

// Tracer e Meter nomeados — boas práticas de OTEL: um tracer/meter por biblioteca/serviço
const tracer = trace.getTracer('otel-demo-app', '1.0.0');
const meter = metrics.getMeter('otel-demo-app', '1.0.0');

// ── Métricas customizadas ────────────────────────────────────────────────────

// Contador de requisições HTTP recebidas
const httpRequestCounter = meter.createCounter('http_requests_total', {
  description: 'Total number of HTTP requests received',
});

// Histograma de latência das requisições (em milissegundos)
const requestLatencyHistogram = meter.createHistogram('http_request_duration_ms', {
  description: 'HTTP request latency in milliseconds',
  unit: 'ms',
});

// Gauge para rastrear requisições em andamento
const activeRequestsGauge = meter.createUpDownCounter('http_requests_active', {
  description: 'Number of active HTTP requests being processed',
});

// ── Middleware de Observabilidade ────────────────────────────────────────────
app.use((req, res, next) => {
  const startTime = Date.now();
  activeRequestsGauge.add(1, { route: req.path });

  res.on('finish', () => {
    const durationMs = Date.now() - startTime;
    const labels = { method: req.method, route: req.path, status_code: String(res.statusCode) };

    httpRequestCounter.add(1, labels);
    requestLatencyHistogram.record(durationMs, labels);
    activeRequestsGauge.add(-1, { route: req.path });
  });

  next();
});

// ── Rotas ────────────────────────────────────────────────────────────────────

/**
 * GET /health
 * Health check usado pelo liveness/readiness probe do Kubernetes.
 * Retorna 200 OK sem criar spans adicionais para evitar ruído nos traces.
 */
app.get('/health', (_req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

/**
 * GET /
 * Rota principal. Demonstra criação manual de spans filhos e atributos semânticos.
 */
app.get('/', async (req, res) => {
  // Cria um span pai para esta operação de negócio
  const span = tracer.startSpan('handle-root-request', {
    attributes: {
      'http.method': req.method,
      'http.url': req.url,
      'user.agent': req.headers['user-agent'] || 'unknown',
    },
  });

  try {
    // Executa lógica dentro do contexto do span (propaga contexto automaticamente)
    await context.with(trace.setSpan(context.active(), span), async () => {
      await simulateProcessing(50); // latência realista
    });

    span.setStatus({ code: SpanStatusCode.OK });
    res.json({
      message: 'Observability demo running on AKS!',
      service: process.env.OTEL_SERVICE_NAME || 'otel-demo-app',
      environment: process.env.DEPLOYMENT_ENV || 'development',
    });
  } catch (err) {
    span.recordException(err);
    span.setStatus({ code: SpanStatusCode.ERROR, message: err.message });
    res.status(500).json({ error: 'Internal server error' });
  } finally {
    span.end(); // SEMPRE encerre o span para evitar memory leaks
  }
});

/**
 * GET /checkout
 * Simula um fluxo de checkout — demonstra latência de negócio rastreável no Dynatrace.
 * Mostra como spans carregam contexto de transação e como o Dynatrace correlaciona
 * latência com erros em fluxos distribuídos.
 *
 * Em produção real, axios chamaria um serviço de pagamento externo e o OTEL SDK
 * propagaria automaticamente os headers W3C TraceContext para esse serviço.
 */
app.get('/checkout', async (_req, res) => {
  const span = tracer.startSpan('checkout-operation');

  try {
    span.setAttribute('operation.type', 'checkout');
    span.setAttribute('transaction.type', 'purchase');

    // Exemplo: chamada a serviço externo com propagação de trace
    // const payment = await axios.get('http://payment-service/validate');
    // span.setAttribute('payment.service.response', payment.status);
    await simulateProcessing(300); // simula latência de chamada real

    span.setAttribute('checkout.latency_ms', 300);
    span.setStatus({ code: SpanStatusCode.OK });

    res.json({
      transaction: 'checkout',
      status: 'success',
      latencySimulation: '300ms',
    });
  } catch (err) {
    span.recordException(err);
    span.setStatus({ code: SpanStatusCode.ERROR, message: err.message });
    res.status(500).json({ error: 'Checkout failed' });
  } finally {
    span.end();
  }
});

/**
 * GET /error
 * Simula erros — demonstra como spans com erro aparecem no Dynatrace
 * e como configurar alertas de taxa de erros (error rate SLO).
 */
app.get('/error', (_req, res) => {
  const span = tracer.startSpan('error-operation');

  try {
    const err = new Error('Simulated application error for observability testing');
    err.code = 'SIMULATED_ERROR';

    // Registra a exceção no span — Dynatrace captura stack trace
    span.recordException(err);
    span.setStatus({ code: SpanStatusCode.ERROR, message: err.message });
    span.setAttribute('error.type', err.code);

    res.status(500).json({ error: err.message, code: err.code });
  } finally {
    span.end();
  }
});

/**
 * GET /chain
 * Demonstra propagação de contexto entre spans (parent → child).
 * Conceito importante: W3C Trace Context / B3 propagation.
 */
app.get('/chain', async (_req, res) => {
  const rootSpan = tracer.startSpan('chain-operation');

  await context.with(trace.setSpan(context.active(), rootSpan), async () => {
    // Span filho A
    const spanA = tracer.startSpan('step-fetch-data');
    await simulateProcessing(100);
    spanA.setAttribute('db.system', 'postgresql');
    spanA.setAttribute('db.statement', 'SELECT * FROM orders LIMIT 10');
    spanA.end();

    // Span filho B
    const spanB = tracer.startSpan('step-process-data');
    await simulateProcessing(80);
    spanB.setAttribute('records.processed', 10);
    spanB.end();

    // Span filho C
    const spanC = tracer.startSpan('step-send-response');
    await simulateProcessing(20);
    spanC.end();

    rootSpan.setStatus({ code: SpanStatusCode.OK });
    rootSpan.end();
  });

  res.json({ message: 'Chained spans completed — check Dynatrace for the full trace!' });
});

// ── Helpers ──────────────────────────────────────────────────────────────────

/** Simula I/O assíncrono (rede, banco de dados, etc.) */
function simulateProcessing(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

// ── Server Bootstrap ─────────────────────────────────────────────────────────
app.listen(PORT, () => {
  console.log(`[otel-demo-app] Listening on port ${PORT}`);
  console.log(`[otel-demo-app] OTEL Endpoint: ${process.env.OTEL_EXPORTER_OTLP_ENDPOINT || 'http://localhost:4318'}`);  // HTTP/protobuf
});
