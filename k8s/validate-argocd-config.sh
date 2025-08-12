#!/bin/bash
# ArgoCD Deployment Validation Script

echo "🔍 Validating ArgoCD deployment configuration..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if file exists
check_file() {
    if [ -f "$1" ]; then
        echo -e "${GREEN}✓${NC} $1 exists"
        return 0
    else
        echo -e "${RED}✗${NC} $1 missing"
        return 1
    fi
}

# Function to validate YAML syntax
validate_yaml() {
    if kubectl apply --dry-run=client -f "$1" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} $1 YAML syntax valid"
        return 0
    else
        echo -e "${RED}✗${NC} $1 YAML syntax invalid"
        kubectl apply --dry-run=client -f "$1"
        return 1
    fi
}

echo ""
echo "📁 Checking required files..."

# Required files for ArgoCD deployment
required_files=(
    "namespaces.yaml"
    "mariadb-pvc-standard.yml"
    "mariadb-configmap.yml"
    "mariadb-secrets.yml"
    "mariadb.yml"
    "mariadb-init-check.yml"
    "demo-secrets.yml"
    "ghcr-secret.yml"
    "deployment.yml"
    "kustomization.yaml"
    "argocd-application.yml"
    "argocd-applicationset.yml"
)

missing_files=0
for file in "${required_files[@]}"; do
    if ! check_file "$file"; then
        missing_files=$((missing_files + 1))
    fi
done

echo ""
echo "🔧 Validating YAML syntax..."

invalid_files=0
for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        if ! validate_yaml "$file"; then
            invalid_files=$((invalid_files + 1))
        fi
    fi
done

echo ""
echo "🔍 Checking ArgoCD specific configurations..."

# Check sync waves
echo "Checking sync waves..."
if grep -q "argocd.argoproj.io/sync-wave" *.yml; then
    echo -e "${GREEN}✓${NC} Sync waves configured"
else
    echo -e "${YELLOW}⚠${NC} No sync waves found (optional but recommended)"
fi

# Check health checks
echo "Checking health checks..."
if grep -q "livenessProbe\|readinessProbe" deployment.yml mariadb.yml; then
    echo -e "${GREEN}✓${NC} Health checks configured"
else
    echo -e "${RED}✗${NC} Health checks missing"
    invalid_files=$((invalid_files + 1))
fi

# Check init containers
echo "Checking init containers..."
if grep -q "initContainers" deployment.yml; then
    echo -e "${GREEN}✓${NC} Init containers configured"
else
    echo -e "${YELLOW}⚠${NC} No init containers found"
fi

# Check resource limits
echo "Checking resource limits..."
if grep -q "resources:" deployment.yml mariadb.yml; then
    echo -e "${GREEN}✓${NC} Resource limits configured"
else
    echo -e "${YELLOW}⚠${NC} Resource limits not set (recommended for production)"
fi

# Check secrets
echo "Checking secrets configuration..."
secret_issues=0

if grep -q "PLACEHOLDER\|placeholder\|changeme" *secrets*.yml; then
    echo -e "${YELLOW}⚠${NC} Placeholder values found in secrets (update for production)"
    secret_issues=$((secret_issues + 1))
fi

if grep -q "type: kubernetes.io/dockerconfigjson" ghcr-secret.yml; then
    echo -e "${GREEN}✓${NC} Docker registry secret type correct"
else
    echo -e "${RED}✗${NC} Docker registry secret type incorrect"
    invalid_files=$((invalid_files + 1))
fi

echo ""
echo "🔧 Validating Kustomization..."

if [ -f "kustomization.yaml" ]; then
    # Check if all resources are listed in kustomization
    echo "Checking kustomization resources..."
    missing_in_kustomization=0
    
    for file in namespaces.yaml mariadb-pvc-standard.yml mariadb-configmap.yml mariadb-secrets.yml mariadb.yml demo-secrets.yml ghcr-secret.yml deployment.yml; do
        if [ -f "$file" ] && ! grep -q "$file" kustomization.yaml; then
            echo -e "${RED}✗${NC} $file not listed in kustomization.yaml"
            missing_in_kustomization=$((missing_in_kustomization + 1))
        fi
    done
    
    if [ $missing_in_kustomization -eq 0 ]; then
        echo -e "${GREEN}✓${NC} All resources listed in kustomization.yaml"
    fi
    
    # Test kustomization build
    if kustomize build . > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} Kustomization builds successfully"
    else
        echo -e "${RED}✗${NC} Kustomization build failed"
        echo "Error details:"
        kustomize build .
        invalid_files=$((invalid_files + 1))
    fi
fi

echo ""
echo "📊 Validation Summary"
echo "===================="

if [ $missing_files -eq 0 ] && [ $invalid_files -eq 0 ]; then
    echo -e "${GREEN}🎉 All validations passed!${NC}"
    echo "✅ Ready for ArgoCD deployment"
    exit 0
else
    echo -e "${RED}❌ Validation failed${NC}"
    echo "Missing files: $missing_files"
    echo "Invalid configurations: $invalid_files"
    
    if [ $secret_issues -gt 0 ]; then
        echo -e "${YELLOW}⚠${NC} Remember to update secret values for production"
    fi
    
    echo ""
    echo "🔧 Next steps:"
    echo "1. Fix the issues listed above"
    echo "2. Run this script again to validate"
    echo "3. Update secrets with production values"
    echo "4. Deploy with ArgoCD"
    
    exit 1
fi
