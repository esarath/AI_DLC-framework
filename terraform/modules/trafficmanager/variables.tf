variable "name_prefix" { type = string }
variable "resource_group" { type = string }
variable "endpoint_fqdn" {
  description = "FQDN of the primary endpoint (Front Door or ingress)"
  type        = string
}
variable "routing_method" {
  type    = string
  default = "Performance" # Performance | Weighted | Priority | Geographic
}
variable "tags" {
  type    = map(string)
  default = {}
}
