#!/bin/bash
# Setup script for deploying the entire application

# Exit immediately if a command exits with a non-zero status
set -e

# Set namespace
NAMESPACE=demo

# Check if required environment variables are set
if [ -z "$GITHUB_USERNAME" ]; then
  echo "GITHUB_USERNAME environment variable is not set."
  export GITHUB_USERNAME="Max2535"  # Default to repo owner
fi

if [ -z "$GITHUB_EMAIL" ]; then
  echo "GITHUB_EMAIL environment variable is not set."
  export GITHUB_EMAIL="your.email@example.com"  # Placeholder
fi

if [ -z "$GITHUB_TOKEN" ]; then
  echo "GITHUB_TOKEN environment variable is not set."
  echo "Please set it with: export GITHUB_TOKEN=your_github_token"
  echo "You can create a token at https://github.com/settings/tokens"
  echo "Token needs at least 'read:packages' scope."
  
  read -p "Do you want to continue without setting GITHUB_TOKEN? (y/n): " continue_without_token
  if [ "$continue_without_token" != "y" ]; then
    exit 1
  fi
fi

# Create namespace first, before any other resources
echo "Creating namespace..."
kubectl create namespace $NAMESPACE || echo "Namespace '$NAMESPACE' already exists, continuing..."

# Create GitHub Container Registry credentials secret
echo "Creating GitHub Container Registry credentials..."
if [ -n "$GITHUB_TOKEN" ]; then
  kubectl create secret docker-registry ghcr-creds \
    -n $NAMESPACE \
    --docker-server=ghcr.io \
    --docker-username="$GITHUB_USERNAME" \
    --docker-password="$GITHUB_TOKEN" \
    --docker-email="$GITHUB_EMAIL" \
    --dry-run=client -o yaml | kubectl apply -f -
    
  if [ $? -ne 0 ]; then
    echo "Failed to create ghcr-creds secret."
    exit 1
  fi
else
  echo "Skipping ghcr-creds creation. You'll need to create it manually."
fi

# Create MariaDB secrets
echo "Creating MariaDB secrets..."
DB_ROOT_PASSWORD=$(openssl rand -base64 16)
DB_USER_PASSWORD=$(openssl rand -base64 16)

kubectl create secret generic mariadb-secrets \
  -n $NAMESPACE \
  --from-literal=root-password="$DB_ROOT_PASSWORD" \
  --from-literal=user-password="$DB_USER_PASSWORD" \
  --dry-run=client -o yaml | kubectl apply -f -

# Deploy MariaDB with the new PVC
echo "Deploying MariaDB..."
kubectl apply -f mariadb-pvc-standard.yml -n $NAMESPACE
kubectl apply -f mariadb.yml -n $NAMESPACE

# Wait for MariaDB to be ready
echo "Waiting for MariaDB to be ready..."
kubectl wait --for=condition=ready pod -l app=mariadb -n $NAMESPACE --timeout=180s

# Update demo-secrets with the generated passwords
echo "Creating application secrets..."
JWT_SECRET=$(openssl rand -base64 32)

kubectl create secret generic demo-secrets \
  -n $NAMESPACE \
  --from-literal=database-url="jdbc:mariadb://mariadb-service:3306/cardb" \
  --from-literal=database-username="caruser" \
  --from-literal=database-password="$DB_USER_PASSWORD" \
  --from-literal=jwt-secret="$JWT_SECRET" \
  --dry-run=client -o yaml | kubectl apply -f -

# Deploy the application
echo "Deploying application..."
kubectl apply -f deployment.yml -n $NAMESPACE

# Output connection information
echo ""
echo "Deployment completed successfully!"
echo ""
echo "Application credentials:"
echo "------------------------"
echo "Database Root Password: $DB_ROOT_PASSWORD"
echo "Database User Password: $DB_USER_PASSWORD"
echo "JWT Secret: $JWT_SECRET"
echo ""
echo "To access the application:"
echo "------------------------"
echo "kubectl port-forward svc/demo-app-service -n demo 8080:80"
echo "Then visit: http://localhost:8080"
echo ""
echo "To check deployment status:"
echo "------------------------"
echo "kubectl get all -n demo"
