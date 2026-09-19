output "cluster_name" {
  value = azurerm_kubernetes_cluster.main.name
}

output "cluster_id" {
  value = azurerm_kubernetes_cluster.main.id
}

output "kubelet_identity_object_id" {
  value = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
}

output "oidc_issuer_url" {
  value = azurerm_kubernetes_cluster.main.oidc_issuer_url
}

output "ingress_fqdn" {
  value = azurerm_public_ip.ingress.fqdn
}

output "ingress_public_ip" {
  value = azurerm_public_ip.ingress.ip_address
}

output "appgw_id" {
  value = var.enable_agic ? azurerm_application_gateway.agic[0].id : null
}
