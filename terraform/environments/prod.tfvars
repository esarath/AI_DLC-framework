subscription_id = "995377ec-18d5-43bb-98db-74ab68a2ef8f"
environment     = "prod"
location        = "eastus"
prefix          = "aidlc"

system_node_pool = {
  vm_size   = "Standard_D2s_v5"
  min_count = 2
  max_count = 3
}

spot_node_pool = {
  vm_size         = "Standard_D4s_v5"
  min_count       = 2
  max_count       = 5
  spot_max_price  = -1
  eviction_policy = "Delete"
}

acr_sku               = "Premium"
enable_agic           = true
enable_front_door     = true
enable_traffic_manager = true   # enable for multi-region / failover routing
log_retention_days    = 90

tags = {
  cost_center = "engineering"
  owner       = "esarath"
}
