#!/usr/bin/env bash
set -euo pipefail

: "${RESOURCE_GROUP:=rg-argocd-36}"
: "${LOCATION:=centralindia}"
: "${AKS_CLUSTER:=aks-argocd-36}"
: "${NODE_COUNT:=2}"

command -v az >/dev/null || { echo "Azure CLI (az) is required"; exit 1; }

az account show >/dev/null 2>&1 || {
  echo "Run 'az login' and select a subscription with 'az account set'."
  exit 1
}

az group create \
  --name "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --output table

az aks create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$AKS_CLUSTER" \
  --location "$LOCATION" \
  --node-count "$NODE_COUNT" \
  --enable-managed-identity \
  --generate-ssh-keys \
  --output table

az aks get-credentials \
  --resource-group "$RESOURCE_GROUP" \
  --name "$AKS_CLUSTER" \
  --overwrite-existing

kubectl get nodes -o wide
