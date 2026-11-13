#!/usr/bin/env bash
set -euo pipefail

: "${RESOURCE_GROUP:=rg-argocd-36}"

echo "This will delete the Azure resource group '${RESOURCE_GROUP}' and ALL resources in it."
read -r -p "Type DELETE to continue: " CONFIRM
if [ "$CONFIRM" != "DELETE" ]; then
  echo "Cleanup cancelled."
  exit 0
fi

az group delete --name "$RESOURCE_GROUP" --yes --no-wait
echo "Deletion requested for resource group ${RESOURCE_GROUP}."
