locals {
  name_prefix = "${var.prefix}-${var.environment}"
  tags = merge({
    environment = var.environment
    project     = "ai-dlc-framework"
    managed_by  = "terraform"
  }, var.tags)
}

resource "azurerm_resource_group" "main" {
  name     = "rg-${local.name_prefix}"
  location = var.location
  tags     = local.tags
}

module "network" {
  source = "./modules/network"

  name_prefix       = local.name_prefix
  location          = azurerm_resource_group.main.location
  resource_group    = azurerm_resource_group.main.name
  enable_appgw_subnet = var.enable_agic
  tags              = local.tags
}

module "acr" {
  source = "./modules/acr"

  name_prefix    = local.name_prefix
  location       = azurerm_resource_group.main.location
  resource_group = azurerm_resource_group.main.name
  sku            = var.acr_sku
  tags           = local.tags
}

module "monitoring" {
  source = "./modules/monitoring"

  name_prefix    = local.name_prefix
  location       = azurerm_resource_group.main.location
  resource_group = azurerm_resource_group.main.name
  retention_days = var.log_retention_days
  tags           = local.tags
}

module "aks" {
  source = "./modules/aks"

  name_prefix        = local.name_prefix
  location           = azurerm_resource_group.main.location
  resource_group     = azurerm_resource_group.main.name
  kubernetes_version = var.kubernetes_version

  aks_subnet_id        = module.network.aks_subnet_id
  appgw_subnet_id      = module.network.appgw_subnet_id
  enable_agic          = var.enable_agic
  acr_id               = module.acr.acr_id
  log_analytics_ws_id  = module.monitoring.log_analytics_workspace_id

  system_node_pool = var.system_node_pool
  spot_node_pool   = var.spot_node_pool

  tags = local.tags
}

module "frontdoor" {
  source = "./modules/frontdoor"
  count  = var.enable_front_door ? 1 : 0

  name_prefix    = local.name_prefix
  resource_group = azurerm_resource_group.main.name
  # Front Door probes/routes to the Application Gateway public frontend when AGIC
  # is enabled, otherwise to the AKS LoadBalancer FQDN.
  origin_host    = module.aks.ingress_fqdn
  tags           = local.tags
}

module "trafficmanager" {
  source = "./modules/trafficmanager"
  count  = var.enable_traffic_manager ? 1 : 0

  name_prefix      = local.name_prefix
  resource_group   = azurerm_resource_group.main.name
  endpoint_fqdn    = var.enable_front_door ? module.frontdoor[0].endpoint_hostname : module.aks.ingress_fqdn
  tags             = local.tags
}
