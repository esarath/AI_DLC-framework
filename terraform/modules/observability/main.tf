# ---------------------------------------------------------------------------
# Alternate monitoring option: Azure Managed Prometheus (AMW) + Managed Grafana.
# Enabled per-environment via `enable_managed_prometheus_grafana = true`.
# Can run alongside OR instead of Container Insights (see enable_container_insights).
# ---------------------------------------------------------------------------

# Azure Monitor Workspace = the managed Prometheus store
resource "azurerm_monitor_workspace" "amw" {
  name                = "amw-${var.name_prefix}"
  resource_group_name = var.resource_group
  location            = var.location
  tags                = var.tags
}

# DCE + DCR pipe the AKS ama-metrics agent (enabled via the cluster's
# monitor_metrics block) into the Azure Monitor Workspace.
resource "azurerm_monitor_data_collection_endpoint" "dce" {
  name                = "MSProm-${var.location}-${var.aks_cluster_name}"
  resource_group_name = var.resource_group
  location            = var.location
  kind                = "Linux"
  tags                = var.tags
}

resource "azurerm_monitor_data_collection_rule" "prometheus" {
  name                        = "MSProm-${var.location}-${var.aks_cluster_name}"
  resource_group_name         = var.resource_group
  location                    = var.location
  data_collection_endpoint_id = azurerm_monitor_data_collection_endpoint.dce.id
  kind                        = "Linux"
  tags                        = var.tags

  destinations {
    monitor_account {
      monitor_account_id = azurerm_monitor_workspace.amw.id
      name               = azurerm_monitor_workspace.amw.name
    }
  }

  data_flow {
    streams      = ["Microsoft-PrometheusMetrics"]
    destinations = [azurerm_monitor_workspace.amw.name]
  }

  data_sources {
    prometheus_forwarder {
      streams = ["Microsoft-PrometheusMetrics"]
      name    = "PrometheusDataSource"
    }
  }
}

resource "azurerm_monitor_data_collection_rule_association" "dcra" {
  name                    = "MSProm-${var.location}-${var.aks_cluster_name}"
  target_resource_id      = var.aks_cluster_id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.prometheus.id
  description             = "Association of DCR. Deleting this association breaks Prometheus data collection for this AKS cluster."
}

# Managed Grafana — SystemAssigned identity reads metrics via Monitoring Reader.
resource "azurerm_dashboard_grafana" "grafana" {
  name                  = "grafana-${var.name_prefix}"
  resource_group_name   = var.resource_group
  location              = var.location
  grafana_major_version = var.grafana_major_version
  sku                   = "Standard"
  tags                  = var.tags

  identity {
    type = "SystemAssigned"
  }

  azure_monitor_workspace_integrations {
    resource_id = azurerm_monitor_workspace.amw.id
  }
}

data "azurerm_subscription" "current" {}

resource "azurerm_role_assignment" "grafana_monitor_reader" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Monitoring Reader"
  principal_id         = azurerm_dashboard_grafana.grafana.identity[0].principal_id
}
