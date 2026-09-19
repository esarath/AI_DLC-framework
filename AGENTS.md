# AGENTS.md — AI-DLC Framework

Shared, always-on rules for AI coding agents (Devin, Claude Code, Windsurf Cascade, Codex)
working in this repository. Keep this file small — it loads every session.

## What this repo is

AI-DLC reference implementation: a Node.js webapp deployed to **Azure AKS** via
**Terraform + GitHub Actions + ACR + ArgoCD (GitOps)** across **dev → stage → prod**.
Full design: `docs/02-hld.md` (HLD + diagrams), `docs/03-lld.md` (LLD steps).

## Repo map

| Path | What lives here |
|------|-----------------|
| `app/` | Node 20 webapp (no deps), `src/index.js`, `test/*.test.js`, `Dockerfile` |
| `terraform/` | Root module + `modules/{network,aks,acr,frontdoor,trafficmanager,monitoring}` + `environments/*.tfvars` |
| `k8s/` | Kustomize `base/` + `overlays/{dev,stage,prod}` — **this is the GitOps desired state** |
| `argocd/` | AppProject + Application CRDs |
| `.github/workflows/` | `ci.yml`, `cd-promote.yml`, `terraform.yml`, `security-scan.yml`, `ai-pr-triage.yml` |
| `policies/` | Conftest Rego + Gatekeeper constraints + Checkov config |
| `scripts/` | `bootstrap-argocd.sh`, `rollback.sh`, `smoke-test.sh` |

## Commands

```bash
cd app && npm run lint && npm test              # app checks (must pass)
kubectl kustomize k8s/overlays/{dev,stage,prod} # render manifests (must build)
terraform fmt -check -recursive                 # in terraform/
terraform init -backend=false && terraform validate
conftest test /tmp/<env>.yaml -p policies/conftest   # policy check on rendered output
```

## Hard rules

1. **GitOps only.** Never add CI steps that `kubectl apply`/`helm install` to a cluster. CI
   mutates `k8s/overlays/*`; ArgoCD owns the cluster.
2. **Immutable image tags** (`sha-<short>`). Never `:latest` — OPA/Gatekeeper deny it.
3. **Jira key `KAN-n`** required in PR titles and release commits.
4. **No secrets, no tfstate, no kubeconfigs in commits.** Azure auth is OIDC-only.
5. **Environments are isolated**: `rg-aidlc-<env>`, `aks-aidlc-<env>`, `acraidlc<env>`,
   `webapp-<env>` namespace. Don't cross-wire them.
6. **Spot pool contract**: `min_count ≥ 2`, `max_count ≤ 5` — it's a stated requirement; don't
   regress it.
7. Prod `Application` stays **manual-sync**; dev/stage stay automated.
8. GitOps bot commits use `[skip ci]` to avoid pipeline loops.

## Before marking work done

- `npm test` green · `kubectl kustomize` builds for all 3 overlays · YAML parses ·
  `terraform fmt`/`validate` clean (if terraform changed)
- Update `docs/` when architecture, commands, or guardrails change
