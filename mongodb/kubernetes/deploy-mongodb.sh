#!/bin/bash
# mongodb/kubernetes/deploy-mongodb.sh

set -e

echo "Deploying MongoDB to Kubernetes..."

# Create namespace
kubectl apply -f namespace.yaml

# Create secrets
if [ ! -f mongodb-secret.yaml ]; then
  echo "Generating MongoDB secret values..."
  
  # Generate random passwords
  ROOT_PASSWORD=$(openssl rand -base64 16)
  REPLICA_SET_KEY=$(openssl rand -base64 756)
  APP_PASSWORD=$(openssl rand -base64 16)
  ADMIN_PASSWORD=$(openssl rand -base64 16)
  READONLY_PASSWORD=$(openssl rand -base64 16)
  EXPORTER_PASSWORD=$(openssl rand -base64 16)
  
  # Create secret YAML
  cat > mongodb-secret.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: mongodb-secret
  namespace: dive25-mongodb
type: Opaque
data:
  mongodb-root-username: $(echo -n "admin" | base64)
  mongodb-root-password: $(echo -n "$ROOT_PASSWORD" | base64)
  mongodb-replica-set-key: $(echo -n "$REPLICA_SET_KEY" | base64)
  mongodb-app-password: $(echo -n "$APP_PASSWORD" | base64)
  mongodb-admin-password: $(echo -n "$ADMIN_PASSWORD" | base64)
  mongodb-readonly-password: $(echo -n "$READONLY_PASSWORD" | base64)
  mongodb-exporter-password: $(echo -n "$EXPORTER_PASSWORD" | base64)
EOF

  echo "Generated secret file: mongodb-secret.yaml"
  echo "Root Password: $ROOT_PASSWORD"
  echo "App Password: $APP_PASSWORD"
  echo "Admin Password: $ADMIN_PASSWORD"
  echo "Readonly Password: $READONLY_PASSWORD"
  echo "Exporter Password: $EXPORTER_PASSWORD"
  echo "Please save these passwords in a secure location."
fi

# Apply configurations
kubectl apply -f mongodb-secret.yaml
kubectl apply -f configmap.yaml
kubectl apply -f backup-pvc.yaml
kubectl apply -f statefulset.yaml
kubectl apply -f service.yaml
kubectl apply -f backup-cronjob.yaml

# Apply monitoring configurations
kubectl apply -f monitoring/prometheus-configmap.yaml
kubectl apply -f monitoring/prometheus-deployment.yaml
kubectl apply -f monitoring/service.yaml

echo "Waiting for MongoDB pods to start..."
kubectl -n dive25-mongodb wait --for=condition=Ready pod/mongodb-0 --timeout=300s

echo "MongoDB deployment completed!"
echo "To connect to MongoDB, use:"
echo "kubectl -n dive25-mongodb exec -it mongodb-0 -- mongosh -u admin -p <password> --authenticationDatabase admin"