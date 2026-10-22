# homelab-gitops (folder in the homelab repo)

Everything in this repo is deployed to the cluster by Argo CD.

```
bootstrap/   applied by hand once (root app, Argo CD UI service patch, repo secret)
apps/        one Argo CD Application per app; root app watches this folder
manifests/   plain Kubernetes YAML that some of those Applications point to
```

## Adding an app
1. Put its manifests in `manifests/<name>/` (or point at a Helm chart, like `apps/cilium.yaml`).
2. Add `apps/<name>.yaml`.
3. Commit and push. Argo CD picks it up within ~3 minutes.

Removing a file from `apps/` removes that app from the cluster.
