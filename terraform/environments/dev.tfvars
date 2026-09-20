subscription_id = "995377ec-18d5-43bb-98db-74ab68a2ef8f"
environment     = "dev"
location        = "eastus"
prefix          = "aidlc"

# NOTE (dev-only deviation from docs/02-hld.md + AGENTS.md spot contract):
# this subscription is capped at 10 regional + 3 low-priority vCPUs and has
# ZERO quota in the DSv5 family (checked via `az vm list-usage -l eastus`).
# Sizes below are the largest that fit. Restore D2s_v5/D4s_v5 + min2/max5
# after a quota increase is approved (portal → Quotas).
system_node_pool = {
  vm_size   = "Standard_D2s_v4" # DSv4 family has 10 free; DSv5 has 0
  min_count = 1
  max_count = 2
}

spot_node_pool = {
  vm_size         = "Standard_D2s_v4" # 3 low-priority vCPU cap → 1×2vCPU node max
  min_count       = 1                 # contract wants ≥2 — impossible under quota
  max_count       = 1
  spot_max_price  = -1
  eviction_policy = "Delete"
}

acr_sku                = "Standard"
enable_agic            = true
enable_front_door      = true
enable_traffic_manager = false
log_retention_days     = 30

# Monitoring: pick option A, option B, or both (docs/09-monitoring-options.md)
enable_container_insights         = true  # Option A: Log Analytics + App Insights
enable_managed_prometheus_grafana = false # Option B: Azure Managed Prometheus + Grafana

tags = {
  cost_center = "engineering"
  owner       = "esarath"
}
