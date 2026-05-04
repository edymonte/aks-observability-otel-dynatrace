# Observabilidade Cloud-Native — AKS + OpenTelemetry + Dynatrace

[![CI/CD Pipeline](https://github.com/edymonte/aks-observability-otel-dynatrace/actions/workflows/ci-cd.yaml/badge.svg)](https://github.com/edymonte/aks-observability-otel-dynatrace/actions/workflows/ci-cd.yaml)
![Kubernetes](https://img.shields.io/badge/Kubernetes-AKS-326CE5?logo=kubernetes&logoColor=white)
![OpenTelemetry](https://img.shields.io/badge/OpenTelemetry-Collector-000000?logo=opentelemetry&logoColor=white)
![Dynatrace](https://img.shields.io/badge/Dynatrace-OTLP-1496FF?logo=dynatrace&logoColor=white)
![Terraform](https://img.shields.io/badge/Terraform-IaC-7B42BC?logo=terraform&logoColor=white)
![Node.js](https://img.shields.io/badge/Node.js-20-339933?logo=nodedotjs&logoColor=white)
![Azure](https://img.shields.io/badge/Azure-Cloud-0078D4?logo=microsoftazure&logoColor=white)

> Plataforma completa de observabilidade cloud-native implantada no **Azure Kubernetes Service (AKS)**.
> Demonstra instrumentação com **OpenTelemetry**, processamento via **OTEL Collector** e análise
> no **Dynatrace** — cobrindo os três pilares de observabilidade: **traces, métricas e logs**.

---

## Sumário

- [Visão Geral](#visão-geral)
- [Arquitetura](#arquitetura)
- [Stack Tecnológica](#stack-tecnológica)
- [Estrutura do Projeto](#estrutura-do-projeto)
- [Pré-requisitos](#pré-requisitos)
- [Como Executar](#como-executar)
- [Endpoints da Aplicação](#endpoints-da-aplicação)
- [Conceitos-Chave](#conceitos-chave)
- [Decisões de Arquitetura](#decisões-de-arquitetura)
- [Autor](#autor)

---

## Visão Geral

Este projeto implementa uma **arquitetura de observabilidade end-to-end** para ambientes Kubernetes, com foco em:

- **Instrumentação de código** com o SDK OpenTelemetry para Node.js
- **Coleta e processamento** de telemetria via OpenTelemetry Collector em modo gateway
- **Exportação nativa via OTLP** para o Dynatrace sem dependência de agente proprietário
- **Infraestrutura como código** com Terraform (AKS, ACR, RBAC, Log Analytics)
- **Pipeline CI/CD** automatizado com GitHub Actions e runner self-hosted no Azure

O resultado é uma stack que gera e entrega **traces, métricas e logs** de uma aplicação Node.js rodando no AKS diretamente para a plataforma do Dynatrace, onde são analisados pelo motor de IA **Davis**.

---

## Arquitetura

```
┌─────────────────────────────────────────────────────────┐
│                      USUÁRIO / CI                        │
│            curl http://135.224.215.123/                  │
└───────────────────────────┬─────────────────────────────┘
                            │ HTTP : 80
                            ▼
┌─────────────────────────────────────────────────────────┐
│           Azure LoadBalancer — Service Kubernetes        │
│                  Namespace: observability-lab            │
└───────────────────────────┬─────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────┐
│         otel-demo-app  (2 réplicas — Node.js)           │
│                                                         │
│  • OTEL SDK auto-instrumentação (HTTP, Express)         │
│  • Spans manuais com atributos semânticos               │
│  • Métricas customizadas (counter, histograma, gauge)   │
└───────────────────────────┬─────────────────────────────┘
                            │ OTLP HTTP : 4318
                            │ /v1/traces  /v1/metrics
                            ▼
┌─────────────────────────────────────────────────────────┐
│        otel-collector  (Deployment — modo gateway)      │
│                                                         │
│  Receivers:   otlp (gRPC :4317 / HTTP :4318)           │
│  Processors:  memory_limiter → resource → batch         │
│  Exporters:   otlphttp/dynatrace + debug                │
└───────────────────────────┬─────────────────────────────┘
                            │ OTLP/HTTP + gzip
                            │ Authorization: Api-Token ...
                            ▼
┌─────────────────────────────────────────────────────────┐
│                   Dynatrace SaaS                        │
│     https://rqn58217.live.dynatrace.com/api/v2/otlp    │
│                                                         │
│  • Distributed Tracing (PurePaths)                     │
│  • Service Monitoring (RED metrics)                     │
│  • Davis AI — detecção de anomalias                    │
└─────────────────────────────────────────────────────────┘

Infraestrutura (Terraform)                CI/CD (GitHub Actions)
 ┌──────────────────────┐                ┌──────────────────────┐
 │ AKS Cluster          │                │ 1. Build & Test       │
 │ Azure Container Reg. │                │ 2. Build & Push ACR   │
 │ Log Analytics        │                │ 3. kubectl apply k8s/ │
 │ VM (self-hosted GHA) │                │ Runner: VM Azure      │
 └──────────────────────┘                └──────────────────────┘
```

---

## Stack Tecnológica

| Camada              | Tecnologia                                   | Função                                    |
|---------------------|----------------------------------------------|-------------------------------------------|
| **Aplicação**       | Node.js 20 + Express                         | API REST instrumentada com OTEL           |
| **Instrumentação**  | OpenTelemetry SDK v0.53 (Node.js)            | Geração de traces e métricas              |
| **Coleta**          | OTEL Collector Contrib v0.100.0              | Receber, processar e exportar telemetria  |
| **Observabilidade** | Dynatrace SaaS                               | Análise, dashboards, alertas, Davis AI    |
| **Orquestração**    | Azure Kubernetes Service (AKS) v1.34         | Plataforma de containers gerenciada       |
| **Registro**        | Azure Container Registry (ACR)               | Armazenamento de imagens Docker           |
| **Infraestrutura**  | Terraform + Azure Provider                   | IaC para todos os recursos Azure          |
| **CI/CD**           | GitHub Actions + self-hosted runner          | Automação de build, push e deploy         |
| **Segredos**        | Kubernetes Secrets + Azure Key Vault (IaC)   | Gestão segura de credenciais              |

---

## Estrutura do Projeto

```
aks-observability-otel-dynatrace/
│
├── app/
│   ├── Dockerfile                     # Multi-stage build, non-root user (UID 1001)
│   ├── package.json                   # Dependências: Express + SDK OTEL completo
│   ├── package-lock.json              # Lock file — build reproduzível
│   └── server.js                      # App com traces manuais + métricas customizadas
│
├── k8s/
│   ├── namespace.yaml                 # Namespace isolado: observability-lab
│   ├── secret-dynatrace.yaml          # Template de Secret (usar kubectl, não commitar tokens)
│   ├── otel-collector-configmap.yaml  # Config completo do Collector (pipeline OTLP → Dynatrace)
│   ├── otel-collector-deployment.yaml # Deployment + Service do Collector (probes na :8888)
│   ├── app-deployment.yaml            # Deployment da app (affinity, securityContext, probes)
│   └── app-service.yaml               # Service LoadBalancer (exposição externa)
│
├── terraform/
│   ├── main.tf                        # AKS, ACR, Log Analytics, RBAC, VM runner
│   ├── variables.tf                   # Variáveis tipadas com validação e descrição
│   └── outputs.tf                     # Outputs: credentials command, ACR server, IPs
│
├── .github/
│   └── workflows/
│       └── ci-cd.yaml                 # Pipeline: Build & Test → Push ACR → Deploy AKS
│
├── .gitignore                         # Exclui tfstate, TROUBLESHOOTING.md, segredos
└── README.md                          # Este arquivo
```

---

## Pré-requisitos

| Requisito                  | Versão mínima | Observação                                             |
|----------------------------|---------------|--------------------------------------------------------|
| Azure CLI (`az`)           | 2.50+         | `az login` antes de executar                           |
| Terraform                  | 1.6+          | `terraform init` no diretório `terraform/`             |
| kubectl                    | 1.28+         | Configurado após `az aks get-credentials`              |
| Docker                     | 24+           | Para build local (opcional — CI/CD faz o build)        |
| Conta Dynatrace            | SaaS          | Trial gratuito disponível em dynatrace.com             |
| Access Token Dynatrace     | —             | Scopes: `metrics.ingest`, `openTelemetryTrace.ingest`, `logs.ingest` |

---

## Como Executar

### 1. Provisionar a Infraestrutura

```bash
cd terraform/

# Crie o arquivo de variáveis locais (não commitar)
cat > terraform.tfvars <<EOF
subscription_id     = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
acr_name            = "acraksobs20260504"
resource_group_name = "rg-aks-observability"
location            = "eastus2"
EOF

terraform init
terraform plan
terraform apply -auto-approve
```

### 2. Configurar o kubectl

```bash
az aks get-credentials \
  --resource-group rg-aks-observability \
  --name aks-observability-cluster \
  --admin

kubectl get nodes   # verificar: 2 nodes Ready
```

### 3. Criar o Secret do Dynatrace

> **Importante:** Nunca commite tokens reais no repositório.
> O arquivo `k8s/secret-dynatrace.yaml` contém apenas placeholders.

```bash
kubectl create secret generic dynatrace-secret \
  --namespace=observability-lab \
  --from-literal=DT_OTLP_ENDPOINT='https://<env-id>.live.dynatrace.com/api/v2/otlp' \
  --from-literal=DT_API_TOKEN='Api-Token dt0c01.SEU_TOKEN_AQUI' \
  --dry-run=client -o yaml | kubectl apply -f -
```

> O prefixo `Api-Token ` (com espaço) é **obrigatório** — sem ele, o Dynatrace retorna 401.

### 4. Build e Push da Imagem (manual)

```bash
ACR_LOGIN_SERVER=$(cd terraform && terraform output -raw acr_login_server)

az acr login --name acraksobs20260504
docker build -t ${ACR_LOGIN_SERVER}/otel-demo-app:latest ./app
docker push ${ACR_LOGIN_SERVER}/otel-demo-app:latest
```

### 5. Deploy no Kubernetes

```bash
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/otel-collector-configmap.yaml
kubectl apply -f k8s/otel-collector-deployment.yaml
kubectl apply -f k8s/app-deployment.yaml
kubectl apply -f k8s/app-service.yaml

# Acompanhar o estado dos pods
kubectl get pods -n observability-lab -w
```

### 6. Verificar o Deploy

```bash
# Todos os pods devem estar 1/1 Running com 0 restarts
kubectl get pods -n observability-lab

# Obter o IP externo da aplicação
kubectl get svc otel-demo-app -n observability-lab
```

### 7. Gerar Tráfego e Verificar no Dynatrace

```bash
EXTERNAL_IP=$(kubectl get svc otel-demo-app -n observability-lab \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

curl http://$EXTERNAL_IP/        # trace simples — rota principal
curl http://$EXTERNAL_IP/health  # health check (sem trace — evita ruído)
```

**No Dynatrace:** `https://<env-id>.apps.dynatrace.com/` → Distributed Tracing → Explorer → Spans

---

## Endpoints da Aplicação

| Endpoint       | Status | Comportamento                                   | Conceito OTEL demonstrado          |
|----------------|--------|-------------------------------------------------|------------------------------------|
| `GET /`        | 200    | Resposta com info do serviço                    | Span com atributos semânticos      |
| `GET /health`  | 200    | Health check (liveness/readiness do Kubernetes) | Rota sem span — não polui traces   |

**Métricas customizadas exportadas:**

| Métrica                     | Tipo        | Descrição                              |
|-----------------------------|-------------|----------------------------------------|
| `http_requests_total`       | Counter     | Total de requisições recebidas         |
| `http_request_duration_ms`  | Histogram   | Latência em milissegundos por rota     |
| `http_requests_active`      | UpDownCounter | Requisições em processamento agora   |

---

## Conceitos-Chave

### Os Três Pilares da Observabilidade

| Pilar       | O que é                                        | Implementado neste projeto                  |
|-------------|------------------------------------------------|---------------------------------------------|
| **Traces**  | Caminho de uma requisição entre serviços       | SDK OTEL → Collector → Dynatrace            |
| **Métricas**| Dados numéricos agregados ao longo do tempo    | Counter, Histogram, Gauge customizados      |
| **Logs**    | Eventos discretos com contexto estruturado     | Pipeline de logs configurado no Collector   |

### OpenTelemetry Collector — Pipeline

```
Receivers           Processors                      Exporters
──────────          ──────────────────────────────  ─────────────────────
otlp (gRPC :4317)   memory_limiter (400Mi / 100Mi)  otlphttp/dynatrace
otlp (HTTP :4318)   resource (k8s.cluster.name,     debug (verbosity normal)
                              cloud.provider)
                    batch (512 spans / 10s)
```

### Dynatrace — Ingestão via OTLP (sem OneAgent)

```
OTEL Collector
    │
    │  POST https://<env-id>.live.dynatrace.com/api/v2/otlp
    │  Authorization: Api-Token <token>
    │  Content-Encoding: gzip
    │
    ▼
Dynatrace Grail (armazenamento unificado)
    ├── Distributed Tracing (PurePaths)
    ├── Service Monitoring (RED: Rate, Errors, Duration)
    └── Davis AI (anomaly detection, root cause)
```

> Esta abordagem é **vendor-neutral**: trocar o backend de Dynatrace para Jaeger,
> Grafana Tempo ou qualquer outro requer apenas alterar o exporter no ConfigMap,
> **sem modificar o código da aplicação**.

### Kubernetes — Padrões de Segurança Aplicados

| Prática                      | Onde                           | Por quê                                      |
|------------------------------|--------------------------------|----------------------------------------------|
| Non-root container (UID 1001)| `Dockerfile` + `securityContext` | Princípio do menor privilégio              |
| `readOnlyRootFilesystem`     | `app-deployment.yaml`          | Evita escrita em disco no container          |
| Secrets via `secretKeyRef`   | `otel-collector-deployment.yaml`| Tokens nunca em plain text nos manifests    |
| `PodAntiAffinity`            | `app-deployment.yaml`          | Alta disponibilidade: pods em nós diferentes |
| Resource requests/limits     | Todos os deployments           | Garantia de QoS e scheduling correto        |
| Liveness/Readiness Probes    | Todos os deployments           | Detecção automática de falhas               |

---

## Decisões de Arquitetura

### Por que OTEL Collector em vez de exportar direto do app?

O app poderia exportar traces diretamente ao Dynatrace via OTLP, mas o Collector adiciona:

1. **Resiliência** — retry automático, buffer em memória, backpressure
2. **Processamento** — enriquecimento com atributos do cluster (`k8s.cluster.name`, `cloud.provider`)
3. **Flexibilidade** — um mesmo dado pode ir para múltiplos backends simultaneamente
4. **Desacoplamento** — trocar o backend não exige rebuild da imagem da aplicação
5. **Batching** — reduz o número de chamadas HTTP ao backend, melhorando throughput

### Por que OTLP em vez do Dynatrace OneAgent?

| Critério            | OneAgent                              | OTLP (este projeto)                      |
|---------------------|---------------------------------------|------------------------------------------|
| Configuração        | Zero-config (auto-discovery)          | Requer instrumentação no código/OTEL     |
| Lock-in             | Acoplado ao Dynatrace                 | Padrão aberto CNCF — troca de backend sem recompilação |
| Contexto de negócio | Automático por bytecode injection     | Controlado — spans com semântica de domínio |
| Kubernetes gerenciado | Requer Dynatrace Operator           | Apenas um ConfigMap e um Secret          |
| Multi-vendor        | Não                                   | Sim — pode exportar para N backends      |

### Por que runner self-hosted no Azure?

A VM `vm-gha-runner-01` no Azure atua como runner do GitHub Actions porque:
- Tem **Managed Identity** com roles `AcrPush` e `AKS RBAC Cluster Admin`
- Elimina a necessidade de armazenar `client_secret` como secret no GitHub
- Está na mesma rede do AKS — latência mínima para o deploy
- Demonstra o padrão de **identidade gerenciada** (sem credenciais de longa duração)

---

## Autor

**Edilson Monteiro**
DevOps Engineer | Cloud & Observability | Azure | Kubernetes

[![LinkedIn](https://img.shields.io/badge/LinkedIn-edymonte-0A66C2?logo=linkedin)](https://linkedin.com/in/edymonte)
[![GitHub](https://img.shields.io/badge/GitHub-edymonte-181717?logo=github)](https://github.com/edymonte)

---

<details>
<summary>Troubleshooting — Problemas Resolvidos</summary>

### otel-collector em CrashLoopBackOff

**Sintoma:** pod reiniciando com `Liveness probe failed: connection refused` na porta 13133.

**Causa:** A extensão `health_check` não abria a porta 13133 na versão `contrib:0.100.0`.

**Solução:** Alterar os probes para usar a porta `8888` (`/metrics`), que é a porta nativa
de métricas do Collector e está sempre disponível:

```yaml
livenessProbe:
  httpGet:
    path: /metrics
    port: 8888
```

---

### Traces não chegando ao Dynatrace

**Sintoma:** App responde HTTP 200, Collector rodando, mas Dynatrace mostra "No matching requests".

**Causa:** O SDK OTEL v0.53.x com `url` explícita no construtor do exporter trata o valor
como endpoint **completo** — sem adicionar o signal path (`/v1/traces`).

```javascript
// ERRADO: envia para http://collector:4318 (raiz — rejeitado pelo Collector)
new OTLPTraceExporter({ url: process.env.OTEL_EXPORTER_OTLP_ENDPOINT })

// CORRETO: SDK lê OTEL_EXPORTER_OTLP_ENDPOINT e adiciona /v1/traces automaticamente
new OTLPTraceExporter()
```

</details>

