# 03 — Low-Level Design (LLD) — step-by-step implementation

## 0. Prerequisites

| Tool | Version |
|------|---------|
| Azure CLI | ≥ 2.60 |
| Terraform | ≥ 1.6 (CI pins 1.9.8) |
| kubectl | ≥ 1.29 |
| kustomize | ≥ 5.x |
| argocd CLI | ≥ 2.12 |
| Node.js | ≥ 20 (local app dev) |

Azure subscription: **`995377ec-18d5-43bb-98db-74ab68a2ef8f`**

## 1. GitHub configuration

> **Automated path:** run `./scripts/setup-github.sh` (requires `az login` + `gh auth login`).
> It performs §1.1–§1.5: Entra app + OIDC creds, secrets/variables, environments with
> reviewers, and branch protection. The manual steps below remain as reference/verification.

### 1.1 Secrets (Settings → Secrets and variables → Actions)

| Secret | Purpose |
|--------|---------|
| `AZURE_CLIENT_ID` | Entra app / managed identity for OIDC login |
| `AZURE_TENANT_ID` | Entra tenant |
| `JIRA_BASE_URL` | `https://adminebooks.atlassian.net` |
| `JIRA_USER_EMAIL` | Jira service account email |
| `JIRA_API_TOKEN` | Jira API token (id.atlassian.com) |
| `ARGOCD_SERVER` | ArgoCD API endpoint (prod cluster) |
| `ARGOCD_AUTH_TOKEN` | ArgoCD service account token for `ai-dlc:deployer` role |

### 1.2 Variables

| Variable | Value |
|----------|-------|
| `AZURE_SUBSCRIPTION_ID` | `995377ec-18d5-43bb-98db-74ab68a2ef8f` |

### 1.3 OIDC (no stored Azure secrets)

```bash
az ad app create --display-name gh-ai-dlc-actions
APP_ID=$(az ad app list --display-name gh-ai-dlc-actions --query '[0].appId' -o tsv)
az ad sp create --id "$APP_ID"
az role assignment create --assignee "$APP_ID" --role Contributor \
  --scope "/subscriptions/995377ec-18d5-43bb-98db-74ab68a2ef8f"
az ad app federated-credential create --id "$APP_ID" --parameters '{
  "name":"main-branch",
  "issuer":"https://token.actions.githubusercontent.com",
  "subject":"repo:esarath/AI_DLC-framework:ref:refs/heads/main",
  "audiences":["api://AzureADTokenExchange"]}'
# repeat with subject "repo:esarath/AI_DLC-framework:environment:dev|stage|prod"
```

### 1.4 GitHub Environments (Settings → Environments)

Create `dev`, `stage`, `prod`:

- **stage** — required reviewers: team leads
- **prod** — required reviewers: ≥ 2, wait timer 5 min, restrict to `main` branch
- **dev** — no reviewers (auto)

### 1.5 Branch protection on `main`

Require PR + 1 approval, require status checks (`test`, `validate-plan`), require CODEOWNERS
review, block force-push.

## 2. Provision infrastructure (per environment)

```bash
az login
az account set --subscription 995377ec-18d5-43bb-98db-74ab68a2ef8f

cd terraform
terraform init            # add -backend-config args if remote state enabled

# DEV
terraform apply -var-file=environments/dev.tfvars
# repeat for stage / prod when promoted
```

**What gets created (dev):**

| Resource | Name |
|----------|------|
| Resource group | `rg-aidlc-dev` |
| VNet + subnets | `vnet-aidlc-dev` (`snet-aks` /20, `snet-appgw` /24) |
| AKS | `aks-aidlc-dev` — system pool 1–2, **spot pool 2–5** |
| App Gateway + PIP | `agw-aidlc-dev`, `pip-aidlc-dev-ingress` (FQDN `aidlc-dev-ingress.eastus.cloudapp.azure.com`) |
| ACR | `acraidlcdev` |
| Front Door | `afd-aidlc-dev` + endpoint `fde-aidlc-dev` |
| Log Analytics + App Insights | `law-aidlc-dev`, `appi-aidlc-dev` |

**RBAC wired automatically:** kubelet → `AcrPull` on ACR; AGIC identity → Contributor on AppGW,
Reader on RG, Network Contributor on AppGW subnet.

## 3. Bootstrap ArgoCD

```bash
ENV=dev ./scripts/bootstrap-argocd.sh
```

Installs ArgoCD v2.12.x into `argocd` ns, applies `argocd/project-ai-dlc.yaml` and the three
`Application` CRDs (`webapp-dev`, `webapp-stage`, `webapp-prod`).

Add repo credentials so ArgoCD can pull:

```bash
argocd repo add https://github.com/esarath/AI_DLC-framework.git --username git --password <PAT>
```

For prod ArgoCD API access from CI (`ARGOCD_AUTH_TOKEN`), create a service account token bound to
the `deployer` role defined in the AppProject.

## 4. Application manifests (what ArgoCD applies)

`k8s/base/` defines the shared desired state; each overlay pins namespace, replica count, HPA
bounds, and the ACR image:

- **Deployment** — non-root, read-only FS, dropped caps, requests `100m/128Mi`, limits
  `500m/256Mi`, liveness/readiness/startup probes on `/healthz` `/readyz`, Spot toleration +
  preferred node affinity + pod anti-affinity + zone spread.
- **Service** — `ClusterIP:80` → pods `:8080` (App Gateway fronts it).
- **HPA** — CPU 70% target; dev/stage 2–10, prod 3–15 pods.
- **PDB** — `minAvailable: 1`.
- **Ingress** — `kubernetes.io/ingress.class: azure/application-gateway` (AGIC claims it).

## 5. CI/CD behaviour

| Pipeline | Trigger | Steps |
|----------|---------|-------|
| `ci.yml` | PR + push to `main` | lint → unit tests → docker build → **Trivy (fail ≥HIGH)** → push to `acraidlcdev` → bump `overlays/dev` tag → commit `[skip ci]` |
| `terraform.yml` | PR/push touching `terraform/`, dispatch | fmt → validate → **Checkov** → plan per env; apply only via dispatch + env approval |
| `cd-promote.yml` | `workflow_dispatch` | `az acr import` dev→stage→prod → bump overlay tag → commit → smoke test → (prod) ArgoCD sync → auto-rollback on failure → Jira transitions |
| `security-scan.yml` | weekly + dispatch | Conftest on rendered manifests, Trivy fs scan, CodeQL |
| `ai-pr-triage.yml` | PR opened/updated | posts change summary + risk flags + gate checklist |

## 6. End-to-end flow (a release)

1. Dev opens PR titled `KAN-12: add /version endpoint`. AI triage comments; CI runs tests + Trivy
   (build not pushed on PR).
2. PR approved (CODEOWNERS) → merged. CI builds `webapp:sha-abc1234`, scans, pushes to
   `acraidlcdev`, bumps `k8s/overlays/dev`, commits. **ArgoCD auto-syncs dev.**
3. Release manager dispatches `cd-promote` → `target_env=stage`, `image_tag=sha-abc1234`,
   `jira_issue=KAN-12`. `stage` environment approval → image imported to `acraidlcstage`, overlay
   bumped, ArgoCD syncs stage, smoke test runs, Jira → *In Staging*.
4. Dispatch `cd-promote` → `prod`. `prod` environment approval (+ Jira check) → image imported to
   `acraidlcprod`, overlay bumped, `argocd app sync webapp-prod`, smoke test; on failure auto
   `argocd app rollback`. Jira → *Done*.

## 7. File-by-file reference

| File | Purpose |
|------|---------|
| `terraform/modules/aks/main.tf` | Cluster, spot pool, AppGW+AGIC, RBAC |
| `terraform/modules/frontdoor/main.tf` | AFD profile/endpoint/origin/route → AppGW FQDN |
| `terraform/modules/trafficmanager/main.tf` | Optional multi-region failover profile |
| `k8s/base/deployment.yaml` | Pod spec, probes, Spot toleration, security context |
| `k8s/overlays/*/kustomization.yaml` | Per-env namespace, replicas, image tag |
| `argocd/application-*.yaml` | ArgoCD App CRDs (auto-sync dev/stage, manual prod) |
| `.github/workflows/*.yml` | Pipelines described in §5 |
| `policies/conftest/deployment.rego` | OPA rules (resources, no :latest, Spot toleration) |
| `policies/gatekeeper/*.yaml` | In-cluster admission constraints |
| `scripts/rollback.sh` / `smoke-test.sh` | Ops runbook automation |

## 8. Configuration inputs summary

```hcl
# terraform/environments/dev.tfvars (excerpt)
spot_node_pool = {
  vm_size   = "Standard_D4s_v5"
  min_count = 2          # requirement: min 2
  max_count = 5          # requirement: max 5
  spot_max_price  = -1   # capacity-only eviction
  eviction_policy = "Delete"
}
```

> **Istio note:** intentionally **not** used — AGIC + Front Door cover L7 ingress/global routing;
> service-mesh features (mTLS, traffic splitting) aren't required for this app. The module layout
> leaves room to add it later without restructuring.
