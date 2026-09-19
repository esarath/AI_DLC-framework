## Summary

<!-- What does this PR change and why? Link the Jira issue: KAN-n -->

Jira: KAN-

## Change type

- [ ] App code (`app/`)
- [ ] Infrastructure (`terraform/`)
- [ ] GitOps manifests (`k8s/`)
- [ ] CI/CD (`.github/workflows/`)
- [ ] Docs

## AI-DLC gate checklist

- [ ] `npm test` passes locally (app changes)
- [ ] `terraform plan` reviewed (infra changes)
- [ ] Trivy / Checkov / Conftest findings reviewed
- [ ] Image tag strategy understood (GitOps bump is automatic for dev)
- [ ] Rollback path identified (`git revert` / `argocd app rollback` / `scripts/rollback.sh`)

## Deployment notes

<!-- Promotion target: dev (auto) → stage (manual dispatch) → prod (manual + approvals) -->
