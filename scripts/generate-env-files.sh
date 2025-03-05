#!/bin/bash
# scripts/generate-env-files.sh
# This script generates environment files for different services
# using a "hardcoded defaults with environment override" approach

echo "Generating environment files for services..."

# Set hardcoded defaults
DEFAULT_FRONTEND_URL="https://dive25.local"
DEFAULT_API_URL="https://api.dive25.local"
DEFAULT_KEYCLOAK_URL="https://keycloak.dive25.local"
DEFAULT_REALM="dive25"
DEFAULT_FRONTEND_CLIENT="dive25-frontend"
DEFAULT_API_CLIENT="dive25-api"

# Load environment variables from .env if it exists
if [ -f ".env" ]; then
  echo "Loading variables from .env file"
  source .env
  
  # Use values from .env or defaults if not set
  FRONTEND_URL=${PUBLIC_FRONTEND_URL:-$DEFAULT_FRONTEND_URL}
  API_URL=${PUBLIC_API_URL:-$DEFAULT_API_URL}
  KEYCLOAK_URL=${PUBLIC_KEYCLOAK_URL:-$DEFAULT_KEYCLOAK_URL}
  REALM=${KEYCLOAK_REALM:-$DEFAULT_REALM}
  FRONTEND_CLIENT=${KEYCLOAK_CLIENT_ID_FRONTEND:-$DEFAULT_FRONTEND_CLIENT}
  API_CLIENT=${KEYCLOAK_CLIENT_ID_API:-$DEFAULT_API_CLIENT}
else
  echo "Warning: No .env file found, using default values"
  FRONTEND_URL=$DEFAULT_FRONTEND_URL
  API_URL=$DEFAULT_API_URL
  KEYCLOAK_URL=$DEFAULT_KEYCLOAK_URL
  REALM=$DEFAULT_REALM
  FRONTEND_CLIENT=$DEFAULT_FRONTEND_CLIENT
  API_CLIENT=$DEFAULT_API_CLIENT
fi

# Ensure needed directories exist
mkdir -p frontend

# Generate frontend/.env.local
cat > frontend/.env.local << EOL
# This file is auto-generated - do not edit directly
# Uses "hardcoded defaults with environment override" approach

# Keycloak configuration
NEXT_PUBLIC_KEYCLOAK_URL=${KEYCLOAK_URL}/auth
NEXT_PUBLIC_KEYCLOAK_REALM=${REALM}
NEXT_PUBLIC_KEYCLOAK_CLIENT_ID=${FRONTEND_CLIENT}

# Frontend URL
NEXT_PUBLIC_FRONTEND_URL=${FRONTEND_URL}

# API URL
NEXT_PUBLIC_API_URL=${API_URL}/api/v1
EOL

echo "Generated frontend/.env.local with:"
echo "  Frontend URL: ${FRONTEND_URL}"
echo "  API URL: ${API_URL}/api/v1"
echo "  Keycloak URL: ${KEYCLOAK_URL}/auth"

# Update E2E environment if script exists
if [ -f "./scripts/update-e2e-env.sh" ]; then
  echo "Updating E2E environment..."
  bash ./scripts/update-e2e-env.sh
  echo "E2E environment updated."
fi

echo "Environment file generation completed successfully." 