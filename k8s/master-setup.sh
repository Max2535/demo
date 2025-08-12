#!/bin/bash
# Master Auto Setup Script for ArgoCD Production Deployment
# This script orchestrates the complete setup process

# Exit immediately if a command exits with a non-zero status
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script information
SCRIPT_VERSION="1.0.0"
SCRIPT_DATE="2025-08-12"

# Banner
print_banner() {
    echo -e "${PURPLE}"
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║                                                          ║"
    echo "║    🚀 ArgoCD Production Auto Setup Master Script        ║"
    echo "║                                                          ║"
    echo "║    Version: $SCRIPT_VERSION                                         ║"
    echo "║    Date: $SCRIPT_DATE                                     ║"
    echo "║    Author: GitHub Copilot                                ║"
    echo "║                                                          ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
}

# Function to check if script exists and is executable
check_script() {
    local script_name=$1
    if [ -f "$script_name" ]; then
        chmod +x "$script_name"
        echo -e "${GREEN}✓ $script_name ready${NC}"
        return 0
    else
        echo -e "${RED}✗ $script_name missing${NC}"
        return 1
    fi
}

# Function to show main menu
show_main_menu() {
    echo -e "${CYAN}🎯 Main Menu${NC}"
    echo "============"
    echo ""
    echo -e "${BLUE}Setup & Deployment:${NC}"
    echo "1. 🏗️  Complete Production Setup (Run setup-production.sh)"
    echo "2. 🚀 Deploy with ArgoCD (Run auto-deploy.sh)"
    echo "3. ⚡ Quick Setup + Deploy (Run both scripts)"
    echo ""
    echo -e "${BLUE}Management:${NC}"
    echo "4. 🔐 Manage Secrets (Run manage-secrets.sh)"
    echo "5. ✅ Validate Configuration (Run validate-argocd-config.sh)"
    echo "6. 🔧 Fix MariaDB Issues (Run fix-mariadb-aria.sh)"
    echo ""
    echo -e "${BLUE}Information:${NC}"
    echo "7. 📊 Show Current Status"
    echo "8. 📚 Show Documentation"
    echo "9. 🆘 Help & Troubleshooting"
    echo ""
    echo -e "${BLUE}Exit:${NC}"
    echo "0. 👋 Exit"
    echo ""
}

# Function to show current status
show_current_status() {
    echo -e "${BLUE}📊 Current Environment Status${NC}"
    echo "==============================="
    echo ""
    
    # Check Kubernetes connectivity
    echo -e "${CYAN}🔗 Kubernetes Cluster:${NC}"
    if kubectl cluster-info >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Connected to cluster${NC}"
        echo "  Context: $(kubectl config current-context)"
    else
        echo -e "${RED}✗ Not connected to cluster${NC}"
    fi
    echo ""
    
    # Check ArgoCD
    echo -e "${CYAN}🔄 ArgoCD Status:${NC}"
    if kubectl get namespace argocd >/dev/null 2>&1; then
        echo -e "${GREEN}✓ ArgoCD namespace exists${NC}"
        if kubectl get deployment argocd-server -n argocd >/dev/null 2>&1; then
            echo -e "${GREEN}✓ ArgoCD server deployed${NC}"
        else
            echo -e "${YELLOW}⚠ ArgoCD server not found${NC}"
        fi
    else
        echo -e "${RED}✗ ArgoCD not installed${NC}"
    fi
    echo ""
    
    # Check namespace
    echo -e "${CYAN}🏗️ Application Namespace:${NC}"
    if kubectl get namespace demo >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Demo namespace exists${NC}"
        
        # Check secrets
        echo "  Secrets:"
        for secret in mariadb-secrets demo-secrets ghcr-creds; do
            if kubectl get secret "$secret" -n demo >/dev/null 2>&1; then
                echo -e "    ${GREEN}✓ $secret${NC}"
            else
                echo -e "    ${RED}✗ $secret${NC}"
            fi
        done
        
        # Check deployments
        echo "  Deployments:"
        for deployment in mariadb demo-app; do
            if kubectl get deployment "$deployment" -n demo >/dev/null 2>&1; then
                local replicas=$(kubectl get deployment "$deployment" -n demo -o jsonpath='{.status.readyReplicas}')
                local desired=$(kubectl get deployment "$deployment" -n demo -o jsonpath='{.spec.replicas}')
                echo -e "    ${GREEN}✓ $deployment ($replicas/$desired ready)${NC}"
            else
                echo -e "    ${RED}✗ $deployment${NC}"
            fi
        done
    else
        echo -e "${RED}✗ Demo namespace not found${NC}"
    fi
    echo ""
    
    # Check production credentials
    echo -e "${CYAN}🔐 Production Setup:${NC}"
    if [ -f ".production-credentials" ]; then
        echo -e "${GREEN}✓ Production credentials file exists${NC}"
        echo "  Created: $(stat -c %y .production-credentials 2>/dev/null || stat -f %Sm .production-credentials 2>/dev/null || echo 'Unknown')"
    else
        echo -e "${RED}✗ Production credentials not found${NC}"
    fi
    echo ""
    
    # Check StorageClass
    echo -e "${CYAN}💾 Storage:${NC}"
    if kubectl get storageclass standard >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Standard StorageClass exists${NC}"
    else
        echo -e "${RED}✗ Standard StorageClass not found${NC}"
    fi
    echo ""
}

# Function to show documentation
show_documentation() {
    echo -e "${BLUE}📚 Available Documentation${NC}"
    echo "==========================="
    echo ""
    
    docs=(
        "ARGOCD_DEPLOYMENT.md:Complete ArgoCD deployment guide"
        "ARGOCD_READY.md:Readiness checklist and validation"
        "MARIADB_TROUBLESHOOTING.md:Database troubleshooting guide"
        "README.md:Project overview and instructions"
    )
    
    for doc in "${docs[@]}"; do
        IFS=':' read -r filename description <<< "$doc"
        if [ -f "$filename" ]; then
            echo -e "${GREEN}✓ $filename${NC} - $description"
        else
            echo -e "${YELLOW}⚠ $filename${NC} - $description (not found)"
        fi
    done
    echo ""
    
    echo -e "${CYAN}💡 Quick Commands:${NC}"
    echo "• View documentation: cat ARGOCD_DEPLOYMENT.md"
    echo "• Check readiness: cat ARGOCD_READY.md"
    echo "• Troubleshoot DB: cat MARIADB_TROUBLESHOOTING.md"
    echo ""
}

# Function to show help
show_help() {
    echo -e "${BLUE}🆘 Help & Troubleshooting${NC}"
    echo "=========================="
    echo ""
    
    echo -e "${CYAN}🔧 Common Issues:${NC}"
    echo ""
    echo -e "${YELLOW}1. Kubernetes cluster not accessible:${NC}"
    echo "   • Check: kubectl config get-contexts"
    echo "   • Switch: kubectl config use-context <context-name>"
    echo ""
    echo -e "${YELLOW}2. ArgoCD not accessible:${NC}"
    echo "   • Port forward: kubectl port-forward svc/argocd-server -n argocd 8080:443"
    echo "   • Get password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
    echo ""
    echo -e "${YELLOW}3. Secrets issues:${NC}"
    echo "   • Run: ./manage-secrets.sh"
    echo "   • Check: kubectl get secrets -n demo"
    echo ""
    echo -e "${YELLOW}4. Database connection issues:${NC}"
    echo "   • Run: ./fix-mariadb-aria.sh"
    echo "   • Check logs: kubectl logs -l app=mariadb -n demo"
    echo ""
    echo -e "${YELLOW}5. Image pull errors:${NC}"
    echo "   • Check: kubectl describe pod <pod-name> -n demo"
    echo "   • Update GHCR credentials in manage-secrets.sh"
    echo ""
    
    echo -e "${CYAN}📞 Getting More Help:${NC}"
    echo "• Check application logs: kubectl logs -f -l app=demo-app -n demo"
    echo "• Check ArgoCD application: argocd app get demo-app"
    echo "• Validate configuration: ./validate-argocd-config.sh"
    echo "• View events: kubectl get events -n demo --sort-by='.lastTimestamp'"
    echo ""
}

# Function to run complete setup
run_complete_setup() {
    echo -e "${PURPLE}🚀 Running Complete Production Setup...${NC}"
    echo ""
    
    echo -e "${BLUE}Step 1: Production Setup${NC}"
    ./setup-production.sh
    
    echo ""
    echo -e "${BLUE}Step 2: ArgoCD Deployment${NC}"
    ./auto-deploy.sh
    
    echo ""
    echo -e "${GREEN}🎉 Complete setup finished!${NC}"
}

# Main function
main() {
    print_banner
    
    # Check if all required scripts exist
    echo -e "${BLUE}🔍 Checking required scripts...${NC}"
    
    scripts=(
        "setup-production.sh"
        "auto-deploy.sh"
        "manage-secrets.sh"
        "validate-argocd-config.sh"
        "fix-mariadb-aria.sh"
    )
    
    missing_scripts=0
    for script in "${scripts[@]}"; do
        if ! check_script "$script"; then
            missing_scripts=$((missing_scripts + 1))
        fi
    done
    
    if [ $missing_scripts -gt 0 ]; then
        echo -e "${RED}✗ $missing_scripts script(s) missing. Please ensure all scripts are present.${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ All required scripts found${NC}"
    echo ""
    
    # Main menu loop
    while true; do
        show_main_menu
        read -p "Select an option (0-9): " choice
        echo ""
        
        case $choice in
            1)
                echo -e "${BLUE}🏗️ Running Production Setup...${NC}"
                ./setup-production.sh
                ;;
            2)
                echo -e "${BLUE}🚀 Running ArgoCD Deployment...${NC}"
                ./auto-deploy.sh
                ;;
            3)
                run_complete_setup
                ;;
            4)
                echo -e "${BLUE}🔐 Managing Secrets...${NC}"
                ./manage-secrets.sh
                ;;
            5)
                echo -e "${BLUE}✅ Validating Configuration...${NC}"
                ./validate-argocd-config.sh
                ;;
            6)
                echo -e "${BLUE}🔧 Fixing MariaDB Issues...${NC}"
                ./fix-mariadb-aria.sh
                ;;
            7)
                show_current_status
                ;;
            8)
                show_documentation
                ;;
            9)
                show_help
                ;;
            0)
                echo -e "${GREEN}👋 Thank you for using the ArgoCD Auto Setup Script!${NC}"
                echo -e "${CYAN}🌟 Your application is ready for production!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}❌ Invalid option. Please try again.${NC}"
                ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
        echo ""
    done
}

# Run main function
main "$@"
