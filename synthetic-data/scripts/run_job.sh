#!/usr/bin/env bash
set -euo pipefail

RG=${1:-openemr-rg}
CG_NAME=$(az container list -g "$RG" --query "[?contains(name,'synthea-cg')].name" -o tsv | head -n1)
if [[ -z "$CG_NAME" ]]; then
  echo "Container group not found" >&2
  exit 1
fi

echo "Restarting container group $CG_NAME"
az container restart -g "$RG" -n "$CG_NAME"
echo "Tailing logs (Ctrl+C to stop)"
az container logs -g "$RG" -n "$CG_NAME" --follow