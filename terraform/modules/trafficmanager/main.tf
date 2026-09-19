resource "azurerm_traffic_manager_profile" "main" {
  name                   = "tm-${var.name_prefix}"
  resource_group_name    = var.resource_group
  traffic_routing_method = var.routing_method
  tags                   = var.tags

  dns_config {
    relative_name = var.name_prefix
    ttl           = 30
  }

  monitor_config {
    protocol                     = "HTTP"
    port                         = 80
    path                         = "/healthz"
    interval_in_seconds          = 30
    timeout_in_seconds           = 10
    tolerated_number_of_failures = 3
  }
}

resource "azurerm_traffic_manager_external_endpoint" "primary" {
  name       = "ep-primary"
  profile_id = azurerm_traffic_manager_profile.main.id
  target     = var.endpoint_fqdn
  priority   = 1
  weight     = 1
}
