#!/bin/bash

# Exit on any error
set -e

# Check for required arguments
if [ "$#" -lt 3 ]; then
    echo "Usage: $0 <secret-name> <namespace> <values-file> [environment]"
    echo "Example: $0 dive25-secrets dive25-dev secrets.env dev"
    exit 1
fi

SECRET_NAME="$1"
NAMESPACE="$2"
VALUES_FILE="$3"
ENVIRONMENT="${4:-dev}"

# Check if values file exists
if [ ! -f "$VALUES_FILE" ]; then
    echo "Error: Values file $VALUES_FILE not found!"
    exit 1
fi

# Create temporary plain secret YAML
echo "Creating temporary secret YAML..."
kubectl create secret generic "$SECRET_NAME" \
  --namespace="$NAMESPACE" \
  --from-env-file="$VALUES_FILE" \
  --dry-run=client -o yaml > temp-secret.yaml

# Seal the secret
echo "Sealing secret $SECRET_NAME for namespace $NAMESPACE..."
kubeseal --format yaml --controller-namespace=kube-system < temp-secret.yaml > "k8s/environments/$ENVIRONMENT/secrets/$SECRET_NAME.yaml"

# Clean up temporary file
rm temp-secret.yaml

echo "Secret sealed and stored in k8s/environments/$ENVIRONMENT/secrets/$SECRET_NAME.yaml"