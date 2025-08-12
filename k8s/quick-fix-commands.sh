#!/bin/bash
# Quick commands to fix MariaDB Aria lock issue

echo "=== MariaDB Aria Lock Fix - Quick Commands ==="
echo ""
echo "1. Stop MariaDB:"
echo "   kubectl scale deployment mariadb -n demo --replicas=0"
echo ""
echo "2. Wait for shutdown:"
echo "   kubectl wait --for=delete pod -l app=mariadb -n demo --timeout=60s"
echo ""
echo "3. Clean lock files (copy and paste the entire block):"
cat << 'EOF'
kubectl apply -n demo -f - <<EOJ
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
            rm -f aria_log_control aria_log.* *.pid mysql.sock* *.lock
            echo "Cleanup completed"
        volumeMounts:
        - name: mariadb-data
          mountPath: /var/lib/mysql
      volumes:
      - name: mariadb-data
        persistentVolumeClaim:
          claimName: mariadb-pvc-standard
      restartPolicy: Never
EOJ
EOF
echo ""
echo "4. Wait for cleanup:"
echo "   kubectl wait --for=condition=complete job/mariadb-cleanup-aria-locks -n demo --timeout=120s"
echo ""
echo "5. Check cleanup logs:"
echo "   kubectl logs job/mariadb-cleanup-aria-locks -n demo"
echo ""
echo "6. Delete cleanup job:"
echo "   kubectl delete job mariadb-cleanup-aria-locks -n demo"
echo ""
echo "7. Restart MariaDB:"
echo "   kubectl apply -f mariadb.yml -n demo"
echo "   kubectl scale deployment mariadb -n demo --replicas=1"
echo ""
echo "8. Verify fix:"
echo "   kubectl wait --for=condition=ready pod -l app=mariadb -n demo --timeout=180s"
echo "   kubectl logs -l app=mariadb -n demo --tail=20"
echo ""
echo "=== End of commands ==="
