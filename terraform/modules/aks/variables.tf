variable "name_prefix" { type = string }
variable "location" { type = string }
variable "resource_group" { type = string }
variable "kubernetes_version" {
  type    = string
  default = null
}
variable "aks_subnet_id" { type = string }
variable "appgw_subnet_id" {
  type    = string
  default = null
}
variable "enable_agic" {
  type    = bool
  default = true
}
variable "acr_id" { type = string }
variable "log_analytics_ws_id" { type = string }
variable "system_node_pool" {
  type = object({
    vm_size   = string
    min_count = number
    max_count = number
  })
}
variable "spot_node_pool" {
  type = object({
    vm_size         = string
    min_count       = number
    max_count       = number
    spot_max_price  = number
    eviction_policy = string
  })
}
variable "tags" {
  type    = map(string)
  default = {}
}
