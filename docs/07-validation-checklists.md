# 07 — Validation Checklists

## 1. Pre-deployment

### Code & PR
- [ ] PR title contains Jira key (`KAN-n`); AI triage comment shows no unresolved risk flags
- [ ] `npm test` green; `npm run lint` clean
- [ ] CODEOWNERS approval received; no unresolved review threads
- [ ] Trivy image scan: zero HIGH/CRITICAL (or documented exception + Jira ticket)
- [ ] Checkov clean on `terraform/`; Conftest clean on rendered overlays
- [ ] Image tag is immutable (`sha-*`), not `latest`

### Infrastructure
- [ ] `terraform plan` output reviewed by approver; no unexpected destroy/replace
- [ ] Spot pool `min_count ≥ 2`, `max_count ≤ 5` per requirement
- [ ] ACR `AcrPull` role assignment present for kubelet identity
- [ ] AGIC role assignments applied (Contributor on AppGW, Reader on RG, Network Contributor on subnet)
- [ ] Secrets/vars configured: `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`,
      `JIRA_*`, `ARGOCD_*` (prod)
- [ ] GitHub Environment reviewers configured for `stage` and `prod`

### Cluster readiness
- [ ] `kubectl get nodes` — spot pool Ready, `kubernetes.azure.com/scalesetpriority=spot` labels
- [ ] `argocd app list` — all three apps `Synced`/`Healthy`
- [ ] Ingress has AppGW-assigned address: `kubectl -n webapp-<env> get ingress`

## 2. Post-deployment (observability)

- [ ] Smoke test green: `ENV=<env> ./scripts/smoke-test.sh` (`/healthz`, `/readyz`, `/`)
- [ ] `kubectl -n webapp-<env> get pods` — all Ready, spread across nodes (`-o wide`)
- [ ] HPA live: `kubectl -n webapp-<env> get hpa` — metrics flowing
- [ ] Container Insights shows logs in `law-aidlc-<env>`; App Insights receiving requests
- [ ] *(if Option B enabled)* Grafana endpoint reachable (`terraform output grafana_endpoint`),
      AMW data source healthy, `http_requests_total` queryable for the webapp namespace
- [ ] ArgoCD app `Healthy`, `revisionHistory` updated
- [ ] Front Door endpoint returns 200: `https://fde-aidlc-<env>.azurefd.net`
- [ ] Jira issue transitioned (In Staging / Done) with deployment comment
- [ ] No elevated error rate / pod restarts after 15 min soak

## 3. Rollback test (run quarterly per env)

- [ ] Deploy a deliberately bad tag to **dev** (e.g. broken `/healthz` image)
- [ ] Verify smoke test fails → auto-rollback fires in `cd-promote` (or run `scripts/rollback.sh`)
- [ ] Confirm app healthy on previous revision within 5 min
- [ ] Confirm git state reconciled (revert commit pushed)
- [ ] Time-to-recover recorded in Jira ticket

## 4. Spot eviction drill

- [ ] `az vmss simulate-eviction` (or scale-in a spot node) on the spot pool
- [ ] PDB holds: `kubectl get pdb` — disruptions allowed respected
- [ ] Cluster autoscaler provisions replacement within ~5 min
- [ ] No user-facing downtime (watch smoke test in a loop during drill)

## 5. Security audit (monthly)

- [ ] `gh api repos/esarath/AI_DLC-framework` — secret scanning + Dependabot alerts triaged
- [ ] Gatekeeper constraints active: `kubectl get constraints`
- [ ] Azure Policy compliance on AKS ≥ 95%
- [ ] No `:latest` or `admin_enabled` ACR usage
- [ ] OIDC federated creds scoped to repo/env only — no wildcard subjects
