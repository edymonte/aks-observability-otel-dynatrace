# Cloud-Native Observability — AKS + OpenTelemetry + Dynatrace

> Projeto de estudo para entrevistas de DevOps/SRE/Platform Engineering.
> Demonstra uma arquitetura de observabilidade end-to-end em Kubernetes.

## Visão Geral

Arquitetura cloud-native de observabilidade usando **Azure Kubernetes Service (AKS)**, **OpenTelemetry** e **Dynatrace**.

O objetivo é fornecer **visibilidade completa** de uma aplicação distribuída coletando, processando e analisando **traces, métricas e logs** (os três pilares da observabilidade).

---

## 🎯 Objectives

- Implement observability in a Kubernetes environment
- Use OpenTelemetry as a vendor-neutral standard for telemetry collection
- Integrate with Dynatrace for monitoring, tracing, and root cause analysis
- Simulate real-world troubleshooting scenarios

---

## 🧱 Architecture

User → Service → Application (AKS)
↓
OpenTelemetry Instrumentation
↓
OpenTelemetry Collector
↓
Dynatrace Platform


### 🔍 Flow Description

1. The application generates telemetry data (traces, metrics, logs)
2. OpenTelemetry collects and standardizes the data
3. OTEL Collector processes and exports the data
4. Dynatrace ingests and analyzes the data

---

## ⚙️ Tech Stack

- Azure Kubernetes Service (AKS)
- Docker
- OpenTelemetry (SDK + Collector)
- Dynatrace
- Kubernetes (Deployment, Service, ConfigMap, Secret)
- GitHub Actions (CI/CD)

---

## Estrutura do Projeto

```
aks-observability-otel-dynatrace/
│
├── app/
│   ├── Dockerfile                    # Multi-stage build, non-root user
│   ├── package.json                  # SDK OTEL + Express
│   └── server.js                     # App instrumentada com traces e métricas
│
├── k8s/
│   ├── namespace.yaml                # Namespace "observability"
│   ├── secret-dynatrace.yaml         # API Token e Endpoint do Dynatrace
│   ├── otel-collector-configmap.yaml # Pipeline: receivers → processors → exporters
│   ├── otel-collector-deployment.yaml# Deployment + Service do Collector
│   ├── app-deployment.yaml           # Deployment da app (probes, affinity, security)
│   └── app-service.yaml              # LoadBalancer Service
│
├── terraform/
│   ├── main.tf                       # AKS, ACR, Log Analytics, RBAC
│   ├── variables.tf                  # Variáveis com tipos e descrições
│   └── outputs.tf                    # Outputs para CI/CD e outros módulos
│
├── .github/
│   └── workflows/
│       └── ci-cd.yaml                # Build → Push ACR → Deploy AKS (OIDC)
│
└── README.md
```

## Arquitetura

```
Usuário → Requisição HTTP
               ↓
       Application (AKS Pod)
       Node.js + OTEL SDK
               ↓  OTLP/gRPC
       OpenTelemetry Collector  ← ConfigMap com pipeline
               ↓  OTLP/HTTP
       Dynatrace Platform
       (Traces, Métricas, Logs)
```

## Pré-requisitos

- Azure subscription com permissão de Contributor
- AKS cluster (ou provisionar via Terraform)
- Docker e kubectl instalados e configurados
- Conta no Dynatrace (trial gratuito: 15 dias)
- API Token do Dynatrace com escopos: `metrics.ingest`, `traces.ingest`, `logs.ingest`

## Como Executar

### 1. Provisionar Infraestrutura

```bash
cd terraform

# Crie um arquivo terraform.tfvars com seus valores:
cat > terraform.tfvars <<EOF
subscription_id     = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
acr_name            = "acraksobs20240101"
resource_group_name = "rg-aks-observability"
EOF

terraform init
terraform plan
terraform apply
```

### 2. Configurar kubectl

```bash
# Use o output do Terraform diretamente:
$(terraform output -raw get_credentials_command)
```

### 3. Criar o Secret do Dynatrace

```bash
# Nunca commite tokens reais no YAML!
kubectl create secret generic dynatrace-secret \
  --namespace=observability-lab \
  --from-literal=DT_OTLP_ENDPOINT='https://<env-id>.live.dynatrace.com/api/v2/otlp' \
  --from-literal=DT_API_TOKEN='Api-Token dt0c01.SEU_TOKEN'
```

### 4. Build e Push da Imagem

```bash
ACR_NAME=$(cd terraform && terraform output -raw acr_login_server)

az acr login --name <acr-name>
docker build -t ${ACR_NAME}/otel-demo-app:latest ./app
docker push ${ACR_NAME}/otel-demo-app:latest
```

### 5. Deploy no AKS

```bash
kubectl apply -f k8s/namespace.yaml          # cria o namespace observability-lab
kubectl apply -f k8s/secret-dynatrace.yaml
kubectl apply -f k8s/otel-collector-configmap.yaml
kubectl apply -f k8s/otel-collector-deployment.yaml
kubectl apply -f k8s/app-deployment.yaml
kubectl apply -f k8s/app-service.yaml

# Verificar status
kubectl get pods -n observability-lab
kubectl get services -n observability-lab
```

### 6. Testar a Aplicação

```bash
# Obter o IP externo do LoadBalancer
EXTERNAL_IP=$(kubectl get svc otel-demo-app -n observability-lab -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

curl http://$EXTERNAL_IP/           # rota principal
curl http://$EXTERNAL_IP/checkout   # simula fluxo de checkout (300ms delay + span)
curl http://$EXTERNAL_IP/error      # simula erro (span com status ERROR)
curl http://$EXTERNAL_IP/chain      # três spans encadeados (parent → child)
curl http://$EXTERNAL_IP/health     # health check (liveness/readiness)
```

## Conceitos-Chave para Entrevista

### Os 3 Pilares da Observabilidade

| Pilar | O que é | Ferramenta neste projeto |
|-------|---------|--------------------------|
| **Traces** | Jornada completa de uma requisição (spans encadeados) | OTEL SDK + Dynatrace |
| **Métricas** | Dados numéricos agregados ao longo do tempo | OTEL Metrics + Dynatrace |
| **Logs** | Registros de eventos com contexto | OTEL Logs + Dynatrace |

### Rotas da aplicação

| Rota | Comportamento | Conceito demonstrado |
|------|--------------|----------------------|
| `GET /` | Resposta imediata | Span simples com atributos |
| `GET /checkout` | 300ms delay (simula chamada externa) | Latência de negócio, axios propagation |
| `GET /error` | Retorna 500 | Span com `SpanStatusCode.ERROR` |
| `GET /chain` | 3 spans filhos sequenciais | Context propagation, parent→child |
| `GET /health` | Health check | Probe sem ruído nos traces |

### Span × Trace

- **Trace**: representa uma transação completa (ex: requisição HTTP de ponta a ponta)
- **Span**: operação individual dentro do trace (ex: query no banco, chamada a API)
- **Context Propagation**: mecanismo que conecta spans entre serviços (W3C TraceContext / B3)

### OpenTelemetry Collector — Pipeline

```
Receivers  → Processors         → Exporters
otlp/grpc    memory_limiter       otlphttp/dynatrace
otlp/http    batch                logging (debug)
             resource (add attrs)
```

### Por que OIDC no GitHub Actions?

- Elimina secrets de longa duração (client_secret)
- Token temporário gerado por GitHub, verificado pelo Azure AD
- Princípio do menor privilégio: cada workflow tem sua própria identidade

### AKS — Conceitos Importantes

| Conceito | O que é | Onde aparece neste projeto |
|----------|---------|---------------------------|
| Liveness Probe | Reinicia o container se falhar | `app-deployment.yaml` |
| Readiness Probe | Remove do Service se não estiver pronto | `app-deployment.yaml` |
| Startup Probe | Evita kill durante inicialização lenta | `app-deployment.yaml` |
| PodAntiAffinity | Distribui pods entre nós (HA) | `app-deployment.yaml` |
| ResourceQuota | Limites de CPU/memória por namespace | definido via requests/limits |
| Managed Identity | Autenticação sem secrets (AKS → ACR) | `main.tf` AcrPull role |

## Por que OpenTelemetry + Dynatrace?

| OpenTelemetry | Dynatrace |
|---------------|-----------|
| Vendor-neutral | Plataforma completa de APM |
| Padronizado (CNCF) | Análise com IA (Davis) |
| Multi-cloud ready | Root Cause Detection automático |
| SDK + Collector | SLO/SLA management |

## Autor

Edilson Monteiro — DevOps Engineer | Cloud | Observability


This project simulates a real-world observability scenario in cloud-native environments, focusing on:

Scalability
Visibility
Troubleshooting efficiency

🚀 Interview Summary (Quick Pitch)

This project demonstrates how to implement observability in AKS using OpenTelemetry and Dynatrace.
The application generates telemetry data, which is collected and processed by the OTEL Collector and sent to Dynatrace for analysis.
This enables distributed tracing, performance monitoring, and faster root cause identification.




