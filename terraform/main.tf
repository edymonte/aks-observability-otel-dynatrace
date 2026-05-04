# ─────────────────────────────────────────────────────────────────────────────
# TERRAFORM — Main Configuration
#
# Provisiona a infraestrutura no Azure:
#   - Resource Group
#   - Azure Container Registry (ACR)
#   - Azure Kubernetes Service (AKS) com integração ao ACR
#
# Comandos essenciais:
#   terraform init      → baixa providers e inicializa o backend
#   terraform plan      → preview das mudanças (nunca aplique sem ver o plan)
#   terraform apply     → aplica as mudanças
#   terraform destroy   → destroi toda a infraestrutura
# ─────────────────────────────────────────────────────────────────────────────

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
  }

  # Backend remoto: armazena o state file no Azure Blob Storage
  # Nunca use backend local em equipes → conflito de state
  # Descomente e configure após criar o Storage Account:
  #
  # backend "azurerm" {
  #   resource_group_name  = "rg-terraform-state"
  #   storage_account_name = "stterraformstate"
  #   container_name       = "tfstate"
  #   key                  = "aks-observability/terraform.tfstate"
  # }
}

provider "azurerm" {
  subscription_id = var.subscription_id
  features {
    # Comportamento ao deletar Resource Groups: aguarda todos os recursos serem removidos
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

# ── Resource Group ───────────────────────────────────────────────────────────

resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# ── Azure Container Registry ─────────────────────────────────────────────────

resource "azurerm_container_registry" "acr" {
  name                = var.acr_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = var.acr_sku

  # Habilita a conta de admin (necessário para docker login com usuário/senha)
  # Em produção: desative e use Managed Identity (prefixo MI na SP do AKS)
  admin_enabled = false

  tags = var.tags
}

# ── Log Analytics Workspace (required for AKS monitoring) ───────────────────

resource "azurerm_log_analytics_workspace" "main" {
  name                = "law-aks-observability"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = var.tags
}

# ── AKS Cluster ──────────────────────────────────────────────────────────────

resource "azurerm_kubernetes_cluster" "main" {
  name                = var.cluster_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  kubernetes_version  = var.kubernetes_version
  dns_prefix          = var.cluster_name

  # Node Pool padrão (System): roda componentes do Kubernetes (coredns, etc.)
  default_node_pool {
    name                = "system"
    node_count          = var.node_count
    vm_size             = var.node_vm_size
    os_disk_size_gb     = var.os_disk_size_gb
    type                = "VirtualMachineScaleSets"

    # Apenas pods de sistema rodam neste node pool
    only_critical_addons_enabled = false

    upgrade_settings {
      max_surge = "33%"  # máximo de nodes extras durante upgrade
    }
  }

  # Identidade Gerenciada: elimina necessidade de Service Principal manual
  identity {
    type = "SystemAssigned"
  }

  # Integração com ACR via role assignment (ver recurso abaixo)
  # O kubelet Managed Identity recebe AcrPull no ACR

  # Network Profile: Azure CNI é recomendado para AKS em produção
  network_profile {
    network_plugin    = "azure"
    network_policy    = "calico"    # ou "azure" (Network Policy obrigatório para segurança)
    load_balancer_sku = "standard"
  }

  # OIDC Issuer: já habilitado no cluster, não pode ser desabilitado
  oidc_issuer_enabled = true

  # Azure Monitor para Containers (envia métricas ao Log Analytics)
  monitor_metrics {}

  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  }

  # Nota: azure_active_directory_role_based_access_control removido para
  # compatibilidade com dispositivos pessoais (Conditional Access Avanade).
  # Em produção, reativar com managed=true e azure_rbac_enabled=true.

  tags = var.tags
}

# ── Role Assignment: AKS → ACR (AcrPull) ────────────────────────────────────
# Permite que o kubelet faça pull de imagens do ACR sem credenciais explícitas
# Utiliza a Managed Identity do kubelet (melhor prática de segurança)

resource "azurerm_role_assignment" "aks_acr_pull" {
  principal_id                     = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.acr.id
  skip_service_principal_aad_check = true

  lifecycle {
    # Role assignments não suportam update — ignorar drift no principal_id
    # causado por re-computação após modificação do AKS cluster
    ignore_changes = [principal_id]
  }
}
