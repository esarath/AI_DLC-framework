#!/usr/bin/env bash
# Smoke test the deployed webapp through its public ingress.
# Usage: ENV=dev ./scripts/smoke-test.sh   (or BASE_URL=http://host)
set -euo pipefail

ENV="${ENV:-dev}"
BASE_URL="${BASE_URL:-http://aidlc-${ENV}-ingress.eastus.cloudapp.azure.com}"

fail=0
for path in /healthz /readyz /; do
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "${BASE_URL}${path}" || echo "000")
  if [[ "${code}" =~ ^2 ]]; then
    echo "PASS  ${BASE_URL}${path} -> ${code}"
  else
    echo "FAIL  ${BASE_URL}${path} -> ${code}"
    fail=1
  fi
done

exit "${fail}"
