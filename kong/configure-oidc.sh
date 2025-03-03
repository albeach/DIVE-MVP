#!/bin/bash
set -e

KONG_ADMIN_URL=${KONG_ADMIN_URL:-http://localhost:8001}

echo "Configuring Kong with OIDC authentication for Keycloak..."

# Wait for Kong Admin API to be available
until curl -s $KONG_ADMIN_URL > /dev/null; do
  echo "Waiting for Kong Admin API to become available..."
  sleep 3
done

# Check if OIDC plugin is installed and enabled
if curl -s $KONG_ADMIN_URL/plugins/enabled | grep -q oidc-auth; then
  echo "OIDC Auth plugin is installed and enabled in Kong"
else
  echo "Warning: OIDC Auth plugin is not enabled in Kong"
  echo "Checking plugin installation status..."

  # Check plugin schema
  echo "Verifying plugin schema..."
  if curl -s -I $KONG_ADMIN_URL/schemas/plugins/oidc-auth | grep -q "200 OK"; then
    echo "OIDC Auth plugin schema exists"
  else
    echo "OIDC Auth plugin schema not found"
    echo "Make sure the plugin is properly installed and registered with Kong"
  fi

  # Try to manually enable the plugin if needed
  echo "Trying to enable the plugin..."
  curl -s -X POST $KONG_ADMIN_URL/plugins -d "name=oidc-auth" || echo "Failed to enable plugin via API"
  
  # Continue anyway as the plugin might be enabled in kong.yml
  echo "Will continue with configuration..."
fi

echo "Verifying OIDC configuration..."

# Verify existing service configurations
echo "Checking services with OIDC config..."
curl -s $KONG_ADMIN_URL/services | grep -q "frontend-service" && echo "Frontend service exists" || echo "Warning: Frontend service not found"
curl -s $KONG_ADMIN_URL/services | grep -q "api-service" && echo "API service exists" || echo "Warning: API service not found"

echo "Validating Keycloak connectivity..."
# Test connection to Keycloak OpenID configuration endpoint
KEYCLOAK_URL="http://keycloak:8080/auth/realms/dive25/.well-known/openid-configuration"
if curl -k -s "$KEYCLOAK_URL" > /dev/null; then
  echo "Successfully connected to Keycloak OpenID configuration endpoint"
else
  echo "Warning: Could not connect to Keycloak OpenID configuration endpoint"
  echo "Keycloak URL: $KEYCLOAK_URL"
  echo "Make sure Keycloak is running and accessible"
fi

echo "Kong OIDC configuration setup complete"
echo "Note: For Kong 3.x, session management uses the plugin's internal implementation" 