#!/usr/bin/env bash
set -euo pipefail

RG=${1:-openemr-rg}
LOCATION=${2:-eastus}
PREFIX=${3:-openemr}

echo "Creating resource group $RG ($LOCATION)"
az group create -n "$RG" -l "$LOCATION" -o none

echo "Deploying Bicep template (synthetic data subset)"
az deployment group create -g "$RG" \
  -f synthetic-data/infra/main.bicep \
  -p namePrefix=$PREFIX mysqlPassword=$(openssl rand -base64 24) \
  -o table

echo "Fetch outputs"
LAST=$(az deployment group list -g "$RG" --query "[-1].name" -o tsv)
az deployment group show -g "$RG" -n "$LAST" --query properties.outputs