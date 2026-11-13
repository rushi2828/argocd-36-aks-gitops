#!/usr/bin/env bash
set -euo pipefail

echo "== Kubernetes context =="
kubectl config current-context

echo "== Nodes =="
kubectl get nodes -o wide

echo "== Argo CD workloads =="
kubectl get pods -n argocd

echo "== Applications =="
kubectl get applications -n argocd

echo "== Deployments across namespaces =="
kubectl get deployments -A

if command -v argocd >/dev/null 2>&1; then
  echo "== Argo CD CLI =="
  argocd version --client
  echo "== Argo CD applications =="
  argocd app list || true
fi
