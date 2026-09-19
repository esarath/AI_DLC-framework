---
trigger: always_on
description: AI-DLC framework project conventions for Windsurf Cascade
---

# AI-DLC project rules

- Single source of truth for rules: **AGENTS.md** at repo root. Follow it.
- GitOps repo: change desired state in `k8s/overlays/{dev,stage,prod}` — never suggest
  `kubectl apply` against clusters from CI or scripts; ArgoCD reconciles.
- AKS workloads run on a **Spot node pool (min 2, max 5)** — Deployments must keep the spot
  toleration + preferred nodeAffinity in `k8s/base/deployment.yaml`.
- Image tags are immutable `sha-*`; CI bumps overlay `newTag` automatically.
- Reference Jira keys (`KAN-n`) in PR titles/commit messages.
- Verify before finishing: `cd app && npm test`, `kubectl kustomize k8s/overlays/dev`,
  `terraform fmt -check -recursive` (terraform not installed locally — note it).
- Never commit secrets, `*.tfstate`, or kubeconfigs; Azure auth is OIDC-only.
