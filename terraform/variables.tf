# ─────────────────────────────────────────────────────────────────────────────
# TERRAFORM — Variables
#
# Boas práticas:
#   - Todas as variáveis obrigatórias sem default forçam o operador a declarar
#     valores explicitamente (evita configurações acidentais).
#   - Variáveis sensíveis (ex: client_secret) nunca devem ter valor default.
#   - Use terraform.tfvars ou variáveis de ambiente TF_VAR_* em CI/CD.
# ─────────────────────────────────────────────────────────────────────────────

# ── Azure ────────────────────────────────────────────────────────────────────

variable "subscription_id" {
  type        = string
  description = "Azure Subscription ID"
}

variable "location" {
  type        = string
  description = "Azure region for all resources"
  default     = "eastus2"
}

variable "resource_group_name" {
  type        = string
  description = "Name of the Azure Resource Group"
  default     = "rg-aks-observability"
}

# ── AKS ─────────────────────────────────────────────────────────────────────

variable "cluster_name" {
  type        = string
  description = "Name of the AKS cluster"
  default     = "aks-observability-cluster"
}

variable "kubernetes_version" {
  type        = string
  description = "Kubernetes version for the AKS cluster"
  default     = null
}

variable "node_count" {
  type        = number
  description = "Number of nodes in the default node pool"
  default     = 2
}

variable "node_vm_size" {
  type        = string
  description = "VM size for AKS nodes"
  default     = "Standard_D2s_v3"
  # D2s_v3: 2 vCPU, 8 GB RAM — bom para demos e estudos
  # Para produção: Standard_D4s_v3 ou superior
}

variable "os_disk_size_gb" {
  type        = number
  description = "OS disk size in GB for each node"
  default     = 50
}

# ── ACR (Azure Container Registry) ──────────────────────────────────────────

variable "acr_name" {
  type        = string
  description = "Globally unique name for the Azure Container Registry (alphanumeric only)"
  # Deve ser único globalmente: ex "acraksobs20240101"
}

variable "acr_sku" {
  type        = string
  description = "ACR SKU: Basic, Standard, or Premium"
  default     = "Standard"
  # Basic:    5 GB storage, sem geo-replication
  # Standard: 100 GB, recomendado para produção
  # Premium:  500 GB, geo-replication, private endpoint
}

# ── Tags ─────────────────────────────────────────────────────────────────────

variable "tags" {
  type        = map(string)
  description = "Tags applied to all Azure resources"
  default = {
    project     = "aks-observability"
    environment = "production"
    managed-by  = "terraform"
    team        = "platform-engineering"
  }
}
