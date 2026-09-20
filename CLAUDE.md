# CLAUDE.md

Read **[AGENTS.md](AGENTS.md)** — it is the single source of project rules (repo map,
commands, hard rules, done-criteria). It applies in full.

Claude Code specifics:

- Prefer `kubectl kustomize k8s/overlays/<env>` over installing standalone kustomize.
- Terraform is installed on the dev host — run `terraform fmt -check -recursive` and
  `terraform init -backend=false && terraform validate` locally before pushing; CI
  (`terraform.yml`) re-checks.
- The GitOps tag-bump commits in `k8s/overlays/*/kustomization.yaml` are made by CI
  (`ai-dlc-bot`, `[skip ci]`) — don't hand-edit `newTag` unless reproducing that step locally.
