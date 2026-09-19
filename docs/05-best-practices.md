# 05 — Best Practices

## Autoscaling (cluster + pods)

- **Two-dimension scaling:** cluster autoscaler grows the Spot pool (2→5 nodes) on pending pods;
  HPA grows pod count (2→10/15) on CPU. Tune HPA to scale *before* nodes saturate so new pods
  trigger node scale-up early.
- **Spot pool sizing:** `min_count=2` keeps ≥1 replica alive through a single-node eviction;
  `spot_max_price=-1` means evict on capacity reclaim, not price — cheapest steady state.
- **Stabilization:** 300s HPA scale-down window prevents thrash during Spot churn; `maxSurge=1`
  on upgrades avoids needing headroom.
- **Overprovision for prod:** prod HPA floor of 3 absorbs a full Spot node eviction + one AZ loss.
- **Fallback:** if Spot capacity is persistently unavailable in a region, add a small on-demand
  user pool and label-shift critical deployments (documented toggle in `variables.tf`).

## Pod-level resilience (already in `k8s/base`)

| Control | Why |
|---------|-----|
| Spot toleration + preferred nodeAffinity | Lands on Spot; can spill to system pool if Spot full |
| podAntiAffinity (hostname) | Replicas on different nodes |
| topologySpreadConstraints (zone) | Spread across AZs |
| PDB `minAvailable: 1` | Survive voluntary disruption / eviction |
| Requests/limits set | Autoscaler math works; OOM protection |
| startupProbe + readiness | No traffic until truly ready |

## Traffic management

- Single region → **AGIC + Front Door** is enough; add **Traffic Manager** only when a second
  region exists (DNS failover granularity).
- Keep health probes consistent end-to-end (`/healthz` at pod, AppGW probe, FD probe, TM probe)
  so a failing pod drops out of every layer.
- Prefer HTTPS-only at Front Door for prod (`HttpsOnly` forwarding + cert on AppGW).

## GitOps / CI-CD

- **Never `kubectl apply` from CI.** CI mutates git; ArgoCD owns cluster writes.
- **Image promotion by `az acr import`** — the digest tested in dev is the digest in prod.
- **Immutable tags** (`sha-<commit>`); `*-latest` only as a convenience pointer. OPA denies
  `:latest` in-cluster.
- **`revisionHistoryLimit`** on both Deployment and ArgoCD Application keeps rollback cheap.
- Keep ArgoCD `selfHeal` on for dev/stage; consider `manual`-only sync for prod (as configured).

## Security & compliance

- OIDC everywhere (GitHub→Azure, AKS→ACR/KeyVault) — zero long-lived secrets in CI.
- Non-root, read-only root FS, drop all caps — enforced by Conftest + Gatekeeper.
- Enable `local_account_disabled` + Entra RBAC on AKS for production hardening.
- Rotate: ACR tokens (none used — MSI), Jira PATs, ArgoCD tokens quarterly.
- Dependabot covers npm/Docker/GitHub Actions/Terraform weekly.

## AI-enabled DevOps workflow

- Let the AI-DLC agent do toil work: manifest diffs, release notes, triage summaries — but keep
  **approvals human** (environments, CODEOWNERS, Jira).
- Feed pipeline failures back to the agent (copy CI log excerpt) for root-cause drafts; validate
  before applying fixes.
- Use AI-generated tests as *additions*, not replacements, for human-reviewed assertions.
- Track AI-suggested changes through the same Jira key discipline — traceability doesn't stop
  being important because a machine wrote the diff.
