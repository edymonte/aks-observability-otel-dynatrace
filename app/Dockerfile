# ─────────────────────────────────────────────────────────────────────────────
# STAGE 1 — Build / Install Dependencies
# Usamos a imagem "alpine" (menor tamanho) apenas para instalar pacotes.
# Multi-stage build é uma boa prática: reduz a imagem final excluindo
# ferramentas de build e arquivos desnecessários.
# ─────────────────────────────────────────────────────────────────────────────
FROM node:20-alpine AS builder

WORKDIR /app

# Copia apenas os arquivos de manifesto primeiro (aproveitamento de cache do Docker).
# Se package.json não mudar, esta camada é reaproveitada em builds subsequentes.
COPY package.json package-lock.json* ./

# --omit=dev: instala somente dependências de produção
RUN npm ci --omit=dev

# ─────────────────────────────────────────────────────────────────────────────
# STAGE 2 — Runtime Image
# Imagem final: apenas Node + dependências de produção + código da aplicação.
# ─────────────────────────────────────────────────────────────────────────────
FROM node:20-alpine AS runtime

# Boa prática de segurança: não rodar como root dentro do container
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

# Copia node_modules já instalados do stage de build
COPY --from=builder /app/node_modules ./node_modules

# Copia o código da aplicação
COPY server.js ./
COPY package.json ./

# Muda a propriedade dos arquivos para o usuário não-root
RUN chown -R appuser:appgroup /app

USER appuser

# Documentação: porta exposta pela aplicação (não publica a porta no host)
EXPOSE 3000

# Healthcheck: o Kubernetes vai sobrescrever isso com liveness/readiness probes,
# mas é útil para testes locais com `docker run`
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://localhost:3000/health || exit 1

# Variáveis de ambiente padrão — serão sobrescritas pelo Deployment do K8s
ENV NODE_ENV=production \
    PORT=3000 \
    OTEL_SERVICE_NAME=otel-demo-app \
    OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4317

CMD ["node", "server.js"]
