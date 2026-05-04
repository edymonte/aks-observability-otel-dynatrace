# ─────────────────────────────────────────────────────────────────────────────
# TERRAFORM — Outputs
#
# Outputs expõem valores do state para:
#   - Uso em outros módulos Terraform (via remote state)
#   - Scripts de CI/CD (via `terraform output -raw <nome>`)
#   - Documentação automática (via terraform-docs)
# ─────────────────────────────────────────────────────────────────────────────

output "resource_group_name" {
  description = "Name of the Azure Resource Group"
  value       = azurerm_resource_group.main.name
}

output "acr_login_server" {
  description = "ACR login server URL (used as Docker registry prefix)"
  value       = azurerm_container_registry.acr.login_server
  # Exemplo de uso no CI/CD:
  # ACR_LOGIN_SERVER=$(terraform output -raw acr_login_server)
  # docker build -t $ACR_LOGIN_SERVER/otel-demo-app:latest ./app
}

output "aks_cluster_name" {
  description = "Name of the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.name
}

output "aks_cluster_id" {
  description = "Resource ID of the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.id
}

output "aks_fqdn" {
  description = "FQDN of the AKS API server"
  value       = azurerm_kubernetes_cluster.main.fqdn
}

output "aks_kube_config" {
  description = "kubeconfig to connect to the AKS cluster (sensitive)"
  value       = azurerm_kubernetes_cluster.main.kube_config_raw
  sensitive   = true
  # Para exportar: terraform output -raw aks_kube_config > ~/.kube/config
  # CUIDADO: este arquivo contém credenciais de acesso ao cluster
}

output "aks_kubelet_identity_object_id" {
  description = "Object ID of the AKS kubelet Managed Identity (used for ACR pull)"
  value       = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
}

output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics Workspace"
  value       = azurerm_log_analytics_workspace.main.id
}

output "get_credentials_command" {
  description = "Command to configure kubectl for this cluster"
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.main.name} --name ${azurerm_kubernetes_cluster.main.name} --overwrite-existing"
}
