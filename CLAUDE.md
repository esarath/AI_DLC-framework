# CLAUDE.md

Read **[AGENTS.md](AGENTS.md)** — it is the single source of project rules (repo map,
commands, hard rules, done-criteria). It applies in full.

Claude Code specifics:

- Prefer `kubectl kustomize k8s/overlays/<env>` over installing standalone kustomize.
- No terraform binary on this machine — write HCL carefully and note that `terraform validate`
  must run in CI (`terraform.yml`) or wherever terraform is available.
- The GitOps tag-bump commits in `k8s/overlays/*/kustomization.yaml` are made by CI
  (`ai-dlc-bot`, `[skip ci]`) — don't hand-edit `newTag` unless reproducing that step locally.
