# GitOps with Argo CD

This document explains how the GitOps workflow is implemented for this project.

## Overview

Our project follows the GitOps methodology using Argo CD, where:

1. Developers commit code to the application repository
2. CI pipeline builds and tests the code
3. CD pipeline builds a Docker image and pushes it to the registry
4. CI/CD updates the Kubernetes manifests in a separate configuration repository
5. Argo CD detects changes in the configuration repository
6. Argo CD automatically deploys the changes to Kubernetes
7. Argo CD continuously monitors the cluster and ensures it matches the desired state

## Repository Structure

- **Application Repository**: Contains the application code (this repository)
- **Configuration Repository**: Contains the Kubernetes manifests that Argo CD monitors
  - `production/`: Production environment manifests
  - `staging/`: Staging environment manifests

## Workflow

The workflow is automated through GitHub Actions:

1. On code changes to `main` or `develop` branches, the CI process builds and tests the code
2. If successful, a Docker image is built and pushed to GitHub Container Registry
3. The CI/CD pipeline updates the appropriate manifests in the configuration repository
4. Argo CD detects the changes and automatically syncs them to the Kubernetes cluster

## Setting Up Argo CD

### Prerequisites

- Kubernetes cluster with Argo CD installed
- GitHub repository for Kubernetes manifests
- GitHub Personal Access Token (PAT) with repository access

### Installation

1. Install Argo CD in your Kubernetes cluster:

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

2. Access the Argo CD UI:

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

3. Get the initial password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

4. Apply the Argo CD Application manifests:

```bash
kubectl apply -f .github/argocd/application.yaml
kubectl apply -f .github/argocd/staging-application.yaml
```

## Configuration

### GitHub Actions Secrets

The following secrets need to be set in the GitHub repository:

- `PAT_TOKEN`: Personal Access Token with repository access to update the configuration repository

### Argo CD Configuration

The Argo CD Applications are defined in `.github/argocd/` directory. These need to be applied to your Argo CD instance.

## Monitoring

Argo CD provides a dashboard where you can monitor the sync status of your applications and troubleshoot any issues.

## References

- [Argo CD Documentation](https://argo-cd.readthedocs.io/en/stable/)
- [GitOps Principles](https://www.gitops.tech/)
