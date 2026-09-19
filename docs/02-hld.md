# 02 — High-Level Design (HLD)

## 1. Solution overview

A delivery platform built following the **AI-DLC (AI-Driven Development Life Cycle)**
methodology, demonstrated with a containerised sample web application on **Azure AKS**:

- **Compute:** AKS with an on-demand *system* pool and a **Spot user pool (autoscale 2–5 nodes)**
- **Registry:** Azure Container Registry (ACR), one per environment
- **Ingress/traffic:** Application Gateway Ingress Controller (AGIC) → Azure Front Door →
  (optional) Traffic Manager
- **CI:** GitHub Actions — build, unit test, Trivy image scan, push to ACR
- **CD:** GitOps via **ArgoCD** — pull-based reconciliation of `k8s/` overlays
- **Governance:** Dev → Stage → Prod promotion with GitHub Environment approvals + Jira gates
- **Observability:** Log Analytics (Container Insights) + Application Insights
- **Guardrails:** Checkov (IaC), Trivy (images/fs), Conftest/OPA (manifests), CodeQL (source),
  Gatekeeper (in-cluster), Azure Policy (cluster add-on)

**Subscription:** `995377ec-18d5-43bb-98db-74ab68a2ef8f` · **Repo:**
`github.com/esarath/AI_DLC-framework` · **Jira:** `adminebooks.atlassian.net` project `KAN`

## 2. High-level architecture

```mermaid
flowchart TB
    subgraph Edge["Edge / Traffic"]
        TM["Traffic Manager<br/>(optional, multi-region)"]
        AFD["Azure Front Door<br/>WAF-capable, global LB, health probes"]
        AGW["Application Gateway<br/>(AGIC-managed, per env)"]
        TM --> AFD --> AGW
    end

    subgraph AKS["AKS cluster (per environment)"]
        subgraph SysPool["system node pool<br/>on-demand, 1–3 nodes"]
            SYSPODS["kube-system<br/>ArgoCD<br/>AGIC controller"]
        end
        subgraph SpotPool["spot node pool<br/>Spot VMs, autoscale 2–5"]
            APPPODS["webapp pods<br/>HPA 2→10 (prod 3→15)"]
        end
        AGW --> APPPODS
    end

    subgraph Platform["Platform services"]
        ACR[("ACR<br/>per env")]
        LAW[("Log Analytics<br/>Container Insights")]
        AI[("App Insights")]
        KV[("Key Vault<br/>(CSI secrets)")]
    end

    AKS --> ACR
    AKS --> LAW
    AKS --> AI
    AKS --> KV
```

## 3. GitOps flow

```mermaid
sequenceDiagram
    participant Dev as Developer
    participant GH as GitHub (main)
    participant CI as GitHub Actions CI
    participant ACR as ACR (dev)
    participant Argo as ArgoCD (in-cluster)
    participant AKS as AKS webapp-dev

    Dev->>GH: PR → merge to main
    GH->>CI: trigger ci.yml
    CI->>CI: lint • test • docker build • Trivy scan
    CI->>ACR: push webapp:sha-abc1234
    CI->>GH: commit tag bump → k8s/overlays/dev [skip ci]
    GH->>Argo: repo poll / webhook
    Argo->>AKS: sync diff (Kustomize build)
    Argo-->>Dev: sync status / health
```

Key property: **CI never touches the cluster.** It writes desired state to git; ArgoCD (inside the
cluster, with its own identity) pulls and applies. Rollback = revert the git commit.

## 4. CI/CD pipeline (promotion model)

```mermaid
flowchart LR
    PR["PR opened"] --> Gates1["Gates: tests · Trivy ·<br/>Checkov · Conftest · AI triage"]
    Gates1 -->|merge| Dev["DEV<br/>auto-deploy via<br/>ArgoCD auto-sync"]
    Dev -->|workflow_dispatch<br/>+ stage env approval| Stage["STAGE<br/>ACR import +<br/>ArgoCD sync"]
    Stage -->|workflow_dispatch<br/>+ prod env approval<br/>+ Jira approved| Prod["PROD<br/>manual ArgoCD sync<br/>+ smoke test"]
    Prod -->|smoke fail| RB["Auto-rollback<br/>argocd app rollback"]
```

| Env | Trigger | Approvals | ArgoCD sync | ACR |
|-----|---------|-----------|-------------|-----|
| dev | merge to `main` | PR review | automated (prune+selfHeal) | `acraidlcdev` |
| stage | `workflow_dispatch` | `stage` environment reviewers | automated | `acraidlcstage` |
| prod | `workflow_dispatch` | `prod` environment + Jira approval | manual (explicit `argocd app sync`) | `acraidlcprod` |

## 5. AKS cluster design

| Component | Choice | Rationale |
|-----------|--------|-----------|
| Node pools | `system` (on-demand D2s_v5, 1–3) + `spot` (D4s_v5, **2–5**) | System pods insulated from evictions; workloads ride cheap Spot capacity |
| Spot config | `eviction_policy=Delete`, `spot_max_price=-1` | Pay up to PAYG price; evict on capacity reclaim only |
| Spot isolation | Taint `scalesetpriority=spot:NoSchedule` + pod toleration | Only opted-in workloads land on Spot |
| Networking | Azure CNI + Azure network policy, dedicated `snet-aks` | Real pod IPs, NSG-capable |
| Ingress | AGIC addon managing a Standard_v2 App Gateway | L7 routing, AGIC reconciles from Ingress objects |
| Identity | SystemAssigned + OIDC issuer + workload identity | Keyless auth to ACR/Key Vault; GitHub OIDC for CI |
| Policy | `azure_policy_enabled` + Gatekeeper constraints | Prevent drift from guardrails |
| Secrets | Key Vault CSI driver w/ rotation | Secrets never in git |
| Monitoring | `oms_agent` → Log Analytics; App Insights | Container + app telemetry |

## 6. Monitoring & observability stack

```mermaid
flowchart TB
    subgraph Cluster
        APP["webapp pods"] --> OMS["Container Insights<br/>(oms_agent)"]
        ARGO["ArgoCD metrics"] --> OMS
        AGICM["AGIC metrics"] --> OMS
    end
    OMS --> LAW["Log Analytics workspace<br/>law-aidlc-<env>"]
    APP --> APPINS["Application Insights<br/>(appi-aidlc-<env>)"]
    LAW --> ALERTS["Azure Monitor alerts<br/>(CPU, pod restarts, Spot evictions)"]
    APPINS --> ALERTS
    ALERTS --> ACT["Action group →<br/>email / Teams / Jira automation"]

    subgraph OptB["Option B (toggle): Managed Prometheus + Grafana"]
        AMA["ama-metrics agent<br/>(monitor_metrics addon)"] --> AMW["Azure Monitor Workspace<br/>amw-aidlc-<env>"]
        APP -.->|"/metrics annotations"| AMA
        AMW --> GRAF["Managed Grafana<br/>grafana-aidlc-<env>"]
    end
```

**Alternate stack available:** set `enable_managed_prometheus_grafana = true` to provision Azure
Managed Prometheus (Azure Monitor Workspace + ama-metrics DCR pipeline) and Azure Managed Grafana —
standalone or alongside Option A. Full comparison and setup: `docs/09-monitoring-options.md`.

## 7. Environments & isolation

| Concern | dev | stage | prod |
|---------|-----|-------|------|
| Resource group | `rg-aidlc-dev` | `rg-aidlc-stage` | `rg-aidlc-prod` |
| AKS cluster | `aks-aidlc-dev` | `aks-aidlc-stage` | `aks-aidlc-prod` |
| Namespace | `webapp-dev` | `webapp-stage` | `webapp-prod` |
| ACR | `acraidlcdev` | `acraidlcstage` | `acraidlcprod` (Premium) |
| Front Door | yes | yes | yes + Traffic Manager |
| Log retention | 30d | 30d | 90d |
| Approvals | PR only | env reviewers | env reviewers + Jira |

## 8. Security & governance guardrails (summary)

| Layer | Control | Enforcement point |
|-------|---------|-------------------|
| Source | Branch protection on `main`, CODEOWNERS, PR template | GitHub |
| Source | Jira key in PR title (KAN-n) | AI triage workflow warns |
| CI | Unit tests, Trivy HIGH/CRITICAL fail, Checkov, Conftest | `ci.yml`, `terraform.yml`, `security-scan.yml` |
| Registry | `az acr import` promotion — image never rebuilt per env | `cd-promote.yml` |
| Cluster | Azure Policy addon, Gatekeeper constraints, read-only root FS | Terraform + `policies/` |
| Deploy | GitHub Environments approvals; Jira transition gates | `cd-promote.yml` |
| Runtime | HPA, PDB, Spot toleration + anti-affinity, health probes | `k8s/base/` |
| Post-deploy | Smoke test → auto `argocd app rollback` on failure | `cd-promote.yml`, `scripts/` |
