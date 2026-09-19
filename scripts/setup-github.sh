#!/usr/bin/env bash
# One-time GitHub + Azure wiring for the AI-DLC pipelines (LLD doc §1).
#
# Automates:
#   1. Entra app + service principal + Contributor role on the subscription
#   2. OIDC federated credentials (main branch, PRs, dev/stage/prod environments)
#   3. GitHub secrets + variables for Actions
#   4. GitHub Environments (dev / stage / prod) with reviewer + branch gates
#   5. Branch protection on main (PR + CODEOWNERS review, required checks)
#
# Prereqs: `az login` (subscription owner/contributor+UA) and `gh auth login`.
# Usage:   ./scripts/setup-github.sh
# Env vars: REPO, SUBSCRIPTION_ID, APP_NAME, REVIEWER (GitHub username),
#           JIRA_USER_EMAIL, JIRA_API_TOKEN (optional — set secrets if provided)
set -euo pipefail

REPO="${REPO:-esarath/AI_DLC-framework}"
SUBSCRIPTION_ID="${SUBSCRIPTION_ID:-995377ec-18d5-43bb-98db-74ab68a2ef8f}"
APP_NAME="${APP_NAME:-gh-ai-dlc-actions}"
REVIEWER="${REVIEWER:-${REPO%%/*}}"          # default: repo owner
JIRA_BASE_URL="${JIRA_BASE_URL:-https://adminebooks.atlassian.net}"

echo ">> Repo: ${REPO} | Subscription: ${SUBSCRIPTION_ID} | App: ${APP_NAME}"

# --- 1. Entra app + SP -------------------------------------------------------
APP_ID=$(az ad app list --display-name "${APP_NAME}" --query '[0].appId' -o tsv)
if [[ -z "${APP_ID}" ]]; then
  APP_ID=$(az ad app create --display-name "${APP_NAME}" --query appId -o tsv)
  echo ">> Created app registration ${APP_ID}"
else
  echo ">> App registration exists: ${APP_ID}"
fi

az ad sp create --id "${APP_ID}" >/dev/null 2>&1 || true

az role assignment create --assignee "${APP_ID}" --role Contributor \
  --scope "/subscriptions/${SUBSCRIPTION_ID}" >/dev/null 2>&1 \
  && echo ">> Contributor role assigned" \
  || echo ">> Contributor role assignment already exists"

# --- 2. OIDC federated credentials -------------------------------------------
add_fedcred() {
  local name="$1" subject="$2"
  if az ad app federated-credential list --id "${APP_ID}" \
       --query "[?subject=='${subject}']" -o tsv | grep -q .; then
    echo ">> fedcred '${name}' already exists"; return
  fi
  az ad app federated-credential create --id "${APP_ID}" --parameters "{
    \"name\": \"${name}\",
    \"issuer\": \"https://token.actions.githubusercontent.com\",
    \"subject\": \"${subject}\",
    \"audiences\": [\"api://AzureADTokenExchange\"]}" >/dev/null
  echo ">> fedcred '${name}' created"
}

add_fedcred "main"        "repo:${REPO}:ref:refs/heads/main"
add_fedcred "pr"          "repo:${REPO}:pull_request"
add_fedcred "env-dev"     "repo:${REPO}:environment:dev"
add_fedcred "env-stage"   "repo:${REPO}:environment:stage"
add_fedcred "env-prod"    "repo:${REPO}:environment:prod"

# --- 3. GitHub secrets + variables -------------------------------------------
TENANT_ID=$(az account show --tenant-id -o tsv)

gh secret set AZURE_CLIENT_ID   --body "${APP_ID}"         --repo "${REPO}"
gh secret set AZURE_TENANT_ID   --body "${TENANT_ID}"      --repo "${REPO}"
gh secret set JIRA_BASE_URL     --body "${JIRA_BASE_URL}"  --repo "${REPO}"
gh variable set AZURE_SUBSCRIPTION_ID --body "${SUBSCRIPTION_ID}" --repo "${REPO}"
echo ">> Secrets/variables set (AZURE_CLIENT_ID, AZURE_TENANT_ID, JIRA_BASE_URL, AZURE_SUBSCRIPTION_ID)"

if [[ -n "${JIRA_USER_EMAIL:-}" && -n "${JIRA_API_TOKEN:-}" ]]; then
  gh secret set JIRA_USER_EMAIL --body "${JIRA_USER_EMAIL}" --repo "${REPO}"
  gh secret set JIRA_API_TOKEN  --body "${JIRA_API_TOKEN}"  --repo "${REPO}"
  echo ">> Jira secrets set"
else
  echo "!! JIRA_USER_EMAIL / JIRA_API_TOKEN not exported — set them later:"
  echo "   gh secret set JIRA_USER_EMAIL -b<email> -R ${REPO}"
  echo "   gh secret set JIRA_API_TOKEN  -b<token> -R ${REPO}"
fi
echo "!! ARGOCD_SERVER / ARGOCD_AUTH_TOKEN — set after bootstrap-argocd.sh (LLD §3)"

# --- 4. GitHub Environments ----------------------------------------------------
REVIEWER_ID=$(gh api "users/${REVIEWER}" --jq .id)

mk_env() {
  local env="$1" reviewers="$2" wait="$3" protected="$4"
  gh api -X PUT "repos/${REPO}/environments/${env}" --input - >/dev/null <<EOF
{
  "wait_timer": ${wait},
  "reviewers": ${reviewers},
  "deployment_branch_policy": $([[ "${protected}" == "true" ]] \
      && echo '{"protected_branches":true,"custom_branch_policies":false}' || echo 'null')
}
EOF
  echo ">> environment '${env}' configured"
}

mk_env dev   "[]" 0 false
mk_env stage "[{\"type\":\"User\",\"id\":${REVIEWER_ID}}]" 0 true
mk_env prod  "[{\"type\":\"User\",\"id\":${REVIEWER_ID}}]" 5 true

# --- 5. Branch protection on main ----------------------------------------------
gh api -X PUT "repos/${REPO}/branches/main/protection" --input - >/dev/null <<'EOF'
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["test", "validate-plan"]
  },
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "required_approving_review_count": 1,
    "require_code_owner_reviews": true,
    "dismiss_stale_reviews": true
  },
  "restrictions": null,
  "required_linear_history": false,
  "allow_force_pushes": false,
  "allow_deletions": false
}
EOF
echo ">> branch protection on 'main' enabled (1 approval + CODEOWNERS + checks: test, validate-plan)"

cat <<'DONE'

Done. Remaining manual steps:
  1. Jira secrets (if not exported above): gh secret set JIRA_USER_EMAIL / JIRA_API_TOKEN
  2. terraform apply -var-file=environments/dev.tfvars      (LLD §2)
  3. ENV=dev ./scripts/bootstrap-argocd.sh                  (LLD §3)
  4. After bootstrap, set ARGOCD_SERVER + ARGOCD_AUTH_TOKEN secrets
DONE
