# Argo CD 3.6 on Azure AKS: GitOps Demo

A focused, reproducible demo for deploying Argo CD **v3.6.1** to Azure Kubernetes Service (AKS), then deploying a sample application from Git and exploring selected Argo CD 3.6 changes.

> **Scope:** This repository contains manifests and scripts. It has not been executed against your Azure subscription. Review Azure region availability, quotas, permissions, and costs before provisioning resources.

## What this project demonstrates

- Provision a small AKS cluster.
- Install Argo CD v3.6.1 using the official non-HA installation manifest.
- Deploy the Guestbook sample using an Argo CD `Application`.
- Enable `ServerSideApply=true`, which in Argo CD 3.6 also opts the Application into Server-Side Diff unless explicitly disabled.
- Use a Helm chart with `_helpers.tpl` and demonstrate the v3.6 local server-side diff include defaults.
- Provide an optional custom health-check example showing `deletionMessage`.

## Architecture

```text
GitHub
  |
  | GitOps source
  v
Argo CD 3.6.1 (inside AKS)
  |
  +--> guestbook Application --> guestbook namespace
  |
  +--> demo-app Application  --> demo-app namespace
```

CI/image publishing is intentionally outside this focused demo. The sample Guestbook app uses the upstream example repository, while `demo-app` uses the Helm chart stored in this repository.

## Repository layout

```text
.
├── README.md
├── .gitignore
├── bootstrap/
│   ├── guestbook.yaml
│   └── demo-app.yaml
├── charts/
│   └── demo-app/
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
│           ├── _helpers.tpl
│           └── deployment.yaml
├── argocd/
│   └── argocd-cm-healthcheck-patch.yaml
├── scripts/
│   ├── create-aks.sh
│   ├── install-argocd.sh
│   ├── install-argocd-cli.sh
│   ├── deploy-apps.sh
│   ├── verify.sh
│   └── cleanup.sh

```

## Prerequisites

- Azure subscription and permission to create resource groups and AKS clusters.
- Azure CLI (`az`), `kubectl`, `git`, `helm`, `curl`.
- An Argo CD CLI matching the server release (the script installs v3.6.1 on Linux AMD64).
- GitHub repository containing this project, if deploying `demo-app` from your own repository.

Check tools:

```bash
az version
kubectl version --client
helm version
git --version
```

## 1. Create AKS

Set environment variables, then run the script:

```bash
export RESOURCE_GROUP="rg-argocd-36"
export LOCATION="centralindia"
export AKS_CLUSTER="aks-argocd-36"
export NODE_COUNT="2"

./scripts/create-aks.sh
```

The script creates a basic two-node cluster with a managed identity. This is a learning environment, not a production sizing recommendation. Azure charges apply while resources exist.

Fetch credentials manually if needed:

```bash
az aks get-credentials \
  --resource-group "$RESOURCE_GROUP" \
  --name "$AKS_CLUSTER" \
  --overwrite-existing

kubectl get nodes -o wide
```

Before installation, ensure your identity has sufficient Kubernetes permissions to create CRDs, ClusterRoles, ClusterRoleBindings, and namespaced resources:

```bash
kubectl auth can-i create customresourcedefinitions
kubectl auth can-i create clusterroles
kubectl auth can-i create deployments -n argocd
```

## 2. Install Argo CD 3.6.1

```bash
export ARGOCD_VERSION="v3.6.1"
./scripts/install-argocd.sh
```

The script uses the official version-pinned, non-HA manifest and server-side apply:

```bash
kubectl apply --server-side --force-conflicts \
  -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.6.1/manifests/install.yaml
```

Wait for the components:

```bash
kubectl get pods -n argocd -w
```

The initial install may take several minutes. Check deployments and services:

```bash
kubectl get deployments,statefulsets,services -n argocd
```

## 3. Access the UI

In one terminal:

```bash
kubectl port-forward -n argocd svc/argocd-server 8080:443
```

Open <https://localhost:8080>. The browser may warn about the self-signed certificate in this demo.

In another terminal, get the initial password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d
echo
```

Install the CLI (Linux AMD64):

```bash
./scripts/install-argocd-cli.sh
```

Login:

```bash
argocd login localhost:8080 \
  --username admin \
  --password '<INITIAL_PASSWORD>' \
  --insecure
```

Change the initial admin password after first login:

```bash
argocd account update-password
```

Do not expose the demo server publicly with the initial admin account.

## 4. Deploy Guestbook

The Guestbook `Application` points at the official Argo CD example repository. Apply it:

```bash
kubectl apply -f bootstrap/guestbook.yaml
```

Verify:

```bash
argocd app get guestbook
kubectl get all -n guestbook
```

Expected steady state: `Sync Status: Synced` and `Health Status: Healthy`. First reconciliation may take a short time.

### Argo CD 3.6: Server-Side Apply and Server-Side Diff

The Application includes:

```yaml
syncOptions:
  - CreateNamespace=true
  - ServerSideApply=true
```

In Argo CD 3.6, setting `ServerSideApply=true` also selects Server-Side Diff for comparison, unless the Application explicitly opts out with:

```yaml
metadata:
  annotations:
    argocd.argoproj.io/compare-options: ServerSideDiff=false
```

Inspect the Application:

```bash
kubectl get application guestbook -n argocd -o yaml
argocd app diff guestbook
```

To demonstrate a change, fork `https://github.com/argoproj/argocd-example-apps`, change a manifest (for example, a Deployment replica count), push the change, and update `repoURL` and `targetRevision` in `bootstrap/guestbook.yaml` to your fork/branch. Then:

```bash
kubectl apply -f bootstrap/guestbook.yaml
argocd app get guestbook --refresh
argocd app diff guestbook
argocd app sync guestbook
```

Verify the changed resource:

```bash
kubectl get deployments -n guestbook
```

Server-Side Diff performs an apply dry-run against the Kubernetes API server. This can surface admission/validation behavior during diff, and increases API-server requests. Results are cached and recalculated on relevant refresh/revision/spec/resource changes. See the official upgrade guide.

## 5. Deploy the local Helm chart

First, push this repository to GitHub. Replace `<GITHUB_OWNER>` below with your account or organization.

Update `bootstrap/demo-app.yaml`:

```yaml
source:
  repoURL: https://github.com/<GITHUB_OWNER>/argocd-36-aks-gitops.git
  targetRevision: main
  path: charts/demo-app
```

Then apply:

```bash
kubectl apply -f bootstrap/demo-app.yaml
argocd app get demo-app
kubectl get deployment -n demo-app
```

You can also create the Application using the CLI:

```bash
argocd app create demo-app \
  --repo https://github.com/<GITHUB_OWNER>/argocd-36-aks-gitops.git \
  --path charts/demo-app \
  --revision main \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace demo-app \
  --sync-option CreateNamespace=true \
  --sync-policy automated \
  --self-heal \
  --auto-prune
```

Render the chart locally:

```bash
helm template demo-app ./charts/demo-app
```

### Argo CD 3.6: Helm local diff include defaults

Argo CD 3.6 changes the implicit `--local-include` defaults for:

```bash
argocd app diff demo-app \
  --local ./charts/demo-app \
  --server-side-generate
```

The default set now includes `*.tpl` and `Chart.lock` in addition to YAML/JSON patterns. This is useful for charts that use `_helpers.tpl` or pinned dependency versions in `Chart.lock`.

If you pass any `--local-include` options yourself, you replace the defaults. To preserve all defaults and add another pattern, specify the full set:

```bash
argocd app diff demo-app \
  --local ./charts/demo-app \
  --server-side-generate \
  --local-include "*.yaml" \
  --local-include "*.yml" \
  --local-include "*.json" \
  --local-include "*.tpl" \
  --local-include "Chart.lock" \
  --local-include "charts/**"
```

The last pattern is only needed if you want to include files under a chart's `charts/` directory.

## 6. Optional: custom health-check deletion message

Argo CD 3.6 adds support for a `deletionMessage` returned by a custom health check. The following ConfigMap is a **snippet** for `argocd-cm`; merge it into your existing `argocd-cm` rather than replacing the whole ConfigMap.

The example is deliberately generic and illustrates the Lua output shape. It does not install a custom resource or finalizer by itself.

```yaml
data:
  resource.customizations.health.example.com_Widget: |
    hs = {}
    hs.status = "Progressing"
    hs.message = "Waiting for widget reconciliation"
    if obj.metadata ~= nil and obj.metadata.deletionTimestamp ~= nil then
      hs.status = "Progressing"
      hs.message = "Resource is being deleted"
      hs.deletionMessage = "Waiting for example.com/cleanup finalizer"
    end
    return hs
```

Apply a merged ConfigMap manifest only after reviewing your current `argocd-cm` settings. Restart the relevant Argo CD component if required by your configuration and verify the health output in the UI.

## 7. Verification checklist

Run:

```bash
./scripts/verify.sh
```

Or individually:

```bash
kubectl get nodes
kubectl get pods -n argocd
kubectl get applications -n argocd
argocd version
argocd app list
argocd app get guestbook
argocd app get demo-app
kubectl get deployments -A
```

Expected outcomes:

- AKS nodes are `Ready`.
- Argo CD components become `Running`/`Ready`.
- `guestbook` and `demo-app` become `Synced`.
- Applications report `Healthy` once all their resources are ready.

## 8. Troubleshooting

| Symptom | Useful command |
|---|---|
| Argo CD pod pending | `kubectl describe pod -n argocd <pod>` |
| Repo fetch error | `kubectl logs -n argocd deploy/argocd-repo-server --tail=100` |
| Application OutOfSync | `argocd app diff <app>` |
| Application Degraded | `argocd app get <app>` |
| RBAC denied | `kubectl auth can-i <verb> <resource> -n argocd` |
| Helm render error | `helm template demo-app ./charts/demo-app` |
| UI unavailable | Check `kubectl get svc -n argocd` and port-forward process |

## 9. Cleanup

Delete the Azure resources when finished. This deletes the AKS cluster and any other resources in the resource group:

```bash
./scripts/cleanup.sh
```

Or run manually:

```bash
az group delete --name "$RESOURCE_GROUP" --yes --no-wait
```

## Official references

- [Argo CD v3.6.1 release](https://github.com/argoproj/argo-cd/releases/tag/v3.6.1)
- [Argo CD 3.5 to 3.6 upgrade guide](https://argo-cd.readthedocs.io/en/release-3.6/operator-manual/upgrading/3.5-3.6/)
- [AKS documentation](https://learn.microsoft.com/azure/aks/)
- [Argo CD example applications](https://github.com/argoproj/argocd-example-apps)

