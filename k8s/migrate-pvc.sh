#!/bin/bash
# This script helps you migrate data from an old PVC to a new one

# Exit immediately if a command exits with a non-zero status
set -e

# Set namespace
NAMESPACE=demo

# Create namespace if it doesn't exist
echo "Creating namespace '$NAMESPACE' if it doesn't exist..."
kubectl create namespace $NAMESPACE || echo "Namespace '$NAMESPACE' already exists"

# Ensure the ghcr-creds secret exists
if ! kubectl get secret ghcr-creds -n $NAMESPACE &> /dev/null; then
  echo "Creating ghcr-creds secret..."
  
  # Check if GITHUB_TOKEN environment variable is set
  if [ -z "$GITHUB_TOKEN" ]; then
    echo "GITHUB_TOKEN environment variable is not set. Please set it first:"
    echo "export GITHUB_TOKEN=your_github_token"
    exit 1
  fi
  
  # Create secret for GitHub Container Registry
  kubectl create secret docker-registry ghcr-creds \
    -n $NAMESPACE \
    --docker-server=ghcr.io \
    --docker-username=$GITHUB_USERNAME \
    --docker-password=$GITHUB_TOKEN \
    --docker-email=$GITHUB_EMAIL
    
  if [ $? -ne 0 ]; then
    echo "Failed to create ghcr-creds secret. Please check your credentials."
    echo "You can manually create it with:"
    echo "kubectl create secret docker-registry ghcr-creds -n $NAMESPACE --docker-server=ghcr.io --docker-username=<username> --docker-password=<token> --docker-email=<email>"
    exit 1
  fi
fi

# Create the new PVC
kubectl apply -f mariadb-pvc-standard.yml -n $NAMESPACE

# Scale down MariaDB deployment
kubectl scale deployment mariadb -n $NAMESPACE --replicas=0

# Create a data migration pod
cat <<EOF | kubectl apply -n $NAMESPACE -f -
apiVersion: v1
kind: Pod
metadata:
  name: mariadb-data-migration
spec:
  containers:
  - name: data-migration
    image: busybox
    command: ['sh', '-c', 'cp -rp /source/* /target/ && echo "Data migration completed"']
    volumeMounts:
    - name: source-data
      mountPath: /source
    - name: target-data
      mountPath: /target
  volumes:
  - name: source-data
    persistentVolumeClaim:
      claimName: mariadb-pvc
  - name: target-data
    persistentVolumeClaim:
      claimName: mariadb-pvc-standard
  restartPolicy: Never
EOF

# Wait for migration to complete
kubectl wait --for=condition=complete pod/mariadb-data-migration -n $NAMESPACE --timeout=300s

# Delete the migration pod
kubectl delete pod mariadb-data-migration -n $NAMESPACE

# Update the deployment to use the new PVC and scale back up
kubectl apply -f mariadb.yml -n $NAMESPACE

# Optionally delete the old PVC after verification
# kubectl delete pvc mariadb-pvc -n $NAMESPACE

echo "PVC migration completed. Please verify that MariaDB is working correctly before deleting the old PVC."
