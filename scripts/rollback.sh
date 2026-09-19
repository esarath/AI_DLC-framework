#!/usr/bin/env bash
# Roll back the webapp to a previous revision.
# GitOps-first: prefer `git revert` on the k8s/ overlay and let ArgoCD converge.
# This script is the fast-path / break-glass option.
# Usage: ENV=prod ./scripts/rollback.sh [REVISION]
set -euo pipefail

ENV="${ENV:-dev}"
REVISION="${1:-}"
APP="webapp-${ENV}"
NS="webapp-${ENV}"

if command -v argocd >/dev/null 2>&1 && argocd account get-user-info >/dev/null 2>&1; then
  echo ">> Rolling back via ArgoCD"
  argocd app history "${APP}"
  if [[ -n "${REVISION}" ]]; then
    argocd app rollback "${APP}" "${REVISION}"
  else
    # roll back to previous revision in history
    PREV=$(argocd app history "${APP}" -o json | jq -r '.[-2].id')
    argocd app rollback "${APP}" "${PREV}"
  fi
  argocd app wait "${APP}" --health --timeout 300
else
  echo ">> argocd CLI not authenticated; falling back to kubectl rollout undo"
  kubectl -n "${NS}" rollout undo "deployment/webapp" ${REVISION:+--to-revision=${REVISION}}
  kubectl -n "${NS}" rollout status "deployment/webapp" --timeout=300s
fi

echo ">> Post-rollback smoke test"
"$(dirname "${BASH_SOURCE[0]}")/smoke-test.sh"
