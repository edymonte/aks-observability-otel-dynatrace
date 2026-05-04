# AKS Observability with OpenTelemetry and Dynatrace

## 📌 Overview

This project demonstrates a cloud-native observability architecture using **Azure Kubernetes Service (AKS)**, **OpenTelemetry**, and **Dynatrace**.

The goal is to provide **end-to-end visibility** into a distributed application by collecting, processing, and analyzing telemetry data such as **traces, metrics, and logs**.

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

## 📁 Project Structure

├── app/ # Application source code
├── k8s/ # Kubernetes manifests
├── terraform/ # AKS infrastructure
├── .github/workflows/ # CI/CD pipeline
└── README.md


---

## 🚀 Getting Started

### 1. Prerequisites

- Azure subscription
- AKS cluster
- Docker
- kubectl configured
- Dynatrace environment
- Dynatrace API Token

---

### 2. Build and Push Image

```bash
docker build -t <acr-name>.azurecr.io/otel-demo-app:latest ./app
docker push <acr-name>.azurecr.io/otel-demo-app:latest

### 3. Deploy to AKS

kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/secret-dynatrace.yaml
kubectl apply -f k8s/otel-collector-configmap.yaml
kubectl apply -f k8s/otel-collector-deployment.yaml
kubectl apply -f k8s/app-deployment.yaml
kubectl apply -f k8s/app-service.yaml

🔎 Observability Concepts
📊 Metrics

Provide numerical insights into system performance
Examples: CPU, memory, latency

🔗 Traces

Represent the full journey of a request across services

🧩 Spans

Individual operations inside a trace

📄 Logs

Detailed event records for debugging


🧠 Troubleshooting Strategy
Analyze metrics to detect anomalies
Use traces to identify bottlenecks
Correlate with logs and infrastructure data
Identify root cause and validate impact

🔥 Key Features
Distributed tracing with OpenTelemetry
Centralized telemetry via OTEL Collector
Integration with Dynatrace using OTLP
Kubernetes-native deployment
Simulated latency and error scenarios

📊 Use Cases
Performance monitoring
Root cause analysis
Microservices observability
Kubernetes troubleshooting
DevOps and SRE practices

🧭 Why OpenTelemetry + Dynatrace?

| OpenTelemetry     | Dynatrace             |
| ----------------- | --------------------- |
| Vendor-neutral    | Full platform         |
| Standardized data | AI-driven analysis    |
| Flexible pipeline | Root cause detection  |
| Multi-cloud ready | End-to-end visibility |

📈 Future Improvements
Add SLO/SLA monitoring
Integrate Prometheus and Grafana
Implement alerting
Add GitOps with ArgoCD
Improve security (RBAC, secrets)

👨‍💻 Author

Edilson Monteiro
DevOps Engineer | Cloud | Observability

💬 Final Notes

This project simulates a real-world observability scenario in cloud-native environments, focusing on:

Scalability
Visibility
Troubleshooting efficiency

🚀 Interview Summary (Quick Pitch)

This project demonstrates how to implement observability in AKS using OpenTelemetry and Dynatrace.
The application generates telemetry data, which is collected and processed by the OTEL Collector and sent to Dynatrace for analysis.
This enables distributed tracing, performance monitoring, and faster root cause identification.




