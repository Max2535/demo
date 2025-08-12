#!/bin/bash
# Kubernetes Cluster Connection Troubleshooting Script

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 Kubernetes Cluster Connection Troubleshooting${NC}"
echo "=================================================="
echo ""

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to test cluster connectivity
test_cluster_connection() {
    echo -e "${CYAN}Testing cluster connection...${NC}"
    if kubectl cluster-info >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Cluster is accessible${NC}"
        return 0
    else
        echo -e "${RED}✗ Cannot access cluster${NC}"
        return 1
    fi
}

# Function to show cluster info
show_cluster_info() {
    echo -e "${BLUE}📊 Current Cluster Information:${NC}"
    echo "Current context: $(kubectl config current-context 2>/dev/null || echo 'None')"
    echo "Current cluster: $(kubectl config view --minify -o jsonpath='{.clusters[0].name}' 2>/dev/null || echo 'None')"
    echo "Current user: $(kubectl config view --minify -o jsonpath='{.users[0].name}' 2>/dev/null || echo 'None')"
    echo ""
}

# Step 1: Check if kubectl is installed
echo -e "${BLUE}Step 1: Checking kubectl installation...${NC}"
if command_exists kubectl; then
    echo -e "${GREEN}✓ kubectl is installed${NC}"
    kubectl version --client --short 2>/dev/null || kubectl version --client 2>/dev/null
else
    echo -e "${RED}✗ kubectl is not installed${NC}"
    echo ""
    echo -e "${YELLOW}Installing kubectl...${NC}"
    
    # Install kubectl based on OS
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        chmod +x kubectl
        sudo mv kubectl /usr/local/bin/
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # Mac OS
        brew install kubectl
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
        # Windows (Git Bash/MSYS)
        echo "Please install kubectl manually from: https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/"
        echo "Or use: choco install kubernetes-cli"
        echo "Or use: scoop install kubectl"
    fi
fi
echo ""

# Step 2: Check kubeconfig
echo -e "${BLUE}Step 2: Checking kubeconfig...${NC}"
KUBECONFIG_PATH="${KUBECONFIG:-$HOME/.kube/config}"
echo "Kubeconfig path: $KUBECONFIG_PATH"

if [ -f "$KUBECONFIG_PATH" ]; then
    echo -e "${GREEN}✓ Kubeconfig file exists${NC}"
    echo "File size: $(ls -lh "$KUBECONFIG_PATH" | awk '{print $5}')"
    echo "Last modified: $(ls -l "$KUBECONFIG_PATH" | awk '{print $6, $7, $8}')"
else
    echo -e "${RED}✗ Kubeconfig file not found${NC}"
    echo ""
    echo -e "${YELLOW}Creating kubeconfig directory...${NC}"
    mkdir -p "$(dirname "$KUBECONFIG_PATH")"
    
    echo -e "${CYAN}💡 How to get kubeconfig:${NC}"
    echo ""
    echo -e "${YELLOW}For Google Cloud (GKE):${NC}"
    echo "  gcloud container clusters get-credentials CLUSTER_NAME --zone=ZONE --project=PROJECT_ID"
    echo ""
    echo -e "${YELLOW}For Amazon Web Services (EKS):${NC}"
    echo "  aws eks update-kubeconfig --region REGION --name CLUSTER_NAME"
    echo ""
    echo -e "${YELLOW}For Microsoft Azure (AKS):${NC}"
    echo "  az aks get-credentials --resource-group RESOURCE_GROUP --name CLUSTER_NAME"
    echo ""
    echo -e "${YELLOW}For local clusters:${NC}"
    echo "  Minikube: minikube start"
    echo "  Kind: kind create cluster"
    echo "  Docker Desktop: Enable Kubernetes in settings"
    echo ""
    exit 1
fi
echo ""

# Step 3: Check available contexts
echo -e "${BLUE}Step 3: Checking available contexts...${NC}"
echo "Available contexts:"
kubectl config get-contexts || echo "No contexts available"
echo ""

# Step 4: Test current context
echo -e "${BLUE}Step 4: Testing current context...${NC}"
show_cluster_info

if test_cluster_connection; then
    echo -e "${GREEN}🎉 Cluster connection successful!${NC}"
    echo ""
    
    # Show cluster version
    echo -e "${CYAN}Cluster version:${NC}"
    kubectl version --short 2>/dev/null || kubectl version 2>/dev/null
    echo ""
    
    # Show cluster nodes
    echo -e "${CYAN}Cluster nodes:${NC}"
    kubectl get nodes 2>/dev/null || echo "Cannot retrieve nodes information"
    echo ""
    
    exit 0
else
    echo -e "${RED}❌ Cluster connection failed${NC}"
    echo ""
fi

# Step 5: Troubleshooting suggestions
echo -e "${BLUE}Step 5: Troubleshooting suggestions...${NC}"
echo ""

echo -e "${YELLOW}🔧 Common Solutions:${NC}"
echo ""

echo -e "${CYAN}1. Check if you have the right context:${NC}"
echo "   kubectl config get-contexts"
echo "   kubectl config use-context CONTEXT_NAME"
echo ""

echo -e "${CYAN}2. Check cluster status:${NC}"
echo "   # For local clusters"
echo "   minikube status"
echo "   docker ps  # Check if Docker Desktop Kubernetes is running"
echo ""

echo -e "${CYAN}3. Update kubeconfig:${NC}"
echo "   # Re-download cluster credentials"
echo "   # Use appropriate command for your cloud provider (shown above)"
echo ""

echo -e "${CYAN}4. Check network connectivity:${NC}"
echo "   # Test if cluster endpoint is reachable"
echo "   CLUSTER_ENDPOINT=\$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')"
echo "   curl -k \$CLUSTER_ENDPOINT/healthz"
echo ""

echo -e "${CYAN}5. Check authentication:${NC}"
echo "   # Verify your credentials haven't expired"
echo "   kubectl auth can-i get pods"
echo ""

echo -e "${CYAN}6. Reset kubectl context:${NC}"
echo "   kubectl config unset current-context"
echo "   kubectl config use-context WORKING_CONTEXT"
echo ""

# Step 6: Interactive context switching
echo -e "${BLUE}Step 6: Interactive context switching...${NC}"
echo ""

CONTEXTS=$(kubectl config get-contexts -o name 2>/dev/null)
if [ -n "$CONTEXTS" ]; then
    echo -e "${CYAN}Available contexts:${NC}"
    echo "$CONTEXTS" | nl
    echo ""
    
    read -p "Enter the number of context to switch to (or press Enter to skip): " choice
    
    if [ -n "$choice" ] && [ "$choice" -gt 0 ]; then
        SELECTED_CONTEXT=$(echo "$CONTEXTS" | sed -n "${choice}p")
        if [ -n "$SELECTED_CONTEXT" ]; then
            echo "Switching to context: $SELECTED_CONTEXT"
            kubectl config use-context "$SELECTED_CONTEXT"
            
            echo ""
            echo "Testing new context..."
            if test_cluster_connection; then
                echo -e "${GREEN}✓ Successfully connected with new context!${NC}"
                show_cluster_info
                exit 0
            else
                echo -e "${RED}✗ Still cannot connect with new context${NC}"
            fi
        fi
    fi
fi

# Step 7: Create local cluster option
echo -e "${BLUE}Step 7: Create local development cluster?${NC}"
echo ""

echo -e "${CYAN}Would you like to create a local development cluster?${NC}"
echo "1. Create minikube cluster"
echo "2. Create kind cluster"
echo "3. Skip"
echo ""

read -p "Select option (1-3): " cluster_choice

case $cluster_choice in
    1)
        echo -e "${YELLOW}Creating minikube cluster...${NC}"
        if command_exists minikube; then
            minikube start
            echo "Testing minikube connection..."
            sleep 5
            test_cluster_connection
        else
            echo -e "${RED}Minikube not installed. Please install from: https://minikube.sigs.k8s.io/docs/start/${NC}"
        fi
        ;;
    2)
        echo -e "${YELLOW}Creating kind cluster...${NC}"
        if command_exists kind; then
            kind create cluster --name demo-cluster
            echo "Testing kind connection..."
            sleep 5
            test_cluster_connection
        else
            echo -e "${RED}Kind not installed. Please install from: https://kind.sigs.k8s.io/docs/user/quick-start/${NC}"
        fi
        ;;
    3)
        echo "Skipping cluster creation"
        ;;
esac

echo ""
echo -e "${BLUE}📚 Additional Resources:${NC}"
echo "• Kubernetes documentation: https://kubernetes.io/docs/"
echo "• kubectl cheat sheet: https://kubernetes.io/docs/reference/kubectl/cheatsheet/"
echo "• Troubleshooting guide: https://kubernetes.io/docs/tasks/debug-application-cluster/"
echo ""

echo -e "${YELLOW}💡 Next Steps:${NC}"
echo "1. Ensure you have a working Kubernetes cluster"
echo "2. Configure kubectl to connect to your cluster"
echo "3. Run: kubectl cluster-info"
echo "4. If successful, run: ./master-setup.sh"
echo ""

if ! test_cluster_connection; then
    echo -e "${RED}❌ Cluster connection still not working${NC}"
    echo -e "${YELLOW}Please resolve the connection issue before proceeding with ArgoCD deployment${NC}"
    exit 1
else
    echo -e "${GREEN}✅ Cluster connection working!${NC}"
    echo -e "${CYAN}You can now proceed with: ./master-setup.sh${NC}"
    exit 0
fi
