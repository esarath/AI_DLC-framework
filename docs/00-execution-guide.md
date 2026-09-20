# 00 — Execution Guide (start here)

A step-by-step runbook to go from zero → running webapp on AKS via the AI-DLC pipeline.
Total time for **dev**: ~60–90 min. Estimated cost while running: **~$0.50–0.70/hour** (see §6).

> Deep-dive docs: `02-hld.md` (design) · `03-lld.md` (technical reference) ·
> `07-validation-checklists.md` (verification)

---

## Step 0 — Pre-flight (≈ 15 min)

You need these tools on your machine:

| Tool | Check command | Install hint |
|------|---------------|--------------|
| Azure CLI | `az version` | RHEL/CentOS: `packages-microsoft-prod` yum repo → `sudo dnf install azure-cli` · Debian/Ubuntu: `curl -sL https://aka.ms/InstallAzureCLIDeb \| sudo bash` |
| GitHub CLI | `gh --version` | `sudo dnf install gh` / `brew install gh` |
| Terraform | `terraform version` (≥1.6) | RHEL/CentOS: `sudo dnf config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo && sudo dnf install terraform` |
| kubectl | `kubectl version --client` | `az aks install-cli` |
| kustomize | `kubectl kustomize --help` | built into kubectl ✅ |
| argocd CLI | `argocd version --client` | `curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64 && chmod +x /usr/local/bin/argocd` |
| docker | `docker version` | `sudo dnf install docker-ce` — only needed for local image builds (CI builds in the cloud) |
| helm | `helm version` | optional — ArgoCD bootstrap uses plain `kubectl apply` |
| git | `git --version` | preinstalled |

Then log in to both clouds:

```bash
az login                  # headless box (no browser)? use: az login --use-device-code
az account set --subscription 995377ec-18d5-43bb-98db-74ab68a2ef8f
gh auth login
git clone https://github.com/esarath/AI_DLC-framework.git && cd AI_DLC-framework
```

✅ **You know it worked when:** `az account show` prints subscription `995377ec-…` and
`gh auth status` shows `esarath`.

---

## Step 1 — Wire GitHub ↔ Azure (≈ 10 min)

One script does everything: Entra app, OIDC credentials, secrets, environments, branch protection.

```bash
export JIRA_USER_EMAIL="esarath.mails@gmail.com"
export JIRA_API_TOKEN="<your-jira-token>"   # create at id.atlassian.com → Security → API tokens
./scripts/setup-github.sh
```

✅ **You know it worked when:** `gh secret list -R esarath/AI_DLC-framework` shows
`AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `JIRA_*`, and repo **Settings → Environments** lists
`dev`, `stage`, `prod`.

---

## Step 2 — Provision dev infrastructure (≈ 15–25 min)

```bash
cd terraform
terraform init
terraform apply -var-file=environments/dev.tfvars
# review the plan → type: yes
```

> ℹ️ The code targets **azurerm `~> 5.x`** (uses `node_provisioning_profile`,
> `certificate_name_check_enabled`, `auto_scaling_enabled`). If `init` resolves an older
> provider — or you see schema errors like *"Insufficient node_provisioning_profile
> blocks"* — run `terraform init -upgrade`.

This creates: `rg-aidlc-dev` → VNet → AKS (`aks-aidlc-dev`: system pool 1–2 + **Spot pool 2–5**) →
ACR `acraidlcdev` → App Gateway `agw-aidlc-dev` + public IP → Front Door `afd-aidlc-dev` →
Log Analytics + App Insights.

✅ **You know it worked when:** the apply ends with outputs like `aks_cluster_name`,
`acr_login_server`, `frontdoor_endpoint_hostname`. Then:

```bash
az aks get-credentials -g rg-aidlc-dev -n aks-aidlc-dev
kubectl get nodes    # expect: system + spot nodes Ready
```

> 💸 **Billing starts here.** Don't need it running yet? `terraform destroy` to stop (§7).

---

## Step 3 — Bootstrap ArgoCD (≈ 5–10 min)

```bash
cd ..
ENV=dev ./scripts/bootstrap-argocd.sh
```

Then connect the repo and open the UI:

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443 &
argocd login localhost:8080 --username admin --password <password-printed-by-script> --insecure
argocd repo add https://github.com/esarath/AI_DLC-framework.git --username git --password <GITHUB_PAT>
argocd app list
```

✅ **You know it worked when:** `webapp-dev`, `webapp-stage`, `webapp-prod` appear (stage/prod
will show `Missing`/not-synced until those clusters exist — that's fine).

---

## Step 4 — First deploy to dev (≈ 10 min)

The pipeline deploys automatically on merge to `main`. To trigger it now, make any tiny change:

```bash
echo "# deployed" >> docs/01-ai-dlc-overview.md
git checkout -b KAN-1-first-deploy
git add -A && git commit -m "KAN-1: trigger first dev deploy"
git push -u origin KAN-1-first-deploy
gh pr create --title "KAN-1: first deploy" --body "Trigger CI + GitOps"
```

Then: approve & merge the PR in GitHub → watch **Actions** tab → `ci.yml` builds, Trivy-scans,
pushes `webapp:sha-xxxxxxx` to ACR, and bumps `k8s/overlays/dev`. ArgoCD syncs within ~3 min.

✅ **You know it worked when:**

```bash
argocd app get webapp-dev                    # Synced / Healthy
ENV=dev ./scripts/smoke-test.sh              # PASS x3
curl http://aidlc-dev-ingress.eastus.cloudapp.azure.com/healthz
```

---

## Step 5 — Promote to stage / prod (≈ 15–25 min per env)

First provision the target cluster, then promote the image:

```bash
# one-time per env:
terraform apply -var-file=environments/stage.tfvars   # ~15-20 min
ENV=stage ./scripts/bootstrap-argocd.sh               # ~5 min
```

Then in GitHub → **Actions → "CD — promote image (stage / prod)" → Run workflow**:

| Field | stage | prod |
|-------|-------|------|
| `target_env` | `stage` | `prod` |
| `image_tag` | the `sha-xxxxxxx` from CI | same tag |
| `jira_issue` | `KAN-1` | `KAN-1` |

The run pauses on **environment approval** — approve it, it imports the image to the env's ACR,
commits the tag bump, ArgoCD syncs, smoke test runs, Jira transitions. For prod, set
`ARGOCD_SERVER`/`ARGOCD_AUTH_TOKEN` secrets first (script's final output explains how).

✅ **Done when:** `https://fde-aidlc-prod.azurefd.net` serves the app and the Jira issue shows
`Done`.

---

## 6. Timeline & cost summary

### Timeline

| Phase | Duration |
|-------|----------|
| Step 0 prereqs + logins | ~15 min |
| Step 1 GitHub/Azure wiring | ~10 min |
| Step 2 `terraform apply` (dev) | ~15–25 min |
| Step 3 ArgoCD bootstrap | ~5–10 min |
| Step 4 first dev deploy | ~10 min |
| **Dev total** | **≈ 60–90 min** |
| Step 5 per additional env (stage, prod) | +20–30 min each |
| **Full Dev→Stage→Prod** | **≈ 1.5–2.5 hrs** |

### Approximate running cost — dev environment

| Resource | Config | ≈ Cost/hr |
|----------|--------|-----------|
| AKS control plane | free tier | $0.00 |
| System node pool | 1 × D2s_v5 on-demand | $0.10 |
| **Spot node pool** | 2 × D4s_v5 Spot (60–80% off) | $0.08–0.16 |
| Application Gateway | Standard_v2, 2 CU | $0.26 |
| Public IP | Standard static | $0.005 |
| Front Door | Standard | $0.05 |
| ACR | Standard | $0.03 |
| Log Analytics + App Insights | minimal traffic | $0.01–0.05 |
| **Dev total** | | **≈ $0.55–0.65/hr (~$400–470/mo)** |
| + Option B (AMW + Grafana) | if enabled | +$0.10–0.20/hr |
| Prod adds | Traffic Manager + Premium ACR | +$0.10/hr |

> ⚠️ Prices are eastus list estimates — Spot pricing fluctuates. Verify current rates in the
> [Azure Pricing Calculator](https://azure.microsoft.com/pricing/calculator/). **App Gateway is
> the biggest fixed cost** — for a pure demo you can set `enable_agic = false` and use a
> `LoadBalancer` Service instead (~$0.20/hr savings).

---

## 7. Stop billing / tear down

```bash
cd terraform
terraform destroy -var-file=environments/dev.tfvars
```

Removes the whole resource group. Re-run Step 2 to recreate. (GitHub-side config from Step 1
persists — no need to redo it.)

---

## Troubleshooting quick hits

| Symptom | Fix |
|---------|-----|
| `az login` prints nothing for ~15 s | Headless host — it's falling back to device code. Wait for the prompt, or run `az login --use-device-code` |
| Schema errors (`node_provisioning_profile`, `certificate_name_check_enabled`, `max_surge` on Spot) | Code requires azurerm `~> 5.x` — `terraform init -upgrade` and re-validate |
| `terraform refresh` errors / prompts | Deprecated — use `terraform plan -refresh-only -var-file=...` (or just `plan`/`apply`, which refresh anyway) |
| `ErrCode_InsufficientVCPUQuota` on AKS create | Subscription vCPU cap — check `az vm list-usage -l <region>` per family + "Total Regional Low-priority" (Spot). dev.tfvars is already downsized for a 10-vCPU/3-Spot sub; restore doc sizes after a quota increase |
| `ServiceCidrOverlapExistingSubnetsCidr` | `service_cidr` must not overlap the VNet — `modules/aks` uses `10.240.0.0/16` (VNet is `10.0.0.0/16`) |
| `azure/login` fails in Actions | Check `AZURE_CLIENT_ID`/`TENANT_ID` secrets + fedcred subject matches `repo:esarath/AI_DLC-framework:environment:<env>` |
| Pods `ImagePullBackOff` | `AcrPull` role assignment — check `terraform apply` completed; `az aks check-acr` |
| Ingress has no address | AGIC identity needs Contributor on AppGW (auto-created in `modules/aks`) — wait ~5 min |
| ArgoCD app `OutOfSync` on dev | `argocd app sync webapp-dev`; check repo cred `argocd repo list` |
| Spot nodes evicted | Expected — autoscaler replaces them; PDB keeps ≥1 pod up. Watch: `kubectl get nodes -w` |
| Smoke test fails post-deploy | `cd-promote` auto-rolls back for prod; otherwise `ENV=<env> ./scripts/rollback.sh` |
