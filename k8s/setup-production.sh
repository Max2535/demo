#!/bin/bash
# Auto Production Setup Script for ArgoCD Deployment
# This script automates the production setup process

# Exit immediately if a command exits with a non-zero status
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script configuration
NAMESPACE=${NAMESPACE:-demo}
STORAGE_CLASS_NAME="standard"

echo -e "${BLUE}🚀 ArgoCD Production Setup Script${NC}"
echo "=================================="
echo ""

# Function to generate secure password
generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-25
}

# Function to generate JWT secret
generate_jwt_secret() {
    openssl rand -base64 64 | tr -d "=+/"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to base64 encode
b64encode() {
    echo -n "$1" | base64 -w 0
}

# Check prerequisites
echo -e "${BLUE}📋 Checking Prerequisites...${NC}"

if ! command_exists kubectl; then
    echo -e "${RED}✗ kubectl not found. Please install kubectl first.${NC}"
    exit 1
fi

if ! command_exists openssl; then
    echo -e "${RED}✗ openssl not found. Please install openssl first.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Prerequisites check passed${NC}"
echo ""

# Step 1: Check if cluster is accessible
echo -e "${BLUE}🔍 Step 1: Checking Kubernetes cluster access...${NC}"

if kubectl cluster-info >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Kubernetes cluster is accessible${NC}"
    CLUSTER_CONTEXT=$(kubectl config current-context)
    echo -e "${YELLOW}📍 Current context: ${CLUSTER_CONTEXT}${NC}"
else
    echo -e "${RED}✗ Cannot access Kubernetes cluster. Please check your kubeconfig.${NC}"
    echo ""
    echo -e "${YELLOW}🔧 Running kubectl connection troubleshooter...${NC}"
    if [ -f "fix-kubectl-connection.sh" ]; then
        chmod +x fix-kubectl-connection.sh
        ./fix-kubectl-connection.sh
        
        # Re-test after running fix script
        if kubectl cluster-info >/dev/null 2>&1; then
            echo -e "${GREEN}✓ Connection fixed! Continuing with setup...${NC}"
        else
            echo -e "${RED}✗ Could not fix connection. Please resolve manually.${NC}"
            exit 1
        fi
    else
        echo "Run: kubectl config get-contexts"
        echo "Then: kubectl config use-context <context-name>"
        exit 1
    fi
fi
echo ""

# Step 2: Get GitHub credentials
echo -e "${BLUE}🔑 Step 2: Setting up GitHub Container Registry credentials...${NC}"

if [ -z "$GITHUB_TOKEN" ]; then
    echo -e "${YELLOW}⚠ GITHUB_TOKEN environment variable not set${NC}"
    echo "Please provide your GitHub personal access token:"
    echo "💡 Create token at: https://github.com/settings/tokens"
    echo "Required scopes: read:packages, write:packages"
    read -s -p "GitHub Token: " GITHUB_TOKEN
    echo ""
fi

if [ -z "$GITHUB_USERNAME" ]; then
    echo "Enter your GitHub username (default: Max2535):"
    read -p "GitHub Username: " GITHUB_USERNAME
    GITHUB_USERNAME=${GITHUB_USERNAME:-Max2535}
fi

if [ -z "$GITHUB_EMAIL" ]; then
    echo "Enter your GitHub email:"
    read -p "GitHub Email: " GITHUB_EMAIL
fi

echo -e "${GREEN}✓ GitHub credentials collected${NC}"
echo ""

# Step 3: Create StorageClass
echo -e "${BLUE}💾 Step 3: Creating StorageClass 'standard'...${NC}"

# Check if StorageClass already exists
if kubectl get storageclass $STORAGE_CLASS_NAME >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠ StorageClass '$STORAGE_CLASS_NAME' already exists${NC}"
    kubectl get storageclass $STORAGE_CLASS_NAME
else
    echo "Creating StorageClass '$STORAGE_CLASS_NAME'..."
    
    # Detect cloud provider and create appropriate StorageClass
    CLUSTER_INFO=$(kubectl cluster-info)
    
    if echo "$CLUSTER_INFO" | grep -qi "gke\|google"; then
        # Google Kubernetes Engine
        cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: $STORAGE_CLASS_NAME
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: kubernetes.io/gce-pd
parameters:
  type: pd-standard
  replication-type: none
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
EOF
    elif echo "$CLUSTER_INFO" | grep -qi "eks\|amazon"; then
        # Amazon EKS
        cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: $STORAGE_CLASS_NAME
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: kubernetes.io/aws-ebs
parameters:
  type: gp3
  fsType: ext4
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
EOF
    elif echo "$CLUSTER_INFO" | grep -qi "aks\|azure"; then
        # Azure AKS
        cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: $STORAGE_CLASS_NAME
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: kubernetes.io/azure-disk
parameters:
  storageaccounttype: Standard_LRS
  kind: managed
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
EOF
    else
        # Generic/Local cluster (like minikube, kind, etc.)
        cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: $STORAGE_CLASS_NAME
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: kubernetes.io/host-path
volumeBindingMode: WaitForFirstConsumer
EOF
    fi
    
    echo -e "${GREEN}✓ StorageClass '$STORAGE_CLASS_NAME' created${NC}"
fi
echo ""

# Step 4: Generate secrets
echo -e "${BLUE}🔐 Step 4: Generating production secrets...${NC}"

DB_ROOT_PASSWORD=$(generate_password)
DB_USER_PASSWORD=$(generate_password)
JWT_SECRET=$(generate_jwt_secret)

echo -e "${GREEN}✓ Secure passwords generated${NC}"

# Step 5: Create namespace
echo -e "${BLUE}🏗️ Step 5: Creating namespace '$NAMESPACE'...${NC}"

if kubectl get namespace $NAMESPACE >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠ Namespace '$NAMESPACE' already exists${NC}"
else
    kubectl create namespace $NAMESPACE
    echo -e "${GREEN}✓ Namespace '$NAMESPACE' created${NC}"
fi
echo ""

# Step 6: Update secret files with real values
echo -e "${BLUE}🔄 Step 6: Updating secret files with production values...${NC}"

# Update mariadb-secrets.yml
cat > mariadb-secrets.yml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: mariadb-secrets
  labels:
    app: mariadb
  annotations:
    argocd.argoproj.io/sync-wave: "0"
type: Opaque
data:
  root-password: $(b64encode "$DB_ROOT_PASSWORD")
  user-password: $(b64encode "$DB_USER_PASSWORD")
EOF

# Update demo-secrets.yml
cat > demo-secrets.yml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: demo-secrets
  labels:
    app: demo-app
  annotations:
    argocd.argoproj.io/sync-wave: "0"
type: Opaque
data:
  database-url: $(b64encode "jdbc:mariadb://mariadb-service:3306/cardb")
  database-username: $(b64encode "caruser")
  database-password: $(b64encode "$DB_USER_PASSWORD")
  jwt-secret: $(b64encode "$JWT_SECRET")
EOF

# Create Docker config JSON for GHCR
DOCKER_CONFIG="{\"auths\":{\"ghcr.io\":{\"username\":\"$GITHUB_USERNAME\",\"password\":\"$GITHUB_TOKEN\",\"auth\":\"$(echo -n "$GITHUB_USERNAME:$GITHUB_TOKEN" | base64 -w 0)\"}}}"

# Update ghcr-secret.yml
cat > ghcr-secret.yml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: ghcr-creds
  labels:
    app: demo-app
  annotations:
    argocd.argoproj.io/sync-wave: "0"
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: $(echo -n "$DOCKER_CONFIG" | base64 -w 0)
EOF

echo -e "${GREEN}✓ Secret files updated with production values${NC}"
echo ""

# Step 7: Apply secrets to cluster
echo -e "${BLUE}🔧 Step 7: Applying secrets to cluster...${NC}"

kubectl apply -f mariadb-secrets.yml -n $NAMESPACE
kubectl apply -f demo-secrets.yml -n $NAMESPACE
kubectl apply -f ghcr-secret.yml -n $NAMESPACE

echo -e "${GREEN}✓ Secrets applied to cluster${NC}"
echo ""

# Step 8: Create production credentials file
echo -e "${BLUE}📝 Step 8: Creating production credentials file...${NC}"

cat > .production-credentials <<EOF
# Production Credentials - KEEP SECURE!
# Generated on: $(date)

DATABASE_ROOT_PASSWORD="$DB_ROOT_PASSWORD"
DATABASE_USER_PASSWORD="$DB_USER_PASSWORD" 
JWT_SECRET="$JWT_SECRET"
GITHUB_USERNAME="$GITHUB_USERNAME"
GITHUB_EMAIL="$GITHUB_EMAIL"
NAMESPACE="$NAMESPACE"
STORAGE_CLASS="$STORAGE_CLASS_NAME"

# Database Connection Info
DATABASE_URL="jdbc:mariadb://mariadb-service:3306/cardb"
DATABASE_USERNAME="caruser"
EOF

chmod 600 .production-credentials
echo -e "${GREEN}✓ Production credentials saved to .production-credentials${NC}"
echo ""

# Step 9: Verify setup
echo -e "${BLUE}✅ Step 9: Verifying setup...${NC}"

echo "Checking namespace..."
kubectl get namespace $NAMESPACE

echo "Checking StorageClass..."
kubectl get storageclass $STORAGE_CLASS_NAME

echo "Checking secrets..."
kubectl get secrets -n $NAMESPACE

echo -e "${GREEN}✓ Setup verification completed${NC}"
echo ""

# Final summary
echo -e "${GREEN}🎉 Production setup completed successfully!${NC}"
echo "=================================="
echo ""
echo -e "${BLUE}📋 Summary:${NC}"
echo "• ✅ Kubernetes cluster access verified"
echo "• ✅ StorageClass '$STORAGE_CLASS_NAME' ready"
echo "• ✅ Namespace '$NAMESPACE' created"
echo "• ✅ Production secrets generated and applied"
echo "• ✅ GitHub Container Registry access configured"
echo "• ✅ Credentials saved to .production-credentials"
echo ""
echo -e "${BLUE}🚀 Next Steps:${NC}"
echo "1. Deploy with ArgoCD:"
echo "   kubectl apply -f argocd-application.yml"
echo "2. Monitor deployment:"
echo "   argocd app get demo-app"
echo "3. Check application status:"
echo "   kubectl get pods -n $NAMESPACE"
echo ""
echo -e "${YELLOW}⚠️ Security Note:${NC}"
echo "• Keep .production-credentials file secure"
echo "• Add .production-credentials to .gitignore"
echo "• Rotate secrets periodically"
echo ""
echo -e "${GREEN}✨ Your application is ready for ArgoCD deployment!${NC}"
