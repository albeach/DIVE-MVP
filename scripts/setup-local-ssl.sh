#!/bin/bash
# scripts/setup-local-ssl.sh

set -e

echo "Setting up SSL certificates for DIVE25 development environment"

# Check if mkcert is installed
if ! command -v mkcert &> /dev/null; then
    echo "mkcert is not installed. Please install it first."
    echo "On macOS: brew install mkcert"
    echo "On Linux: Follow instructions at https://github.com/FiloSottile/mkcert"
    exit 1
fi

# Create certs directory
mkdir -p ./kong/certs

# Install local CA
mkcert -install

# Generate certificates for all domains
echo "Generating certificates for DIVE25 domains..."
mkcert -cert-file ./kong/certs/dive25-cert.pem -key-file ./kong/certs/dive25-key.pem \
    "*.dive25.local" "dive25.local" \
    "api.dive25.local" "keycloak.dive25.local" "frontend.dive25.local" \
    "grafana.dive25.local" "prometheus.dive25.local" "mongo-express.dive25.local" \
    "opa.dive25.local" "phpldapadmin.dive25.local" "localhost"

# Update hosts file if not already done
if ! grep -q "dive25.local" /etc/hosts; then
    echo "Updating /etc/hosts file (requires sudo)..."
    echo "127.0.0.1 dive25.local api.dive25.local keycloak.dive25.local frontend.dive25.local grafana.dive25.local prometheus.dive25.local mongo-express.dive25.local opa.dive25.local phpldapadmin.dive25.local" | sudo tee -a /etc/hosts
fi

echo "SSL certificates created successfully!"
echo ""
echo "To start the system with SSL, run:"
echo "chmod +x ./scripts/update-kong-config.sh"
echo "./scripts/update-kong-config.sh"
echo "docker-compose up -d" 