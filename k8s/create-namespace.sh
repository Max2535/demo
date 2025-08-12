#!/bin/bash
# Script to apply Kubernetes namespace separately

# Exit immediately if a command exits with a non-zero status
set -e

echo "Creating 'demo' namespace..."
# Using kubectl create instead of apply to ensure it exists
kubectl create namespace demo || echo "Namespace 'demo' already exists"
