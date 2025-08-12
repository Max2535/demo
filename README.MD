# Demo Project

## Overview

This is a demo Spring Boot application that provides a car management API with MariaDB backend. The application can be deployed locally or in a Kubernetes environment.

## Prerequisites

- Java 17 or higher
- Maven 3.6.x or higher
- Spring Boot 3.x
- Docker and Docker Compose (for containerized development)
- Kubernetes cluster (for deployment)
- kubectl CLI

## Getting Started

### Local Development

1. Clone the repository
2. Navigate to the project directory
3. Run the application:

```bash
mvn spring-boot:run
```

### Docker Development

Use the included Docker Compose files for development:

```bash
# For development environment
docker-compose -f docker-compose.dev.yml up -d

# For production-like environment
docker-compose up -d
```

### Kubernetes Deployment

#### Cluster Requirements

- A running Kubernetes cluster (minikube, kind, GKE, AKS, EKS, etc.)
- kubectl configured to communicate with your cluster
- For GHCR images: a GitHub Personal Access Token with `read:packages` scope

#### Deployment Steps

1. Create a namespace for the application:

```bash
kubectl create namespace demo
```

1. Create Docker registry secret for GitHub Container Registry:

```bash
kubectl create secret docker-registry ghcr-creds \
  --namespace demo \
  --docker-server=ghcr.io \
  --docker-username=<your-github-username> \
  --docker-password=<your-github-token> \
  --docker-email=<your-email>
```

1. Deploy MariaDB database:

```bash
kubectl apply -f k8s/mariadb.yml -n demo
```

1. Wait for MariaDB to be ready:

```bash
kubectl wait --for=condition=ready pod -l app=mariadb -n demo --timeout=120s
```

1. Deploy the application:

```bash
kubectl apply -f k8s/deployment.yml -n demo
```

1. Check deployment status:

```bash
kubectl get all -n demo
```

1. Access the application:
   - For minikube: `minikube service demo-app-service -n demo`
   - For Ingress: Access via your configured domain (default: demo.example.com)

#### Notes

- The Ingress resource requires an Ingress Controller (like nginx-ingress) to be installed in the cluster
- For minikube: `minikube addons enable ingress`
- For SSL, cert-manager should be installed in the cluster

#### Custom Configuration

- Update the secrets in `k8s/deployment.yml` for production use
- Adjust resource limits and requests based on your environment
- Change the domain in the Ingress resource to your actual domain

## Project Structure

- `src/main/java` - Java source files
- `src/main/resources` - Configuration files and resources
- `src/test` - Test files
- `k8s/` - Kubernetes deployment manifests
- `docker-compose.yml` - Docker Compose configuration for local deployment

## CI/CD Pipeline

This project includes GitHub Actions workflows for:

- Building and testing the application
- Building and pushing Docker images to GitHub Container Registry
- Updating Kubernetes manifests in a GitOps repository

## Features

- RESTful API endpoints for car and owner management
- MariaDB database integration
- JWT authentication and authorization
- Kubernetes-ready with health checks and resource management
- GitOps deployment model

## Configuration

Configuration details can be found in:

- `application.properties` - Base application properties
- `application-docker.properties` - Docker-specific configuration
- `application-production.properties` - Production environment settings
- `application-test.properties` - Test environment configuration

## License

[MIT](https://opensource.org/licenses/MIT)