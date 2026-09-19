resource "azurerm_container_registry" "main" {
  name                = replace("acr${var.name_prefix}", "-", "")
  location            = var.location
  resource_group_name = var.resource_group
  sku                 = var.sku
  admin_enabled       = false
  tags                = var.tags
}
