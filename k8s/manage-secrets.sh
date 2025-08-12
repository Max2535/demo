#!/bin/bash
# Secret Rotation Script
# This script helps rotate and update production secrets

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

echo -e "${BLUE}🔐 Secret Rotation and Update Script${NC}"
echo "==================================="
echo ""

# Function to generate secure password
generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-25
}

# Function to generate JWT secret
generate_jwt_secret() {
    openssl rand -base64 64 | tr -d "=+/"
}

# Function to base64 encode
b64encode() {
    echo -n "$1" | base64 -w 0
}

# Function to check if secret exists
secret_exists() {
    kubectl get secret "$1" -n "$NAMESPACE" >/dev/null 2>&1
}

# Function to backup existing secret
backup_secret() {
    local secret_name=$1
    local backup_file="backup-${secret_name}-$(date +%Y%m%d-%H%M%S).yaml"
    
    if secret_exists "$secret_name"; then
        kubectl get secret "$secret_name" -n "$NAMESPACE" -o yaml > "$backup_file"
        echo -e "${GREEN}✓ Secret $secret_name backed up to $backup_file${NC}"
    fi
}

# Main menu
show_menu() {
    echo -e "${BLUE}🔧 Available Actions:${NC}"
    echo "1. Check current secrets status"
    echo "2. Rotate database passwords"
    echo "3. Rotate JWT secret"
    echo "4. Update GitHub Container Registry credentials"
    echo "5. Generate new secrets (all)"
    echo "6. Apply secrets to cluster"
    echo "7. Restart deployments (to pick up new secrets)"
    echo "8. Exit"
    echo ""
}

# Function to check secrets status
check_secrets_status() {
    echo -e "${BLUE}📊 Checking secrets status...${NC}"
    
    secrets=("mariadb-secrets" "demo-secrets" "ghcr-creds")
    
    for secret in "${secrets[@]}"; do
        if secret_exists "$secret"; then
            echo -e "${GREEN}✓ $secret exists${NC}"
            
            # Show last modified date
            local last_modified=$(kubectl get secret "$secret" -n "$NAMESPACE" -o jsonpath='{.metadata.creationTimestamp}')
            echo "  Last modified: $last_modified"
            
            # Show keys in secret
            local keys=$(kubectl get secret "$secret" -n "$NAMESPACE" -o jsonpath='{.data}' | jq -r 'keys[]' 2>/dev/null || echo "Could not read keys")
            echo "  Keys: $keys"
        else
            echo -e "${RED}✗ $secret missing${NC}"
        fi
        echo ""
    done
}

# Function to rotate database passwords
rotate_db_passwords() {
    echo -e "${BLUE}🗄️ Rotating database passwords...${NC}"
    
    # Backup existing secret
    backup_secret "mariadb-secrets"
    
    # Generate new passwords
    NEW_ROOT_PASSWORD=$(generate_password)
    NEW_USER_PASSWORD=$(generate_password)
    
    echo "Generated new database passwords"
    
    # Update mariadb-secrets.yml file
    cat > mariadb-secrets.yml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: mariadb-secrets
  labels:
    app: mariadb
  annotations:
    argocd.argoproj.io/sync-wave: "0"
    rotated-on: "$(date -Iseconds)"
type: Opaque
data:
  root-password: $(b64encode "$NEW_ROOT_PASSWORD")
  user-password: $(b64encode "$NEW_USER_PASSWORD")
EOF

    # Update demo-secrets.yml file with new user password
    if [ -f ".production-credentials" ]; then
        source .production-credentials
    fi
    
    cat > demo-secrets.yml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: demo-secrets
  labels:
    app: demo-app
  annotations:
    argocd.argoproj.io/sync-wave: "0"
    rotated-on: "$(date -Iseconds)"
type: Opaque
data:
  database-url: $(b64encode "jdbc:mariadb://mariadb-service:3306/cardb")
  database-username: $(b64encode "caruser")
  database-password: $(b64encode "$NEW_USER_PASSWORD")
  jwt-secret: $(b64encode "${JWT_SECRET:-$(generate_jwt_secret)}")
EOF

    # Update credentials file
    if [ -f ".production-credentials" ]; then
        # Update existing file
        sed -i "s/DATABASE_ROOT_PASSWORD=.*/DATABASE_ROOT_PASSWORD=\"$NEW_ROOT_PASSWORD\"/" .production-credentials
        sed -i "s/DATABASE_USER_PASSWORD=.*/DATABASE_USER_PASSWORD=\"$NEW_USER_PASSWORD\"/" .production-credentials
    else
        # Create new file
        cat > .production-credentials <<EOF
DATABASE_ROOT_PASSWORD="$NEW_ROOT_PASSWORD"
DATABASE_USER_PASSWORD="$NEW_USER_PASSWORD"
ROTATED_ON="$(date -Iseconds)"
EOF
    fi
    
    echo -e "${GREEN}✓ Database passwords rotated${NC}"
    echo -e "${YELLOW}⚠ Remember to apply secrets and restart deployments${NC}"
}

# Function to rotate JWT secret
rotate_jwt_secret() {
    echo -e "${BLUE}🔑 Rotating JWT secret...${NC}"
    
    # Backup existing secret
    backup_secret "demo-secrets"
    
    # Generate new JWT secret
    NEW_JWT_SECRET=$(generate_jwt_secret)
    
    # Load current credentials
    if [ -f ".production-credentials" ]; then
        source .production-credentials
    fi
    
    # Update demo-secrets.yml file
    cat > demo-secrets.yml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: demo-secrets
  labels:
    app: demo-app
  annotations:
    argocd.argoproj.io/sync-wave: "0"
    rotated-on: "$(date -Iseconds)"
type: Opaque
data:
  database-url: $(b64encode "jdbc:mariadb://mariadb-service:3306/cardb")
  database-username: $(b64encode "caruser")
  database-password: $(b64encode "${DATABASE_USER_PASSWORD:-defaultpass}")
  jwt-secret: $(b64encode "$NEW_JWT_SECRET")
EOF

    # Update credentials file
    if [ -f ".production-credentials" ]; then
        sed -i "s/JWT_SECRET=.*/JWT_SECRET=\"$NEW_JWT_SECRET\"/" .production-credentials
    else
        echo "JWT_SECRET=\"$NEW_JWT_SECRET\"" >> .production-credentials
    fi
    
    echo -e "${GREEN}✓ JWT secret rotated${NC}"
    echo -e "${YELLOW}⚠ Remember to apply secrets and restart deployments${NC}"
}

# Function to update GHCR credentials
update_ghcr_credentials() {
    echo -e "${BLUE}📦 Updating GitHub Container Registry credentials...${NC}"
    
    # Get current credentials or prompt for new ones
    if [ -z "$GITHUB_TOKEN" ]; then
        echo "Enter your GitHub personal access token:"
        read -s -p "GitHub Token: " GITHUB_TOKEN
        echo ""
    fi
    
    if [ -z "$GITHUB_USERNAME" ]; then
        echo "Enter your GitHub username:"
        read -p "GitHub Username: " GITHUB_USERNAME
    fi
    
    if [ -z "$GITHUB_EMAIL" ]; then
        echo "Enter your GitHub email:"
        read -p "GitHub Email: " GITHUB_EMAIL
    fi
    
    # Backup existing secret
    backup_secret "ghcr-creds"
    
    # Create Docker config JSON
    DOCKER_CONFIG="{\"auths\":{\"ghcr.io\":{\"username\":\"$GITHUB_USERNAME\",\"password\":\"$GITHUB_TOKEN\",\"auth\":\"$(echo -n "$GITHUB_USERNAME:$GITHUB_TOKEN" | base64 -w 0)\"}}}"
    
    # Update ghcr-secret.yml file
    cat > ghcr-secret.yml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: ghcr-creds
  labels:
    app: demo-app
  annotations:
    argocd.argoproj.io/sync-wave: "0"
    updated-on: "$(date -Iseconds)"
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: $(echo -n "$DOCKER_CONFIG" | base64 -w 0)
EOF

    # Update credentials file
    if [ -f ".production-credentials" ]; then
        sed -i "s/GITHUB_USERNAME=.*/GITHUB_USERNAME=\"$GITHUB_USERNAME\"/" .production-credentials
        sed -i "s/GITHUB_EMAIL=.*/GITHUB_EMAIL=\"$GITHUB_EMAIL\"/" .production-credentials
    fi
    
    echo -e "${GREEN}✓ GHCR credentials updated${NC}"
}

# Function to apply secrets to cluster
apply_secrets() {
    echo -e "${BLUE}🚀 Applying secrets to cluster...${NC}"
    
    if [ ! -f "mariadb-secrets.yml" ] || [ ! -f "demo-secrets.yml" ] || [ ! -f "ghcr-secret.yml" ]; then
        echo -e "${RED}✗ Secret files missing. Please generate secrets first.${NC}"
        return 1
    fi
    
    kubectl apply -f mariadb-secrets.yml -n "$NAMESPACE"
    kubectl apply -f demo-secrets.yml -n "$NAMESPACE"
    kubectl apply -f ghcr-secret.yml -n "$NAMESPACE"
    
    echo -e "${GREEN}✓ Secrets applied to cluster${NC}"
}

# Function to restart deployments
restart_deployments() {
    echo -e "${BLUE}🔄 Restarting deployments to pick up new secrets...${NC}"
    
    # Restart MariaDB deployment
    if kubectl get deployment mariadb -n "$NAMESPACE" >/dev/null 2>&1; then
        kubectl rollout restart deployment/mariadb -n "$NAMESPACE"
        echo "Waiting for MariaDB rollout..."
        kubectl rollout status deployment/mariadb -n "$NAMESPACE"
    fi
    
    # Restart Demo app deployment
    if kubectl get deployment demo-app -n "$NAMESPACE" >/dev/null 2>&1; then
        kubectl rollout restart deployment/demo-app -n "$NAMESPACE"
        echo "Waiting for demo-app rollout..."
        kubectl rollout status deployment/demo-app -n "$NAMESPACE"
    fi
    
    echo -e "${GREEN}✓ Deployments restarted${NC}"
}

# Main loop
while true; do
    show_menu
    read -p "Select an option (1-8): " choice
    echo ""
    
    case $choice in
        1)
            check_secrets_status
            ;;
        2)
            rotate_db_passwords
            ;;
        3)
            rotate_jwt_secret
            ;;
        4)
            update_ghcr_credentials
            ;;
        5)
            echo -e "${BLUE}🔄 Generating all new secrets...${NC}"
            rotate_db_passwords
            rotate_jwt_secret
            update_ghcr_credentials
            echo -e "${GREEN}✓ All secrets generated${NC}"
            ;;
        6)
            apply_secrets
            ;;
        7)
            restart_deployments
            ;;
        8)
            echo -e "${GREEN}👋 Goodbye!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option. Please try again.${NC}"
            ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
    echo ""
done
