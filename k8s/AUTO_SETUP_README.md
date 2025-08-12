# 🚀 Auto Setup Scripts for ArgoCD Production Deployment

## 📋 Overview

ชุด scripts อัตโนมัติสำหรับการ deploy Spring Boot application ด้วย ArgoCD ในสภาพแวดล้อม production

## 📁 Script Files

### 🎯 Master Script
- **`master-setup.sh`** - Main menu script ที่รวมทุกอย่างเข้าด้วยกัน (แนะนำให้เริ่มต้นที่นี่)

### 🏗️ Setup Scripts
- **`setup-production.sh`** - ตั้งค่า production environment (secrets, StorageClass, credentials)
- **`auto-deploy.sh`** - Deploy application ด้วย ArgoCD อัตโนมัติ

### 🔐 Management Scripts  
- **`manage-secrets.sh`** - จัดการและ rotate secrets
- **`validate-argocd-config.sh`** - ตรวจสอบการกำหนดค่า
- **`fix-mariadb-aria.sh`** - แก้ไขปัญหา MariaDB Aria lock

### 🛠️ Utility Scripts
- **`create-namespace.sh`** - สร้าง namespace
- **`migrate-pvc.sh`** - Migration PVC 
- **`quick-fix-commands.sh`** - คำสั่งแก้ไขด่วน
- **`setup.sh`** - Setup script เดิม (legacy)

## 🚀 Quick Start

### Option 1: ใช้ Master Script (แนะนำ)
```bash
./master-setup.sh
```

### Option 2: Run Manual Steps
```bash
# 1. Setup production
./setup-production.sh

# 2. Deploy with ArgoCD  
./auto-deploy.sh
```

## 📝 Prerequisites

### ✅ Required Tools
- `kubectl` - Kubernetes CLI
- `openssl` - For generating secrets
- `argocd` - ArgoCD CLI (จะติดตั้งอัตโนมัติถ้าไม่มี)

### 🔑 Required Information
- **GitHub Personal Access Token** (สำหรับ GHCR access)
- **GitHub Username และ Email**
- **Kubernetes cluster access** (kubeconfig configured)

### 🌐 Kubernetes Cluster Requirements
- **ArgoCD installed** (หรือ script จะติดตั้งให้อัตโนมัติ)
- **StorageClass "standard"** (หรือ script จะสร้างให้)
- **Sufficient permissions** for creating namespaces, secrets, deployments

## 🔧 What Each Script Does

### 🎯 master-setup.sh
- Main menu interface
- Orchestrates all other scripts
- Shows current status
- Provides help and documentation

### 🏗️ setup-production.sh
1. ✅ ตรวจสอบ prerequisites
2. 🔑 รับ GitHub credentials
3. 💾 สร้าง StorageClass (auto-detect cloud provider)
4. 🏗️ สร้าง namespace
5. 🔐 สร้าง production secrets
6. 📝 บันทึก credentials

### 🚀 auto-deploy.sh
1. ✅ ตรวจสอบ ArgoCD installation
2. 🔑 Login to ArgoCD
3. 🚀 Deploy application via GitOps
4. ⏳ รอให้ deployment เสร็จ
5. 🏥 ตรวจสอบ health status

### 🔐 manage-secrets.sh
- Interactive menu สำหรับจัดการ secrets
- Rotate database passwords
- Rotate JWT secrets
- Update GHCR credentials
- Backup เก่า secrets
- Apply ใหม่ secrets

## 📊 Generated Files

### 🔐 Secret Files
- `mariadb-secrets.yml` - Database credentials
- `demo-secrets.yml` - Application secrets  
- `ghcr-secret.yml` - Container registry credentials

### 📝 Credentials File
- `.production-credentials` - ไฟล์เก็บ credentials (chmod 600)

### 🗄️ Backup Files
- `backup-*-YYYYMMDD-HHMMSS.yaml` - Secret backups

## 🔒 Security Notes

### ⚠️ Important
- **ไฟล์ `.production-credentials` มี sensitive data**
- **Add `.production-credentials` to `.gitignore`**
- **Rotate secrets เป็นประจำ**
- **ใช้ proper RBAC ใน production**

### 🔐 Best Practices
- ใช้ external secret management (Vault, External Secrets Operator)
- Monitor secret access และ rotation
- Use least privilege principles
- Audit secret usage regularly

## 🆘 Troubleshooting

### ❌ Common Issues

#### 1. Kubernetes Access
```bash
# Check current context
kubectl config get-contexts

# Switch context
kubectl config use-context <context-name>
```

#### 2. ArgoCD Access
```bash
# Port forward ArgoCD
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

#### 3. Secret Issues
```bash
# Use secret management script
./manage-secrets.sh

# Check secrets
kubectl get secrets -n demo
```

#### 4. Database Issues
```bash
# Fix MariaDB problems
./fix-mariadb-aria.sh

# Check database logs
kubectl logs -l app=mariadb -n demo
```

### 🔍 Debug Commands
```bash
# Check application status
kubectl get all -n demo

# Check ArgoCD application
argocd app get demo-app

# View events
kubectl get events -n demo --sort-by='.lastTimestamp'

# Check logs
kubectl logs -f -l app=demo-app -n demo
```

## 🎉 Success Indicators

### ✅ Setup Complete When
- ✅ All scripts run without errors
- ✅ ArgoCD shows application as "Healthy" and "Synced"
- ✅ All pods are "Running"
- ✅ Database connectivity works
- ✅ Application responds to health checks

### 🌐 Access Points
- **ArgoCD UI**: https://localhost:8080 (admin/<password>)
- **Application**: Port forward or through ingress
- **Database**: kubectl exec into MariaDB pod

## 📞 Support

### 📚 Documentation
- `ARGOCD_DEPLOYMENT.md` - Complete deployment guide
- `ARGOCD_READY.md` - Readiness checklist
- `MARIADB_TROUBLESHOOTING.md` - Database troubleshooting

### 🔧 Tools
- `validate-argocd-config.sh` - Configuration validation
- `master-setup.sh` menu option 7 - Current status
- `master-setup.sh` menu option 9 - Help & troubleshooting

---

**🌟 Ready for Production GitOps Deployment! 🌟**

*Generated: 2025-08-12*  
*Version: 1.0.0*
