#!/bin/bash
# Script to fix MariaDB Aria control file lock issues

# Exit immediately if a command exits with a non-zero status
set -e

# Set namespace
NAMESPACE=${NAMESPACE:-demo}

echo "Fixing MariaDB Aria control file lock issue..."

# Scale down MariaDB deployment to stop all processes
echo "Scaling down MariaDB deployment..."
kubectl scale deployment mariadb -n $NAMESPACE --replicas=0

# Wait for pods to terminate
echo "Waiting for MariaDB pods to terminate..."
kubectl wait --for=delete pod -l app=mariadb -n $NAMESPACE --timeout=60s || echo "Timeout waiting for pods to terminate, continuing..."

# Create a cleanup job to remove lock files
echo "Creating cleanup job to remove Aria lock files..."
cat <<EOF | kubectl apply -n $NAMESPACE -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: mariadb-cleanup-aria-locks
spec:
  template:
    spec:
      containers:
      - name: cleanup
        image: busybox
        command: ['sh', '-c']
        args:
          - |
            echo "Cleaning up MariaDB Aria lock files..."
            cd /var/lib/mysql
            
            # Remove Aria control files if they exist
            if [ -f "aria_log_control" ]; then
              echo "Removing aria_log_control file..."
              rm -f aria_log_control
            fi
            
            # Remove any other potential lock files
            rm -f *.pid
            rm -f mysql.sock*
            rm -f *.lock
            
            # List remaining files for verification
            echo "Remaining files in /var/lib/mysql:"
            ls -la /var/lib/mysql/ || echo "Directory is empty or cannot be read"
            
            echo "Cleanup completed successfully"
        volumeMounts:
        - name: mariadb-data
          mountPath: /var/lib/mysql
      volumes:
      - name: mariadb-data
        persistentVolumeClaim:
          claimName: mariadb-pvc-standard
      restartPolicy: Never
  backoffLimit: 3
EOF

# Wait for cleanup job to complete
echo "Waiting for cleanup job to complete..."
kubectl wait --for=condition=complete job/mariadb-cleanup-aria-locks -n $NAMESPACE --timeout=120s

# Check job logs
echo "Cleanup job logs:"
kubectl logs job/mariadb-cleanup-aria-locks -n $NAMESPACE

# Clean up the job
kubectl delete job mariadb-cleanup-aria-locks -n $NAMESPACE

# Scale MariaDB back up
echo "Scaling MariaDB back up..."
kubectl scale deployment mariadb -n $NAMESPACE --replicas=1

# Wait for MariaDB to be ready
echo "Waiting for MariaDB to be ready..."
kubectl wait --for=condition=ready pod -l app=mariadb -n $NAMESPACE --timeout=180s

echo "MariaDB Aria lock issue has been fixed!"
echo "Checking MariaDB logs for any remaining issues..."
kubectl logs -l app=mariadb -n $NAMESPACE --tail=20

echo "Fix completed. MariaDB should now be running without Aria lock errors."
