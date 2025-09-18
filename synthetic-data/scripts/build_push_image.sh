#!/usr/bin/env bash
set -euo pipefail

RG=${1:-openemr-rg}
IMAGE_NAME=${2:-synthea-job}
IMAGE_TAG=${3:-v1}

ACR_NAME=$(az acr list -g "$RG" --query "[0].name" -o tsv)
if [[ -z "$ACR_NAME" ]]; then
  echo "ACR not found in resource group $RG" >&2
  exit 1
fi

LOGIN_SERVER=$(az acr show -n "$ACR_NAME" --query loginServer -o tsv)
echo "Logging into ACR $ACR_NAME"
az acr login -n "$ACR_NAME"

echo "Building image $LOGIN_SERVER/$IMAGE_NAME:$IMAGE_TAG"
docker build -t "$LOGIN_SERVER/$IMAGE_NAME:$IMAGE_TAG" synthetic-data/container

docker push "$LOGIN_SERVER/$IMAGE_NAME:$IMAGE_TAG"
echo "Done"