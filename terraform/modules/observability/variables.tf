variable "name_prefix" { type = string }
variable "location" { type = string }
variable "resource_group" { type = string }
variable "aks_cluster_id" { type = string }
variable "aks_cluster_name" { type = string }
variable "grafana_major_version" {
  type    = number
  default = 10
}
variable "tags" {
  type    = map(string)
  default = {}
}
