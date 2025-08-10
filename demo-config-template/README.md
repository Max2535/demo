# Demo Config Repository

This repository contains Kubernetes manifests for the demo application.

It is designed to work with Argo CD for GitOps-based deployments.

## Structure

- [production/](./production/) - Production environment manifests
- [staging/](./staging/) - Staging environment manifests

## GitOps Workflow

1. Changes to application code trigger builds in the application repository
2. CI/CD pipeline updates manifests in this repository with new image tags
3. Argo CD detects the changes and automatically deploys to the appropriate environment

## Setup

### Argo CD Application

To set up Argo CD to monitor this repository, apply the following manifest:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: demo-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/Max2535/demo-config.git
    targetRevision: HEAD
    path: production  # or staging
  destination:
    server: https://kubernetes.default.svc
    namespace: demo  # or demo-staging
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

## Environments

### Production

The production environment is deployed from the [production/](./production/) directory.

### Staging

The staging environment is deployed from the [staging/](./staging/) directory.
