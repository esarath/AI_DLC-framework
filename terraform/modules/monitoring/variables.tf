variable "name_prefix" { type = string }
variable "location" { type = string }
variable "resource_group" { type = string }
variable "retention_days" {
  type    = number
  default = 30
}
variable "tags" {
  type    = map(string)
  default = {}
}
