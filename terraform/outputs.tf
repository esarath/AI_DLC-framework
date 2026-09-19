output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "aks_cluster_name" {
  value = module.aks.cluster_name
}

output "aks_kube_config_command" {
  value = "az aks get-credentials -g ${azurerm_resource_group.main.name} -n ${module.aks.cluster_name}"
}

output "acr_login_server" {
  value = module.acr.login_server
}

output "acr_name" {
  value = module.acr.acr_name
}

output "ingress_fqdn" {
  value = module.aks.ingress_fqdn
}

output "frontdoor_endpoint_hostname" {
  value = var.enable_front_door ? module.frontdoor[0].endpoint_hostname : null
}

output "traffic_manager_fqdn" {
  value = var.enable_traffic_manager ? module.trafficmanager[0].fqdn : null
}

output "log_analytics_workspace_id" {
  value = module.monitoring.log_analytics_workspace_id
}

output "grafana_endpoint" {
  description = "Managed Grafana URL (when enable_managed_prometheus_grafana = true)"
  value       = var.enable_managed_prometheus_grafana ? module.observability[0].grafana_endpoint : null
}

output "prometheus_query_endpoint" {
  description = "Azure Monitor Workspace PromQL query endpoint"
  value       = var.enable_managed_prometheus_grafana ? module.observability[0].monitor_workspace_query_endpoint : null
}
