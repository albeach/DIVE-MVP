#!/bin/bash
# scripts/update-e2e-env.sh
# This script updates e2e test environment configurations based on the central .env file
# It follows a "hardcoded defaults with environment override" approach.

set -e

# Set hardcoded defaults
DEFAULT_FRONTEND_URL="https://dive25.local"
DEFAULT_API_URL="https://api.dive25.local"
DEFAULT_KEYCLOAK_URL="https://keycloak.dive25.local"
DEFAULT_REALM="dive25"
DEFAULT_USERNAME="alice"
DEFAULT_PASSWORD="password123"

# Check if .env file exists and load it
if [ -f ".env" ]; then
  echo "Loading environment variables from .env"
  source .env
  
  # Use values from .env or defaults if not set
  FRONTEND_URL=${PUBLIC_FRONTEND_URL:-$DEFAULT_FRONTEND_URL}
  API_URL=${PUBLIC_API_URL:-$DEFAULT_API_URL}
  KEYCLOAK_URL=${PUBLIC_KEYCLOAK_URL:-$DEFAULT_KEYCLOAK_URL}
  REALM=${KEYCLOAK_REALM:-$DEFAULT_REALM}
  FRONTEND_CLIENT=${KEYCLOAK_CLIENT_ID_FRONTEND:-"dive25-frontend"}
  API_CLIENT=${KEYCLOAK_CLIENT_ID_API:-"dive25-api"}
  TEST_USER=${TEST_USERNAME:-$DEFAULT_USERNAME}
  TEST_PWD=${TEST_PASSWORD:-$DEFAULT_PASSWORD}
else
  echo "Warning: No .env file found, using default values"
  FRONTEND_URL=$DEFAULT_FRONTEND_URL
  API_URL=$DEFAULT_API_URL
  KEYCLOAK_URL=$DEFAULT_KEYCLOAK_URL
  REALM=$DEFAULT_REALM
  FRONTEND_CLIENT="dive25-frontend"
  API_CLIENT="dive25-api"
  TEST_USER=$DEFAULT_USERNAME
  TEST_PWD=$DEFAULT_PASSWORD
fi

# Ensure e2e directory exists
mkdir -p e2e/tests/helpers

echo "Updating e2e test environments..."

# Create a .env file in the e2e directory
cat > e2e/.env << EOL
# Generated from central configuration - do not edit directly
# Uses "hardcoded defaults with environment override" approach

# Base URLs
PUBLIC_FRONTEND_URL=${FRONTEND_URL}
PUBLIC_API_URL=${API_URL}
PUBLIC_KEYCLOAK_URL=${KEYCLOAK_URL}

# Authentication
KEYCLOAK_REALM=${REALM}
KEYCLOAK_CLIENT_ID_FRONTEND=${FRONTEND_CLIENT}
KEYCLOAK_CLIENT_ID_API=${API_CLIENT}

# Test credentials 
TEST_USERNAME=${TEST_USER}
TEST_PASSWORD=${TEST_PWD}
EOL

echo "E2E environment setup complete with the following URLs:"
echo "  Frontend: ${FRONTEND_URL}"
echo "  API: ${API_URL}"
echo "  Keycloak: ${KEYCLOAK_URL}" 