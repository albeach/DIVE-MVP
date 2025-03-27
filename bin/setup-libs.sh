#!/bin/bash
# DIVE25 - Library setup script
# Sets up all the library files with the correct permissions

# Set strict error handling
set -o pipefail

# Get absolute paths
export SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
export LIB_DIR="$ROOT_DIR/lib"

# Create logs directory
mkdir -p "$ROOT_DIR/logs"

# Display header
echo "DIVE25 - Setting up libraries"
echo "============================"
echo

# Check library directory exists
if [ ! -d "$LIB_DIR" ]; then
  echo "Creating library directory..."
  mkdir -p "$LIB_DIR"
fi

# Make all library scripts executable
echo "Making library scripts executable..."
find "$LIB_DIR" -name "*.sh" -type f -exec chmod +x {} \;

# Make all bin scripts executable
echo "Making bin scripts executable..."
find "$SCRIPT_DIR" -name "*.sh" -type f -exec chmod +x {} \;

# Create config directories
echo "Creating configuration directories..."
mkdir -p "$ROOT_DIR/config/env"
mkdir -p "$ROOT_DIR/config/kong"
mkdir -p "$ROOT_DIR/config/keycloak"

# Create example environment files
echo "Creating example environment files..."

# Dev environment
cat > "$ROOT_DIR/config/env/dev.env" << EOF
# DIVE25 Development Environment Configuration
ENVIRONMENT=dev
BASE_DOMAIN=dive25.local
FRONTEND_DOMAIN=frontend
API_DOMAIN=api
KEYCLOAK_DOMAIN=keycloak
KONG_DOMAIN=kong
KEYCLOAK_REALM=dive25
KEYCLOAK_CLIENT_ID=dive25-frontend
KEYCLOAK_CLIENT_SECRET=dev-secret-key
EOF

# Staging environment
cat > "$ROOT_DIR/config/env/staging.env" << EOF
# DIVE25 Staging Environment Configuration
ENVIRONMENT=staging
BASE_DOMAIN=dive25.staging
FRONTEND_DOMAIN=frontend
API_DOMAIN=api
KEYCLOAK_DOMAIN=keycloak
KONG_DOMAIN=kong
KEYCLOAK_REALM=dive25
KEYCLOAK_CLIENT_ID=dive25-frontend
KEYCLOAK_CLIENT_SECRET=staging-secret-key
EOF

# Production environment
cat > "$ROOT_DIR/config/env/prod.env" << EOF
# DIVE25 Production Environment Configuration
ENVIRONMENT=prod
BASE_DOMAIN=dive25.com
FRONTEND_DOMAIN=app
API_DOMAIN=api
KEYCLOAK_DOMAIN=auth
KONG_DOMAIN=gateway
KEYCLOAK_REALM=dive25
KEYCLOAK_CLIENT_ID=dive25-frontend
KEYCLOAK_CLIENT_SECRET=change-me-in-production
EOF

# Create base .env file if it doesn't exist
if [ ! -f "$ROOT_DIR/.env" ]; then
  echo "Creating base .env file..."
  cp "$ROOT_DIR/config/env/dev.env" "$ROOT_DIR/.env"
fi

# Create a basic kong.conf file for DB-less configuration
cat > "$ROOT_DIR/config/kong/kong.conf" << EOF
# Kong configuration file (DB-less mode)
database = off
declarative_config = /etc/kong/kong.yml
admin_listen = 0.0.0.0:8001, 0.0.0.0:8444 ssl
proxy_listen = 0.0.0.0:8000, 0.0.0.0:8443 ssl
ssl_cert = /etc/kong/certs/dive25-cert.pem
ssl_cert_key = /etc/kong/certs/dive25-key.pem
log_level = notice
plugins = bundled,oidc
EOF

echo "Library setup completed successfully!"
exit 0 