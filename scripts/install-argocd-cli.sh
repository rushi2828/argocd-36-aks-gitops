#!/usr/bin/env bash
set -euo pipefail

: "${ARGOCD_VERSION:=v3.6.1}"
: "${INSTALL_DIR:=/usr/local/bin}"

OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"

case "${OS}-${ARCH}" in
  linux-x86_64|linux-amd64) ASSET="argocd-linux-amd64" ;;
  linux-aarch64|linux-arm64) ASSET="argocd-linux-arm64" ;;
  darwin-x86_64) ASSET="argocd-darwin-amd64" ;;
  darwin-arm64) ASSET="argocd-darwin-arm64" ;;
  *)
    echo "Unsupported platform: ${OS}-${ARCH}. Download the matching CLI from:"
    echo "https://github.com/argoproj/argo-cd/releases/tag/${ARGOCD_VERSION}"
    exit 1
    ;;
esac

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

curl -fsSL \
  "https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_VERSION}/${ASSET}" \
  -o "$TMP"

chmod +x "$TMP"
if [ -w "$INSTALL_DIR" ]; then
  install -m 0755 "$TMP" "${INSTALL_DIR}/argocd"
else
  sudo install -m 0755 "$TMP" "${INSTALL_DIR}/argocd"
fi

argocd version --client
