# 09 — Monitoring Options (pick one, or run both)

Two monitoring stacks are available. Toggle them independently per environment in
`terraform/environments/<env>.tfvars` — **nothing is deleted**, both can coexist.

| | **Option A — Azure Monitor suite** (default) | **Option B — Managed Prometheus + Grafana** |
|---|---|---|
| Flag | `enable_container_insights = true` | `enable_managed_prometheus_grafana = true` |
| Backend | Log Analytics workspace + App Insights | Azure Monitor Workspace (AMW) + Azure Managed Grafana |
| Query language | KQL | **PromQL** |
| Agent | `oms_agent` (Container Insights) | `ama-metrics` (`monitor_metrics` addon) |
| Dashboards | Azure portal workbooks | Grafana (importable community dashboards) |
| Best for | Teams already on Azure Monitor / KQL alerting | Prometheus-native teams, OSS dashboard ecosystem |
| Cost driver | LAW ingestion + retention | AMW ingestion (per-sample) + Grafana Standard instance |

```hcl
# terraform/environments/<env>.tfvars
enable_container_insights         = true   # Option A
enable_managed_prometheus_grafana = true   # Option B (prod.tfvars has this ON)
```

## Option A — Azure Monitor (Container Insights + App Insights)

Always provisioned via `modules/monitoring` (LAW + App Insights are created regardless — App
Insights and alert queries need the workspace). The `enable_container_insights` flag controls only
the AKS `oms_agent` addon:

- `true` (default): container logs/metrics flow to `law-aidlc-<env>`; query with KQL.
- `false`: disable the agent to avoid double-ingestion cost when running Option B.

## Option B — Azure Managed Prometheus + Managed Grafana

Setting `enable_managed_prometheus_grafana = true` provisions (`modules/observability`):

| Resource | Name |
|----------|------|
| Azure Monitor Workspace (Prometheus store) | `amw-aidlc-<env>` |
| Data Collection Endpoint + Rule | `MSProm-<region>-aks-aidlc-<env>` |
| DCR ↔ AKS association | attaches ama-metrics scraping to the cluster |
| Managed Grafana | `grafana-aidlc-<env>` (Standard, SystemAssigned MI) |
| Cluster addon | `monitor_metrics` block on AKS (enables ama-metrics) |

After `terraform apply`:

```bash
terraform output grafana_endpoint        # open in browser, Entra ID SSO
terraform output prometheus_query_endpoint
```

### Scraping the sample app

`k8s/base/deployment.yaml` already carries pod annotations
(`prometheus.io/scrape`, `prometheus.io/port: 8080`, `prometheus.io/path: /metrics`) and the app
exposes a real `/metrics` endpoint (`http_requests_total`, `app_uptime_seconds`) — no extra config
needed for pod scraping. Cluster-level metrics (node/pod/kube state) flow automatically via
ama-metrics defaults.

### Useful Grafana dashboards to import

| Dashboard | Grafana.com ID |
|-----------|----------------|
| Kubernetes / Compute Resources / Cluster | 15757 |
| Kubernetes / Compute Resources / Namespace (Pods) | 15758 |
| AKS cluster health (Azure Monitor curated) | bundled in Managed Grafana under *Azure Monitor* dashboards |
| Node exporter / host metrics | 1860 |

### Sample PromQL queries

```promql
# Request rate per pod
sum(rate(http_requests_total{env="prod"}[5m])) by (pod)

# Spot pool capacity usage
sum by (node) (kube_node_status_capacity{resource="cpu"})

# Pods restarting (Spot eviction signal)
increase(kube_pod_container_status_restarts_total{namespace="webapp-prod"}[15m])
```

## Choosing

- **Cost-optimised single stack:** Option B only → set `enable_container_insights = false`.
- **Azure-native alerting + KQL:** Option A only (default dev/stage).
- **Recommended for prod (as configured):** both — App Insights for app traces, Prometheus/Grafana
  for metrics dashboards and ArgoCD sync-health panels.
