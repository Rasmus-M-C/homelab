# homelab-gitops (Flux)

Flux keeps the cluster in sync with this folder.

```
clusters/homelab/   entry point Flux watches
  flux-system/      created by `flux bootstrap`, don't edit
  infrastructure.yaml   cilium, cilium-config, local-path
  apps.yaml             one block per app
infrastructure/     cluster building blocks
apps/<name>/        one folder per app (incl. namespace.yaml + kustomization.yaml)
```

## Add an app
1. Create `apps/<name>/` with its manifests, a `namespace.yaml` and a `kustomization.yaml` listing them.
2. Add a block for it to `clusters/homelab/apps.yaml`.
3. Commit and push. `flux reconcile kustomization flux-system --with-source` applies it immediately.
