# MariaDB Aria Control File Lock Issue - Troubleshooting Guide

## Problem
MariaDB is showing errors related to the Aria storage engine control file being locked:
```
[ERROR] mariadbd: Can't lock aria control file '/var/lib/mysql/aria_log_control' for exclusive use
[ERROR] mariadbd: Got error 'Could not get an exclusive lock; file is probably in use by another process'
[ERROR] Plugin 'Aria' registration as a STORAGE ENGINE failed.
```

## Root Cause
This typically happens when:
1. MariaDB was not properly shut down
2. Lock files remain from a previous instance
3. Multiple processes are trying to access the same data directory
4. File system corruption or permission issues

## Solution Steps

### Step 1: Stop MariaDB cleanly
```bash
# Scale down MariaDB deployment
kubectl scale deployment mariadb -n demo --replicas=0

# Wait for pods to terminate
kubectl wait --for=delete pod -l app=mariadb -n demo --timeout=60s
```

### Step 2: Clean up lock files
```bash
# Create a cleanup job
kubectl apply -n demo -f - <<EOF
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
            echo "Cleaning up MariaDB lock files..."
            cd /var/lib/mysql
            
            # Remove Aria control files
            rm -f aria_log_control
            rm -f aria_log.*
            
            # Remove other lock files
            rm -f *.pid
            rm -f mysql.sock*
            rm -f *.lock
            
            echo "Cleanup completed"
        volumeMounts:
        - name: mariadb-data
          mountPath: /var/lib/mysql
      volumes:
      - name: mariadb-data
        persistentVolumeClaim:
          claimName: mariadb-pvc-standard
      restartPolicy: Never
EOF

# Wait for cleanup to complete
kubectl wait --for=condition=complete job/mariadb-cleanup-aria-locks -n demo --timeout=120s

# Check logs
kubectl logs job/mariadb-cleanup-aria-locks -n demo

# Clean up the job
kubectl delete job mariadb-cleanup-aria-locks -n demo
```

### Step 3: Restart MariaDB
```bash
# Apply the updated MariaDB configuration
kubectl apply -f mariadb.yml -n demo

# Scale back up
kubectl scale deployment mariadb -n demo --replicas=1

# Wait for readiness
kubectl wait --for=condition=ready pod -l app=mariadb -n demo --timeout=180s
```

### Step 4: Verify the fix
```bash
# Check logs for any remaining errors
kubectl logs -l app=mariadb -n demo --tail=20

# Test database connectivity
kubectl exec -n demo deployment/mariadb -- mysqladmin ping
```

## Prevention

The updated `mariadb.yml` includes:

1. **Graceful shutdown hook**: Ensures proper shutdown when pods are terminated
2. **Optimized Aria settings**: Better configuration for Aria storage engine
3. **Improved startup parameters**: Reduces lock contention issues

## Alternative Quick Fix

If the above doesn't work, you can recreate the MariaDB data:

```bash
# WARNING: This will delete all database data!
kubectl delete pvc mariadb-pvc-standard -n demo
kubectl apply -f mariadb-pvc-standard.yml -n demo
kubectl apply -f mariadb.yml -n demo
```

## Monitoring

After fixing, monitor MariaDB logs:
```bash
kubectl logs -f -l app=mariadb -n demo
```

Look for successful startup messages and absence of Aria-related errors.
