#!/usr/bin/env bash
# Bootstrap ArgoCD on the AKS cluster and register the AI-DLC applications.
# Usage: ENV=dev ./scripts/bootstrap-argocd.sh
set -euo pipefail

ENV="${ENV:-dev}"
RG="rg-aidlc-${ENV}"
CLUSTER="aks-aidlc-${ENV}"
ARGOCD_VERSION="${ARGOCD_VERSION:-v2.12.4}"

echo ">> Fetching kubeconfig for ${CLUSTER} in ${RG}"
az aks get-credentials --resource-group "${RG}" --name "${CLUSTER}" --overwrite-existing

echo ">> Installing ArgoCD ${ARGOCD_VERSION}"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"

echo ">> Waiting for argocd-server to be ready"
kubectl rollout status deployment/argocd-server -n argocd --timeout=300s

echo ">> Applying AppProject + Applications"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
kubectl apply -f "${SCRIPT_DIR}/../argocd/project-ai-dlc.yaml"
kubectl apply -f "${SCRIPT_DIR}/../argocd/application-dev.yaml"
kubectl apply -f "${SCRIPT_DIR}/../argocd/application-stage.yaml"
kubectl apply -f "${SCRIPT_DIR}/../argocd/application-prod.yaml"

echo ">> Initial admin password (change immediately):"
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d; echo

cat <<'NEXT'
Next steps:
  1. Expose argocd-server (port-forward for quick access):
       kubectl port-forward svc/argocd-server -n argocd 8080:443
  2. Log in:  argocd login localhost:8080
  3. Add the GitHub repo credential (SSH deploy key or HTTPS PAT):
       argocd repo add https://github.com/esarath/AI_DLC-framework.git \
         --username git --password <PAT>
  4. Verify apps:  argocd app list && argocd app sync webapp-dev
NEXT
