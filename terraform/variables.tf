variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
  default     = "995377ec-18d5-43bb-98db-74ab68a2ef8f"
}

variable "environment" {
  description = "Deployment environment (dev | stage | prod)"
  type        = string
  validation {
    condition     = contains(["dev", "stage", "prod"], var.environment)
    error_message = "environment must be one of: dev, stage, prod."
  }
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "eastus"
}

variable "prefix" {
  description = "Naming prefix for all resources"
  type        = string
  default     = "aidlc"
}

variable "kubernetes_version" {
  description = "AKS Kubernetes version (null = latest supported)"
  type        = string
  default     = null
}

variable "system_node_pool" {
  description = "On-demand system node pool settings"
  type = object({
    vm_size   = string
    min_count = number
    max_count = number
  })
  default = {
    vm_size   = "Standard_D2s_v5"
    min_count = 1
    max_count = 3
  }
}

variable "spot_node_pool" {
  description = "Spot user node pool settings (cost-optimised workload pool)"
  type = object({
    vm_size         = string
    min_count       = number
    max_count       = number
    spot_max_price  = number
    eviction_policy = string
  })
  default = {
    vm_size         = "Standard_D4s_v5"
    min_count       = 2
    max_count       = 5
    spot_max_price  = -1 # -1 = pay-as-you-go cap (eviction only, no price cap)
    eviction_policy = "Delete"
  }
}

variable "acr_sku" {
  description = "Azure Container Registry SKU"
  type        = string
  default     = "Standard"
}

variable "enable_agic" {
  description = "Deploy Application Gateway + AGIC ingress addon"
  type        = bool
  default     = true
}

variable "enable_front_door" {
  description = "Deploy Azure Front Door profile for global ingress"
  type        = bool
  default     = true
}

variable "enable_traffic_manager" {
  description = "Deploy Traffic Manager profile (multi-region / failover routing)"
  type        = bool
  default     = false
}

variable "enable_container_insights" {
  description = "Monitoring option A: Log Analytics Container Insights (oms_agent) on AKS"
  type        = bool
  default     = true
}

variable "enable_managed_prometheus_grafana" {
  description = "Monitoring option B: Azure Managed Prometheus (AMW) + Managed Grafana"
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "Log Analytics retention in days"
  type        = number
  default     = 30
}

variable "tags" {
  description = "Common resource tags"
  type        = map(string)
  default     = {}
}
