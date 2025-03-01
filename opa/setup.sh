#!/bin/bash
# opa/setup.sh

set -e

echo "Setting up OPA for DIVE25..."

# Create directories if they don't exist
mkdir -p data bundles tests

# Create bundle directory if it doesn't exist
if [ ! -d "bundles/dive25-policies" ]; then
  echo "Creating bundle directory..."
  mkdir -p bundles/dive25-policies
fi

# Install dependencies if node is available
if command -v node &> /dev/null; then
  echo "Installing Node.js dependencies..."
  npm install
fi

# Build bundle if the script exists
if [ -f "bundles/create-bundle.js" ]; then
  echo "Building policy bundle..."
  node bundles/create-bundle.js
fi

# Start Docker Compose
echo "Starting OPA services..."
docker-compose up -d

echo "Waiting for OPA to start..."
sleep 5

# Check if OPA is running
if curl -s http://localhost:8181/health | grep -q "ok"; then
  echo "OPA is running!"
else
  echo "Error: OPA is not running properly."
  exit 1
fi

# Load policies directly
echo "Loading policies into OPA..."
curl -X PUT http://localhost:8181/v1/policies/dive25 --data-binary @policies/dive25/partner_policies.rego
curl -X PUT http://localhost:8181/v1/policies/access_policy --data-binary @policies/access_policy.rego
curl -X PUT http://localhost:8181/v1/policies/document_access --data-binary @policies/document_access.rego

echo "OPA setup completed successfully!"
echo "You can access the policy tester at: http://localhost:8181/"
echo "You can run policy tests with: ./test_policy.sh"