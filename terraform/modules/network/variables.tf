variable "name_prefix" { type = string }
variable "location" { type = string }
variable "resource_group" { type = string }
variable "vnet_cidr" {
  type    = string
  default = "10.0.0.0/16"
}
variable "aks_subnet_cidr" {
  type    = string
  default = "10.0.0.0/20"
}
variable "appgw_subnet_cidr" {
  type    = string
  default = "10.0.16.0/24"
}
variable "enable_appgw_subnet" {
  type    = bool
  default = true
}
variable "tags" {
  type    = map(string)
  default = {}
}
