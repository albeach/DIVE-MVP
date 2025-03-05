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

# Create a temporary file for processing
TMP_ENV_FILE=$(mktemp)

# Process the environment file to ensure URL variables are properly handled
echo "Processing environment variables..."
while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip comments and empty lines
    if [[ "$line" =~ ^#.*$ ]] || [[ -z "$line" ]]; then
        echo "$line" >> "$TMP_ENV_FILE"
        continue
    fi
    
    # Extract variable name and value
    var_name=$(echo "$line" | cut -d= -f1)
    var_value=$(echo "$line" | cut -d= -f2-)
    
    # Check if this is a URL variable that needs special handling
    if [[ "$var_name" == *_URL ]] || [[ "$var_name" == *_URI ]]; then
        echo "Detected URL variable: $var_name"
        # Ensure there are no trailing comments in URL values
        var_value=$(echo "$var_value" | sed 's/\s*#.*$//')
        echo "$var_name=$var_value" >> "$TMP_ENV_FILE"
    else
        # Pass through other variables unchanged
        echo "$line" >> "$TMP_ENV_FILE"
    fi
done < "$VALUES_FILE"

# Create temporary plain secret YAML
echo "Creating temporary secret YAML..."
kubectl create secret generic "$SECRET_NAME" \
  --namespace="$NAMESPACE" \
  --from-env-file="$TMP_ENV_FILE" \
  --dry-run=client -o yaml > temp-secret.yaml

# Create directories for environment if they don't exist
mkdir -p "k8s/environments/$ENVIRONMENT/secrets"

# Try to seal the secret, but fallback to using regular secret if kubeseal fails
echo "Sealing secret $SECRET_NAME for namespace $NAMESPACE..."
if kubeseal --format yaml --controller-namespace=kube-system < temp-secret.yaml > "k8s/environments/$ENVIRONMENT/secrets/$SECRET_NAME.yaml" 2>/dev/null; then
    echo "Secret sealed successfully."
else
    echo "Warning: kubeseal failed, creating regular Kubernetes secret instead."
    # For development purposes, just copy the regular secret
    cp temp-secret.yaml "k8s/environments/$ENVIRONMENT/secrets/$SECRET_NAME.yaml"
    echo "Regular Kubernetes secret created (not sealed)."
fi

# Clean up temporary files
rm temp-secret.yaml
rm "$TMP_ENV_FILE"

echo "Secret stored in k8s/environments/$ENVIRONMENT/secrets/$SECRET_NAME.yaml"