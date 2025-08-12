#!/bin/bash
# Quick Fix Script for Local Development Environment

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Quick Fix for Local Development Environment${NC}"
echo "=============================================="
echo ""

# Function to check if Docker is running
check_docker() {
    if docker ps >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Docker is running${NC}"
        return 0
    else
        echo -e "${RED}✗ Docker is not running${NC}"
        return 1
    fi
}

# Function to start Docker Desktop on Windows
start_docker_windows() {
    echo -e "${YELLOW}📦 Starting Docker Desktop...${NC}"
    
    # Try different methods to start Docker Desktop
    if command -v "Docker Desktop.exe" >/dev/null 2>&1; then
        "Docker Desktop.exe" &
    elif [ -f "/c/Program Files/Docker/Docker/Docker Desktop.exe" ]; then
        "/c/Program Files/Docker/Docker/Docker Desktop.exe" &
    elif [ -f "/mnt/c/Program Files/Docker/Docker/Docker Desktop.exe" ]; then
        "/mnt/c/Program Files/Docker/Docker/Docker Desktop.exe" &
    else
        echo -e "${YELLOW}Please start Docker Desktop manually${NC}"
        echo "Look for Docker Desktop in your Start menu or taskbar"
    fi
    
    echo "Waiting for Docker to start..."
    for i in {1..30}; do
        if check_docker; then
            echo -e "${GREEN}✓ Docker started successfully${NC}"
            return 0
        fi
        echo "Waiting... ($i/30)"
        sleep 5
    done
    
    echo -e "${RED}✗ Docker failed to start${NC}"
    return 1
}

# Step 1: Check Docker status
echo -e "${BLUE}Step 1: Checking Docker status...${NC}"
if check_docker; then
    echo -e "${GREEN}Docker is ready!${NC}"
else
    echo -e "${YELLOW}Docker is not running. Attempting to start...${NC}"
    if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
        start_docker_windows
    else
        echo -e "${YELLOW}Please start Docker manually:${NC}"
        echo "• Linux: sudo systemctl start docker"
        echo "• macOS: Open Docker Desktop"
        echo "• Windows: Open Docker Desktop"
        exit 1
    fi
fi
echo ""

# Step 2: Check existing Kind clusters
echo -e "${BLUE}Step 2: Checking existing Kind clusters...${NC}"
if command -v kind >/dev/null 2>&1; then
    echo "Existing Kind clusters:"
    kind get clusters
    
    # Check if any clusters are actually running
    CLUSTERS=$(kind get clusters 2>/dev/null)
    if [ -n "$CLUSTERS" ]; then
        echo ""
        echo "Checking cluster health..."
        for cluster in $CLUSTERS; do
            echo "Testing cluster: $cluster"
            if kubectl cluster-info --context "kind-$cluster" >/dev/null 2>&1; then
                echo -e "${GREEN}✓ Cluster $cluster is healthy${NC}"
                kubectl config use-context "kind-$cluster"
                echo -e "${GREEN}✓ Switched to working cluster: $cluster${NC}"
                exit 0
            else
                echo -e "${RED}✗ Cluster $cluster is not responding${NC}"
                
                # Try to restart the cluster
                echo "Attempting to restart cluster: $cluster"
                kind delete cluster --name "$cluster"
                kind create cluster --name "$cluster"
                
                if kubectl cluster-info --context "kind-$cluster" >/dev/null 2>&1; then
                    echo -e "${GREEN}✓ Cluster $cluster restarted successfully${NC}"
                    kubectl config use-context "kind-$cluster"
                    exit 0
                fi
            fi
        done
    fi
else
    echo -e "${YELLOW}Kind is not installed${NC}"
fi
echo ""

# Step 3: Create new working cluster
echo -e "${BLUE}Step 3: Creating new local Kubernetes cluster...${NC}"
echo ""
echo -e "${CYAN}Choose cluster type:${NC}"
echo "1. Kind (Kubernetes in Docker) - Recommended"
echo "2. Minikube"
echo "3. Enable Docker Desktop Kubernetes"
echo "4. Skip cluster creation"
echo ""

read -p "Select option (1-4): " choice

case $choice in
    1)
        echo -e "${YELLOW}Setting up Kind cluster...${NC}"
        
        # Install Kind if not present
        if ! command -v kind >/dev/null 2>&1; then
            echo "Installing Kind..."
            if [[ "$OSTYPE" == "linux-gnu"* ]]; then
                curl -Lo ./kind https://kind.sigs.k8s.io/dl/latest/kind-linux-amd64
                chmod +x ./kind
                sudo mv ./kind /usr/local/bin/kind
            elif [[ "$OSTYPE" == "darwin"* ]]; then
                brew install kind
            elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
                curl -Lo ./kind.exe https://kind.sigs.k8s.io/dl/latest/kind-windows-amd64
                chmod +x ./kind.exe
                mv ./kind.exe /usr/local/bin/kind.exe
            fi
        fi
        
        # Create new Kind cluster
        CLUSTER_NAME="demo-local"
        echo "Creating Kind cluster: $CLUSTER_NAME"
        
        # Delete existing cluster if it exists
        kind delete cluster --name "$CLUSTER_NAME" 2>/dev/null || true
        
        # Create cluster with proper configuration
        cat > kind-config.yaml <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
  - containerPort: 30000
    hostPort: 30000
    protocol: TCP
EOF
        
        kind create cluster --name "$CLUSTER_NAME" --config kind-config.yaml
        
        # Verify cluster
        sleep 10
        if kubectl cluster-info --context "kind-$CLUSTER_NAME" >/dev/null 2>&1; then
            kubectl config use-context "kind-$CLUSTER_NAME"
            echo -e "${GREEN}✓ Kind cluster created and ready!${NC}"
            
            # Install a default StorageClass
            kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: standard
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: rancher.io/local-path
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
EOF
            
            echo -e "${GREEN}✓ Default StorageClass installed${NC}"
            rm -f kind-config.yaml
        else
            echo -e "${RED}✗ Failed to create Kind cluster${NC}"
            exit 1
        fi
        ;;
    2)
        echo -e "${YELLOW}Setting up Minikube cluster...${NC}"
        
        # Install Minikube if not present
        if ! command -v minikube >/dev/null 2>&1; then
            echo "Installing Minikube..."
            if [[ "$OSTYPE" == "linux-gnu"* ]]; then
                curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
                sudo install minikube-linux-amd64 /usr/local/bin/minikube
            elif [[ "$OSTYPE" == "darwin"* ]]; then
                brew install minikube
            elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
                echo "Please install Minikube manually from: https://minikube.sigs.k8s.io/docs/start/"
                exit 1
            fi
        fi
        
        # Start Minikube
        minikube start --driver=docker
        
        if kubectl cluster-info >/dev/null 2>&1; then
            echo -e "${GREEN}✓ Minikube cluster created and ready!${NC}"
        else
            echo -e "${RED}✗ Failed to create Minikube cluster${NC}"
            exit 1
        fi
        ;;
    3)
        echo -e "${YELLOW}Please enable Kubernetes in Docker Desktop:${NC}"
        echo "1. Open Docker Desktop"
        echo "2. Go to Settings → Kubernetes"
        echo "3. Check 'Enable Kubernetes'"
        echo "4. Click 'Apply & Restart'"
        echo ""
        echo "After enabling, run: kubectl config use-context docker-desktop"
        exit 0
        ;;
    4)
        echo "Skipping cluster creation"
        exit 0
        ;;
    *)
        echo -e "${RED}Invalid option${NC}"
        exit 1
        ;;
esac

# Step 4: Final verification
echo ""
echo -e "${BLUE}Step 4: Final verification...${NC}"

if kubectl cluster-info >/dev/null 2>&1; then
    echo -e "${GREEN}🎉 Kubernetes cluster is ready!${NC}"
    echo ""
    echo "Cluster information:"
    kubectl cluster-info
    echo ""
    echo "Available nodes:"
    kubectl get nodes
    echo ""
    echo "Current context:"
    kubectl config current-context
    echo ""
    echo -e "${CYAN}✅ You can now run: ./master-setup.sh${NC}"
else
    echo -e "${RED}❌ Cluster setup failed${NC}"
    echo "Please check the error messages above and try again"
    exit 1
fi
