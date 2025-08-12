# ArgoCD Deployment Guide for Demo Application

## Overview
This guide provides instructions for deploying the Demo Spring Boot application using ArgoCD with GitOps principles.

## Prerequisites

1. **Kubernetes Cluster** with ArgoCD installed
2. **ArgoCD CLI** installed and configured
3. **GitHub Container Registry access** (for pulling images)
4. **StorageClass** named "standard" available in the cluster

## Quick Start

### 1. Deploy Single Application
```bash
# Apply the ArgoCD application
kubectl apply -f argocd-application.yml

# Check application status
argocd app get demo-app

# Sync the application
argocd app sync demo-app
```

### 2. Deploy Multiple Environments (ApplicationSet)
```bash
# Apply the ApplicationSet for multi-environment deployment
kubectl apply -f argocd-applicationset.yml

# Check ApplicationSet status
argocd appset get demo-app-environments
```

## File Structure

```
k8s/
├── argocd-application.yml      # Single environment ArgoCD app
├── argocd-applicationset.yml   # Multi-environment ApplicationSet
├── kustomization.yaml          # Kustomize configuration
├── namespaces.yaml            # Namespace definition
├── mariadb-pvc-standard.yml   # Database storage
├── mariadb-secrets.yml        # Database credentials
├── mariadb-configmap.yml      # Database initialization
├── mariadb.yml               # Database deployment
├── mariadb-init-check.yml    # Post-sync health check
├── demo-secrets.yml          # Application secrets
├── ghcr-secret.yml           # Registry credentials
└── deployment.yml            # Application deployment
```

## Sync Waves (Resource Ordering)

ArgoCD will deploy resources in the following order:

- **Wave 0**: Namespace, PVC, Secrets, ConfigMaps
- **Wave 1**: MariaDB deployment and service
- **Wave 2**: Demo application deployment
- **Wave 3**: Post-sync health checks

## Configuration

### Secrets Management

**Important**: The current secrets contain placeholder values. In production:

1. **MariaDB Secrets** (`mariadb-secrets.yml`):
   ```bash
   # Generate secure passwords
   ROOT_PASSWORD=$(openssl rand -base64 32)
   USER_PASSWORD=$(openssl rand -base64 32)
   
   # Update the secret
   kubectl create secret generic mariadb-secrets \
     --from-literal=root-password="$ROOT_PASSWORD" \
     --from-literal=user-password="$USER_PASSWORD" \
     --dry-run=client -o yaml | kubectl apply -f -
   ```

2. **GitHub Container Registry** (`ghcr-secret.yml`):
   ```bash
   # Create with actual GitHub token
   kubectl create secret docker-registry ghcr-creds \
     --docker-server=ghcr.io \
     --docker-username=Max2535 \
     --docker-password=$GITHUB_TOKEN \
     --docker-email=$GITHUB_EMAIL
   ```

3. **Application Secrets** (`demo-secrets.yml`):
   ```bash
   # Generate JWT secret
   JWT_SECRET=$(openssl rand -base64 64)
   
   # Update application secrets
   kubectl create secret generic demo-secrets \
     --from-literal=database-url="jdbc:mariadb://mariadb-service:3306/cardb" \
     --from-literal=database-username="caruser" \
     --from-literal=database-password="$USER_PASSWORD" \
     --from-literal=jwt-secret="$JWT_SECRET" \
     --dry-run=client -o yaml | kubectl apply -f -
   ```

### Environment Customization

To customize for different environments, modify:

1. **Image tags** in `kustomization.yaml`
2. **Replica counts** in `kustomization.yaml`
3. **Resource limits** in deployment files
4. **Environment variables** in `deployment.yml`

## Monitoring and Troubleshooting

### Check Application Status
```bash
# ArgoCD application status
argocd app get demo-app

# Kubernetes resources
kubectl get all -n demo

# Check pod logs
kubectl logs -f deployment/demo-app -n demo
kubectl logs -f deployment/mariadb -n demo
```

### Health Checks

The deployment includes:
- **Liveness probes** for both applications
- **Readiness probes** for proper traffic routing
- **Init containers** to wait for database availability
- **Post-sync hooks** to verify database setup

### Common Issues

1. **Image Pull Errors**: Verify `ghcr-creds` secret is correct
2. **Database Connection**: Check `mariadb-secrets` and network policies
3. **Storage Issues**: Verify `standard` StorageClass exists
4. **Sync Failures**: Check ArgoCD sync waves and dependencies

## CI/CD Integration

The application works with the GitHub Actions workflow in `.github/workflows/ci-cd.yml`:

1. **Build and test** on push/PR
2. **Build and push** Docker image to GHCR
3. **Update** image tag in GitOps repository
4. **ArgoCD auto-sync** deploys the new version

## Production Considerations

1. **Resource Limits**: Adjust CPU/memory based on actual usage
2. **Backup Strategy**: Implement database backup solution
3. **Security**: Use proper RBAC and network policies
4. **Monitoring**: Add Prometheus metrics and alerting
5. **Secrets**: Use external secret management (Vault, ESO)
6. **Storage**: Use appropriate StorageClass for production

## Cleanup

```bash
# Delete application
argocd app delete demo-app

# Or delete ApplicationSet
kubectl delete applicationset demo-app-environments -n argocd

# Manual cleanup if needed
kubectl delete namespace demo
```
