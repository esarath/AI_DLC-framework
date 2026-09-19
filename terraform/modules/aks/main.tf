data "azurerm_resource_group" "main" {
  name = var.resource_group
}

# Public IP + DNS label used as the ingress frontend (App Gateway when AGIC is
# enabled; otherwise it can be adopted by a LoadBalancer service annotation).
resource "azurerm_public_ip" "ingress" {
  name                = "pip-${var.name_prefix}-ingress"
  location            = var.location
  resource_group_name = var.resource_group
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = "${var.name_prefix}-ingress"
  tags                = var.tags
}

# ---------------------------------------------------------------------------
# Application Gateway (brownfield for AGIC) — AGIC takes over and manages the
# backend pools, listeners, rules and probes; they are ignore_changes below.
# ---------------------------------------------------------------------------
resource "azurerm_application_gateway" "agic" {
  count               = var.enable_agic ? 1 : 0
  name                = "agw-${var.name_prefix}"
  location            = var.location
  resource_group_name = var.resource_group
  tags                = var.tags

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "gw-ipcfg"
    subnet_id = var.appgw_subnet_id
  }

  frontend_ip_configuration {
    name                 = "fe-public"
    public_ip_address_id = azurerm_public_ip.ingress.id
  }

  frontend_port {
    name = "port-80"
    port = 80
  }

  backend_address_pool {
    name = "default-backend"
  }

  backend_http_settings {
    name                  = "default-http"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 30
  }

  http_listener {
    name                           = "default-listener"
    frontend_ip_configuration_name = "fe-public"
    frontend_port_name             = "port-80"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "default-rule"
    rule_type                  = "Basic"
    priority                   = 100
    http_listener_name         = "default-listener"
    backend_address_pool_name  = "default-backend"
    backend_http_settings_name = "default-http"
  }

  lifecycle {
    ignore_changes = [
      backend_address_pool,
      backend_http_settings,
      frontend_port,
      http_listener,
      probe,
      request_routing_rule,
      redirect_configuration,
      ssl_certificate,
      url_path_map,
      tags,
    ]
  }
}

# ---------------------------------------------------------------------------
# AKS cluster
# ---------------------------------------------------------------------------
resource "azurerm_kubernetes_cluster" "main" {
  name                = "aks-${var.name_prefix}"
  location            = var.location
  resource_group_name = var.resource_group
  dns_prefix          = var.name_prefix
  kubernetes_version  = var.kubernetes_version
  tags                = var.tags

  # On-demand system pool — keeps cluster/system pods off Spot capacity.
  default_node_pool {
    name                = "system"
    vm_size             = var.system_node_pool.vm_size
    vnet_subnet_id      = var.aks_subnet_id
    auto_scaling_enabled = true
    min_count           = var.system_node_pool.min_count
    max_count           = var.system_node_pool.max_count
    os_disk_size_gb     = 64
    upgrade_settings {
      max_surge = "33%"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "azure"
    network_policy    = "azure"
    load_balancer_sku = "standard"
    outbound_type     = "loadBalancer"
  }

  azure_policy_enabled             = true
  oidc_issuer_enabled              = true   # enables workload identity / GitHub OIDC federation
  workload_identity_enabled        = true
  local_account_disabled           = false  # set true + AAD RBAC for production hardening
  role_based_access_control_enabled = true

  oms_agent {
    log_analytics_workspace_id      = var.log_analytics_ws_id
    msi_auth_for_monitoring_enabled = true
  }

  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m"
  }

  dynamic "ingress_application_gateway" {
    for_each = var.enable_agic ? [1] : []
    content {
      gateway_id = azurerm_application_gateway.agic[0].id
    }
  }
}

# ---------------------------------------------------------------------------
# Spot user node pool — autoscaled min 2 / max 5, tainted so only tolerant
# workloads (our app, via toleration) schedule here.
# ---------------------------------------------------------------------------
resource "azurerm_kubernetes_cluster_node_pool" "spot" {
  name                  = "spot"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = var.spot_node_pool.vm_size
  vnet_subnet_id        = var.aks_subnet_id
  mode                  = "User"

  priority        = "Spot"
  eviction_policy = var.spot_node_pool.eviction_policy
  spot_max_price  = var.spot_node_pool.spot_max_price

  auto_scaling_enabled = true
  min_count            = var.spot_node_pool.min_count
  max_count            = var.spot_node_pool.max_count

  os_disk_size_gb = 64
  node_labels = {
    "kubernetes.azure.com/scalesetpriority" = "spot"
    "workload"                              = "webapp"
  }
  node_taints = [
    "kubernetes.azure.com/scalesetpriority=spot:NoSchedule"
  ]
  upgrade_settings {
    max_surge = "33%"
  }
  tags = var.tags
}

# ---------------------------------------------------------------------------
# RBAC: AcrPull for kubelet identity
# ---------------------------------------------------------------------------
resource "azurerm_role_assignment" "acr_pull" {
  scope                            = var.acr_id
  role_definition_name             = "AcrPull"
  principal_id                     = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
  skip_service_principal_aad_check = true
}

# ---------------------------------------------------------------------------
# RBAC for the AGIC addon identity (only when AGIC enabled)
# ---------------------------------------------------------------------------
locals {
  agic_identity = var.enable_agic ? azurerm_kubernetes_cluster.main.ingress_application_gateway[0].ingress_application_gateway_identity[0].object_id : null
}

resource "azurerm_role_assignment" "agic_appgw_contributor" {
  count                            = var.enable_agic ? 1 : 0
  scope                            = azurerm_application_gateway.agic[0].id
  role_definition_name             = "Contributor"
  principal_id                     = local.agic_identity
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "agic_rg_reader" {
  count                            = var.enable_agic ? 1 : 0
  scope                            = data.azurerm_resource_group.main.id
  role_definition_name             = "Reader"
  principal_id                     = local.agic_identity
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "agic_subnet_network_contributor" {
  count                            = var.enable_agic ? 1 : 0
  scope                            = var.appgw_subnet_id
  role_definition_name             = "Network Contributor"
  principal_id                     = local.agic_identity
  skip_service_principal_aad_check = true
}
