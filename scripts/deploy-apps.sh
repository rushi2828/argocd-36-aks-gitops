#!/usr/bin/env bash
set -euo pipefail

kubectl apply -f bootstrap/guestbook.yaml

if grep -q '<GITHUB_OWNER>' bootstrap/demo-app.yaml; then
  echo "Skipping demo-app: replace <GITHUB_OWNER> in bootstrap/demo-app.yaml first."
else
  kubectl apply -f bootstrap/demo-app.yaml
fi

echo "Applications currently registered:"
kubectl get applications -n argocd
