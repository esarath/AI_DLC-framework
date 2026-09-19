# 06 — Rollback Strategy

Three rungs, fastest → most complete. Prefer the highest rung that fits the situation.

## Rung 1 — GitOps revert (preferred, audited)

```bash
git revert <gitops-tag-bump-commit>   # e.g. "gitops(prod): release sha-abc1234"
git push
# ArgoCD detects drift and converges back automatically (dev/stage).
# For prod (manual sync):
argocd app sync webapp-prod
```

- **Pros:** fully audited in git history; desired state and actual state stay consistent.
- **Use when:** bad release discovered post-deploy and you can wait ~1 poll cycle (~3 min).

## Rung 2 — ArgoCD rollback (fast)

```bash
argocd app history webapp-prod            # find previous healthy revision ID
argocd app rollback webapp-prod <ID>
argocd app wait webapp-prod --health --timeout 300
```

- **Pros:** seconds to minutes; doesn't require a git commit.
- **Caveat:** creates drift vs git — follow up with a revert commit so the next sync doesn't
  redeploy the broken version.
- **Automated:** `cd-promote.yml` runs this automatically when the post-deploy smoke test fails.

## Rung 3 — kubectl rollout undo (break-glass)

```bash
kubectl -n webapp-prod rollout undo deployment/webapp --to-revision=<N>
kubectl -n webapp-prod rollout status deployment/webapp
```

- **Pros:** no ArgoCD dependency.
- **Caveat:** ArgoCD will show `OutOfSync`/`Drift` — must be reconciled with a git revert
  afterwards. `revisionHistoryLimit: 5` (deploy) / `20` (prod app) keeps history available.

## Helper script

```bash
ENV=prod ./scripts/rollback.sh [REVISION]
```

Picks ArgoCD path if authenticated, else `kubectl`; always ends with a smoke test.

## Infra rollback

- Terraform changes roll back by reverting the commit and re-running
  `terraform apply -var-file=environments/<env>.tfvars` (state file is authoritative).
- Destructive infra changes (VNet CIDR, cluster replacement) should be split into a dedicated PR
  with an explicit plan review — never bundled with app releases.

## Database / stateful changes

This app is stateless. When state is introduced, gate releases on backward-compatible schema
migrations (expand → migrate → contract) so app rollback never requires a DB rollback.

## Rollback validation checklist

See `docs/07-validation-checklists.md` §3 — includes a quarterly **rollback drill**.
