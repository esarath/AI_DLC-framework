variable "name_prefix" { type = string }
variable "resource_group" { type = string }
variable "origin_host" {
  description = "Backend origin hostname (App Gateway / AKS ingress FQDN)"
  type        = string
}
variable "tags" {
  type    = map(string)
  default = {}
}
