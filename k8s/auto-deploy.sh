#!/bin/bash
# Auto ArgoCD Deployment Script
# This script deploys the application using ArgoCD after production setup

# Exit immediately if a command exits with a non-zero status
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE=${NAMESPACE:-demo}
APP_NAME="demo-app"
REPO_URL="https://github.com/Max2535/demo.git"

echo -e "${BLUE}🚀 Auto ArgoCD Deployment Script${NC}"
echo "================================="
echo ""

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to wait for deployment
wait_for_deployment() {
    local deployment_name=$1
    local namespace=$2
    echo "Waiting for deployment $deployment_name to be ready..."
    kubectl wait --for=condition=available deployment/$deployment_name -n $namespace --timeout=300s
}

# Check prerequisites
echo -e "${BLUE}📋 Checking Prerequisites...${NC}"

if ! command_exists kubectl; then
    echo -e "${RED}✗ kubectl not found${NC}"
    exit 1
fi

if ! command_exists argocd; then
    echo -e "${YELLOW}⚠ ArgoCD CLI not found. Installing...${NC}"
    # Download and install ArgoCD CLI
    curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
    sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
    rm argocd-linux-amd64
    echo -e "${GREEN}✓ ArgoCD CLI installed${NC}"
fi

echo -e "${GREEN}✓ Prerequisites check passed${NC}"
echo ""

# Check if production setup was run
echo -e "${BLUE}🔍 Checking Kubernetes cluster access...${NC}"

if kubectl cluster-info >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Kubernetes cluster is accessible${NC}"
    CLUSTER_CONTEXT=$(kubectl config current-context)
    echo -e "${YELLOW}📍 Current context: ${CLUSTER_CONTEXT}${NC}"
else
    echo -e "${RED}✗ Cannot access Kubernetes cluster${NC}"
    echo ""
    echo -e "${YELLOW}🔧 Running kubectl connection troubleshooter...${NC}"
    if [ -f "fix-kubectl-connection.sh" ]; then
        chmod +x fix-kubectl-connection.sh
        ./fix-kubectl-connection.sh
        
        # Re-test after running fix script
        if kubectl cluster-info >/dev/null 2>&1; then
            echo -e "${GREEN}✓ Connection fixed! Continuing with deployment...${NC}"
        else
            echo -e "${RED}✗ Could not fix connection. Please resolve manually.${NC}"
            exit 1
        fi
    else
        echo "Please ensure kubectl is configured correctly"
        exit 1
    fi
fi

echo -e "${BLUE}🔍 Checking production setup...${NC}"

if [ ! -f ".production-credentials" ]; then
    echo -e "${RED}✗ Production setup not found${NC}"
    echo "Please run setup-production.sh first"
    exit 1
fi

# Load production credentials
source .production-credentials
echo -e "${GREEN}✓ Production credentials loaded${NC}"
echo ""

# Check ArgoCD installation
echo -e "${BLUE}🔍 Checking ArgoCD installation...${NC}"

if ! kubectl get namespace argocd >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠ ArgoCD not installed. Installing ArgoCD...${NC}"
    
    # Install ArgoCD
    kubectl create namespace argocd
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    
    # Wait for ArgoCD to be ready
    echo "Waiting for ArgoCD to be ready..."
    kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s
    
    # Get ArgoCD admin password
    ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
    echo -e "${GREEN}✓ ArgoCD installed${NC}"
    echo -e "${YELLOW}📝 ArgoCD admin password: $ARGOCD_PASSWORD${NC}"
    
    # Save ArgoCD credentials
    echo "ARGOCD_PASSWORD=\"$ARGOCD_PASSWORD\"" >> .production-credentials
else
    echo -e "${GREEN}✓ ArgoCD already installed${NC}"
fi
echo ""

# Port forward ArgoCD server (in background)
echo -e "${BLUE}🌐 Setting up ArgoCD access...${NC}"

# Check if port-forward is already running
if ! pgrep -f "kubectl.*port-forward.*argocd-server" > /dev/null; then
    kubectl port-forward svc/argocd-server -n argocd 8080:443 > /dev/null 2>&1 &
    PORT_FORWARD_PID=$!
    sleep 5
    echo -e "${GREEN}✓ ArgoCD server accessible at https://localhost:8080${NC}"
else
    echo -e "${GREEN}✓ ArgoCD server already accessible${NC}"
fi

# Login to ArgoCD
echo -e "${BLUE}🔑 Logging into ArgoCD...${NC}"

if [ -z "$ARGOCD_PASSWORD" ]; then
    ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d 2>/dev/null || echo "")
fi

if [ -n "$ARGOCD_PASSWORD" ]; then
    argocd login localhost:8080 --username admin --password "$ARGOCD_PASSWORD" --insecure
    echo -e "${GREEN}✓ Logged into ArgoCD${NC}"
else
    echo -e "${YELLOW}⚠ Could not auto-login to ArgoCD. Please login manually:${NC}"
    echo "argocd login localhost:8080 --username admin --insecure"
fi
echo ""

# Deploy application
echo -e "${BLUE}🚀 Deploying application with ArgoCD...${NC}"

# Apply ArgoCD application
kubectl apply -f argocd-application.yml

echo -e "${GREEN}✓ ArgoCD application created${NC}"

# Wait a moment for application to be recognized
sleep 5

# Sync application
echo "Syncing application..."
argocd app sync $APP_NAME

# Wait for sync to complete
echo "Waiting for application to sync..."
argocd app wait $APP_NAME --timeout 600

echo -e "${GREEN}✓ Application synced successfully${NC}"
echo ""

# Check deployment status
echo -e "${BLUE}📊 Checking deployment status...${NC}"

echo "Namespace resources:"
kubectl get all -n $NAMESPACE

echo ""
echo "Application health:"
argocd app get $APP_NAME

echo ""
echo "Pod logs (last 10 lines):"
kubectl logs -l app=demo-app -n $NAMESPACE --tail=10 || echo "App not ready yet"

echo ""

# Wait for deployments to be ready
echo -e "${BLUE}⏳ Waiting for deployments to be ready...${NC}"

echo "Waiting for MariaDB..."
wait_for_deployment "mariadb" "$NAMESPACE"

echo "Waiting for Demo App..."
wait_for_deployment "demo-app" "$NAMESPACE"

echo -e "${GREEN}✓ All deployments are ready${NC}"
echo ""

# Get service information
echo -e "${BLUE}🌐 Service Information:${NC}"

echo "Services in namespace $NAMESPACE:"
kubectl get services -n $NAMESPACE

# Get ingress information if exists
if kubectl get ingress -n $NAMESPACE >/dev/null 2>&1; then
    echo ""
    echo "Ingress information:"
    kubectl get ingress -n $NAMESPACE
fi

echo ""

# Health check
echo -e "${BLUE}🏥 Running health checks...${NC}"

echo "Checking MariaDB connection..."
if kubectl exec -n $NAMESPACE deployment/mariadb -- mysqladmin ping > /dev/null 2>&1; then
    echo -e "${GREEN}✓ MariaDB is healthy${NC}"
else
    echo -e "${YELLOW}⚠ MariaDB health check failed${NC}"
fi

echo "Checking Demo App health..."
if kubectl get pods -n $NAMESPACE -l app=demo-app -o jsonpath='{.items[0].status.phase}' | grep -q "Running"; then
    echo -e "${GREEN}✓ Demo App is running${NC}"
else
    echo -e "${YELLOW}⚠ Demo App is not running yet${NC}"
fi

echo ""

# Final summary
echo -e "${GREEN}🎉 Deployment completed successfully!${NC}"
echo "================================="
echo ""
echo -e "${BLUE}📋 Deployment Summary:${NC}"
echo "• ✅ ArgoCD installed and configured"
echo "• ✅ Application deployed via GitOps"
echo "• ✅ All resources synchronized"
echo "• ✅ Health checks completed"
echo ""
echo -e "${BLUE}🔗 Access Information:${NC}"
echo "• ArgoCD UI: https://localhost:8080"
echo "• Username: admin"
echo "• Password: (saved in .production-credentials)"
echo ""
echo -e "${BLUE}🔧 Useful Commands:${NC}"
echo "• Check app status: argocd app get $APP_NAME"
echo "• View app logs: kubectl logs -f -l app=demo-app -n $NAMESPACE"
echo "• Check database: kubectl exec -it deployment/mariadb -n $NAMESPACE -- mysql -u caruser -p cardb"
echo "• Port forward app: kubectl port-forward svc/demo-app-service -n $NAMESPACE 8080:80"
echo ""
echo -e "${BLUE}📊 Monitoring:${NC}"
echo "• Watch pods: kubectl get pods -n $NAMESPACE -w"
echo "• ArgoCD sync status: argocd app list"
echo "• Application events: kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp'"
echo ""
echo -e "${GREEN}✨ Your application is now running with ArgoCD GitOps!${NC}"

# Cleanup port-forward on exit
cleanup() {
    if [ ! -z "$PORT_FORWARD_PID" ]; then
        kill $PORT_FORWARD_PID 2>/dev/null || true
    fi
}
trap cleanup EXIT
