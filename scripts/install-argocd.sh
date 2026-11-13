#!/usr/bin/env bash
set -euo pipefail

: "${ARGOCD_VERSION:=v3.6.1}"

kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

kubectl apply \
  --server-side \
  --force-conflicts \
  -n argocd \
  -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"

echo "Argo CD ${ARGOCD_VERSION} manifests applied."
echo "Watch readiness with: kubectl get pods -n argocd -w"
