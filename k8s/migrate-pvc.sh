#!/bin/bash
# This script helps you migrate data from an old PVC to a new one

# Set namespace
NAMESPACE=demo

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
