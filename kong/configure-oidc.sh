#!/bin/bash
set -e

# Kong OIDC Configuration Script
# This script configures Kong with OIDC authentication for Keycloak
# Using standardized URL variables

KONG_ADMIN_URL=${KONG_ADMIN_URL:-http://localhost:8001}

echo "Configuring Kong with OIDC authentication for Keycloak..."
echo "Using a phased approach for safer deployment..."

# Load environment variables if they exist
if [ -f "/.env" ]; then
  echo "Loading environment variables from /.env"
  source /.env
elif [ -f "/app/.env" ]; then
  echo "Loading environment variables from /app/.env"
  source /app/.env
fi

# Use standardized variables with fallbacks
# Internal URLs (service-to-service communication)
KEYCLOAK_URL=${INTERNAL_KEYCLOAK_URL:-http://keycloak:8080}
KEYCLOAK_AUTH_URL=${INTERNAL_KEYCLOAK_AUTH_URL:-http://keycloak:8080/auth}

# External URLs (browser-to-service communication)
PUBLIC_KEYCLOAK_URL=${PUBLIC_KEYCLOAK_URL:-https://keycloak.dive25.local}
PUBLIC_KEYCLOAK_AUTH_URL=${PUBLIC_KEYCLOAK_AUTH_URL:-https://keycloak.dive25.local/auth}
PUBLIC_FRONTEND_URL=${PUBLIC_FRONTEND_URL:-https://frontend.dive25.local}
PUBLIC_API_URL=${PUBLIC_API_URL:-https://api.dive25.local}

# Authentication configuration
KEYCLOAK_REALM=${KEYCLOAK_REALM:-dive25}
KEYCLOAK_CLIENT_ID_FRONTEND=${KEYCLOAK_CLIENT_ID_FRONTEND:-dive25-frontend}
KEYCLOAK_CLIENT_ID_API=${KEYCLOAK_CLIENT_ID_API:-dive25-api}
KEYCLOAK_CLIENT_SECRET=${KEYCLOAK_CLIENT_SECRET:-change-me-in-production}

echo "Using configuration:"
echo "INTERNAL_KEYCLOAK_URL: $KEYCLOAK_URL"
echo "INTERNAL_KEYCLOAK_AUTH_URL: $KEYCLOAK_AUTH_URL"
echo "PUBLIC_KEYCLOAK_URL: $PUBLIC_KEYCLOAK_URL"
echo "PUBLIC_KEYCLOAK_AUTH_URL: $PUBLIC_KEYCLOAK_AUTH_URL"
echo "PUBLIC_FRONTEND_URL: $PUBLIC_FRONTEND_URL"
echo "PUBLIC_API_URL: $PUBLIC_API_URL"
echo "KEYCLOAK_REALM: $KEYCLOAK_REALM"

# Wait for Kong Admin API to be available
max_retries=15
retry_count=0

until curl -s $KONG_ADMIN_URL > /dev/null; do
  retry_count=$((retry_count+1))
  if [ $retry_count -ge $max_retries ]; then
    echo "Error: Kong Admin API is not available after $max_retries attempts"
    echo "Check Kong's logs for errors:"
    echo "  docker logs dive25-kong"
    exit 1
  fi
  echo "Waiting for Kong Admin API to become available... (attempt $retry_count/$max_retries)"
  sleep 5
done

echo "Kong Admin API is available at $KONG_ADMIN_URL"

# Check if OIDC plugin is installed and enabled
if curl -s $KONG_ADMIN_URL/plugins/enabled | grep -q oidc-auth; then
  echo "✅ OIDC Auth plugin is installed and enabled in Kong"
else
  echo "⚠️ Warning: OIDC Auth plugin is not enabled in Kong"
  echo "Checking plugin installation status..."

  # Get a list of all installed plugins for diagnosis
  echo "Currently enabled plugins:"
  curl -s $KONG_ADMIN_URL/plugins/enabled | jq -r '.enabled_plugins[]' || echo "Failed to get enabled plugins"

  # Check plugin schema
  echo "Verifying plugin schema..."
  if curl -s -I $KONG_ADMIN_URL/schemas/plugins/oidc-auth | grep -q "200 OK"; then
    echo "✅ OIDC Auth plugin schema exists"
  else
    echo "❌ OIDC Auth plugin schema not found"
    echo "Make sure the plugin is properly installed and registered with Kong"
    echo "🔧 Troubleshooting steps:"
    echo "  1. Check Kong's Dockerfile to ensure lua-resty-openidc is installed"
    echo "  2. Verify plugin files are correctly placed in /usr/local/share/lua/5.1/kong/plugins/oidc-auth"
    echo "  3. Ensure KONG_PLUGINS includes 'oidc-auth'"
    echo "  4. Check Kong logs for any plugin loading errors"
    
    # Try to manually enable the plugin if needed
    echo "Trying to enable the plugin..."
    curl -s -X POST $KONG_ADMIN_URL/plugins -d "name=oidc-auth" || echo "Failed to enable plugin via API"
  fi
  
  # Continue anyway as the plugin might be enabled in kong.yml
  echo "Will continue with configuration, but OIDC functionality may not work..."
fi

echo "Verifying Keycloak connectivity..."
# Test connection to Keycloak OpenID configuration endpoint
# Use the internal URL for service-to-service communication
KEYCLOAK_OPENID_URL="${KEYCLOAK_AUTH_URL}/realms/${KEYCLOAK_REALM}/.well-known/openid-configuration"
if curl -k -s -f "$KEYCLOAK_OPENID_URL" > /dev/null; then
  echo "✅ Successfully connected to Keycloak OpenID configuration endpoint"
else
  echo "❌ Error: Could not connect to Keycloak OpenID configuration endpoint"
  echo "Keycloak URL: $KEYCLOAK_OPENID_URL"
  echo "This is critical for OIDC to function."
  echo "🔧 Troubleshooting steps:"
  echo "  1. Check if Keycloak is running: docker ps | grep keycloak"
  echo "  2. Verify the URL is correct in your environment variables"
  echo "  3. Check Keycloak logs: docker logs dive25-keycloak"
  echo "  4. Ensure the realm $KEYCLOAK_REALM exists in Keycloak"
  echo "  5. Check network connectivity between Kong and Keycloak"
  # Try fallback without /auth path
  KEYCLOAK_OPENID_URL_ALT="${KEYCLOAK_URL}/realms/${KEYCLOAK_REALM}/.well-known/openid-configuration"
  echo "Trying alternate URL: $KEYCLOAK_OPENID_URL_ALT"
  if curl -k -s -f "$KEYCLOAK_OPENID_URL_ALT" > /dev/null; then
    echo "✅ Successfully connected to alternate Keycloak OpenID configuration endpoint"
    KEYCLOAK_OPENID_URL=$KEYCLOAK_OPENID_URL_ALT
    KEYCLOAK_AUTH_URL=$KEYCLOAK_URL
    echo "Using alternate Keycloak auth URL: $KEYCLOAK_AUTH_URL"
  else
    echo "❌ Error: Could not connect to alternate Keycloak OpenID configuration endpoint"
  fi
fi

# Get the discovery document to verify the configuration
echo "Fetching OpenID Configuration..."
OPENID_CONFIG=$(curl -k -s $KEYCLOAK_OPENID_URL)
if [ -z "$OPENID_CONFIG" ]; then
  echo "❌ Error: Could not fetch OpenID Configuration"
  exit 1
else
  echo "✅ Successfully fetched OpenID Configuration"
  # Verify that the issuer matches the expected Keycloak URL
  ISSUER=$(echo $OPENID_CONFIG | jq -r '.issuer')
  echo "Keycloak Issuer: $ISSUER"
  
  # Extract token endpoints for debugging
  TOKEN_ENDPOINT=$(echo $OPENID_CONFIG | jq -r '.token_endpoint')
  AUTH_ENDPOINT=$(echo $OPENID_CONFIG | jq -r '.authorization_endpoint')
  echo "Token Endpoint: $TOKEN_ENDPOINT"
  echo "Auth Endpoint: $AUTH_ENDPOINT"
  
  # Save these for the Kong configuration
  DISCOVERY_URL=$KEYCLOAK_OPENID_URL
  
  # Create a public-facing discovery URL for token validation
  # NOTE: We're not using this for discovery as Kong can't resolve it from inside the container
  # Instead we keep using the internal URL but disable SSL verification
  PUBLIC_KEYCLOAK_OPENID_URL="${PUBLIC_KEYCLOAK_AUTH_URL}/realms/${KEYCLOAK_REALM}/.well-known/openid-configuration"
  echo "Public Keycloak OpenID URL: $PUBLIC_KEYCLOAK_OPENID_URL (not used for discovery)"
  
  # IMPORTANT: We keep using internal URL for discovery to ensure Kong can access it
  # DISCOVERY_URL="$PUBLIC_KEYCLOAK_OPENID_URL"
fi

# Create or update frontend service in Kong
echo "Configuring Kong frontend service..."
FRONTEND_SERVICE_NAME="frontend-service"

# Check if the service already exists
SERVICE_ID=$(curl -s $KONG_ADMIN_URL/services/$FRONTEND_SERVICE_NAME | jq -r '.id')
if [ "$SERVICE_ID" != "null" ]; then
  echo "Updating existing frontend service: $FRONTEND_SERVICE_NAME"
  curl -s -X PATCH $KONG_ADMIN_URL/services/$FRONTEND_SERVICE_NAME \
    -d "name=$FRONTEND_SERVICE_NAME" \
    -d "url=${INTERNAL_FRONTEND_URL}" || echo "Failed to update frontend service"
else
  echo "Creating new frontend service: $FRONTEND_SERVICE_NAME"
  curl -s -X POST $KONG_ADMIN_URL/services \
    -d "name=$FRONTEND_SERVICE_NAME" \
    -d "url=${INTERNAL_FRONTEND_URL}" || echo "Failed to create frontend service"
fi

# Create or update frontend route in Kong
FRONTEND_ROUTE_NAME="frontend-route"
HOST="${FRONTEND_DOMAIN}.${BASE_DOMAIN}"

# Check if the route already exists
ROUTE_ID=$(curl -s $KONG_ADMIN_URL/services/$FRONTEND_SERVICE_NAME/routes/$FRONTEND_ROUTE_NAME | jq -r '.id')
if [ "$ROUTE_ID" != "null" ]; then
  echo "Updating existing frontend route: $FRONTEND_ROUTE_NAME"
  curl -s -X PATCH $KONG_ADMIN_URL/services/$FRONTEND_SERVICE_NAME/routes/$FRONTEND_ROUTE_NAME \
    -d "name=$FRONTEND_ROUTE_NAME" \
    -d "hosts[]=$HOST" \
    -d "preserve_host=true" \
    -d "protocols[]=http" \
    -d "protocols[]=https" || echo "Failed to update frontend route"
else
  echo "Creating new frontend route: $FRONTEND_ROUTE_NAME"
  curl -s -X POST $KONG_ADMIN_URL/services/$FRONTEND_SERVICE_NAME/routes \
    -d "name=$FRONTEND_ROUTE_NAME" \
    -d "hosts[]=$HOST" \
    -d "preserve_host=true" \
    -d "protocols[]=http" \
    -d "protocols[]=https" || echo "Failed to create frontend route"
fi

# Create or update API service in Kong
echo "Configuring Kong API service..."
API_SERVICE_NAME="api-service"

# Check if the service already exists
SERVICE_ID=$(curl -s $KONG_ADMIN_URL/services/$API_SERVICE_NAME | jq -r '.id')
if [ "$SERVICE_ID" != "null" ]; then
  echo "Updating existing API service: $API_SERVICE_NAME"
  curl -s -X PATCH $KONG_ADMIN_URL/services/$API_SERVICE_NAME \
    -d "name=$API_SERVICE_NAME" \
    -d "url=${INTERNAL_API_URL}" || echo "Failed to update API service"
else
  echo "Creating new API service: $API_SERVICE_NAME"
  curl -s -X POST $KONG_ADMIN_URL/services \
    -d "name=$API_SERVICE_NAME" \
    -d "url=${INTERNAL_API_URL}" || echo "Failed to create API service"
fi

# Create or update API route in Kong
API_ROUTE_NAME="api-route"
API_HOST="${API_DOMAIN}.${BASE_DOMAIN}"

# Check if the route already exists
ROUTE_ID=$(curl -s $KONG_ADMIN_URL/services/$API_SERVICE_NAME/routes/$API_ROUTE_NAME | jq -r '.id')
if [ "$ROUTE_ID" != "null" ]; then
  echo "Updating existing API route: $API_ROUTE_NAME"
  curl -s -X PATCH $KONG_ADMIN_URL/services/$API_SERVICE_NAME/routes/$API_ROUTE_NAME \
    -d "name=$API_ROUTE_NAME" \
    -d "hosts[]=$API_HOST" \
    -d "preserve_host=true" \
    -d "protocols[]=http" \
    -d "protocols[]=https" || echo "Failed to update API route"
else
  echo "Creating new API route: $API_ROUTE_NAME"
  curl -s -X POST $KONG_ADMIN_URL/services/$API_SERVICE_NAME/routes \
    -d "name=$API_ROUTE_NAME" \
    -d "hosts[]=$API_HOST" \
    -d "preserve_host=true" \
    -d "protocols[]=http" \
    -d "protocols[]=https" || echo "Failed to create API route"
fi

# Now configure the OIDC plugin for the frontend
echo "Configuring OIDC plugin for frontend service..."
# Check if the OIDC plugin already exists for this service
PLUGIN_ID=$(curl -s $KONG_ADMIN_URL/services/$FRONTEND_SERVICE_NAME/plugins | jq -r '.data[] | select(.name == "oidc-auth") | .id')

# Prepare callback URLs - use the PUBLIC domain for the browser to access
if [ "$USE_HTTPS" = "true" ]; then
  # For HTTPS, only add port if it's not the standard 443
  if [ "$KONG_PROXY_PORT" = "443" ]; then
    CALLBACK_URL="https://${FRONTEND_DOMAIN}.${BASE_DOMAIN}/callback"
  else
    CALLBACK_URL="https://${FRONTEND_DOMAIN}.${BASE_DOMAIN}:${KONG_PROXY_PORT}/callback"
  fi
else
  # For HTTP, only add port if it's not the standard 80
  if [ "$KONG_PROXY_PORT" = "80" ]; then
    CALLBACK_URL="http://${FRONTEND_DOMAIN}.${BASE_DOMAIN}/callback"
  else
    CALLBACK_URL="http://${FRONTEND_DOMAIN}.${BASE_DOMAIN}:${KONG_PROXY_PORT}/callback"
  fi
fi

# IMPORTANT: Ensure the redirect_uri exactly matches what's registered in Keycloak
# This is critical for proper OIDC token exchange
echo "Using callback URL: $CALLBACK_URL"

# Prepare plugin configuration
PLUGIN_CONFIG=$(cat <<EOF
{
  "name": "oidc-auth",
  "config": {
    "client_id": "${KEYCLOAK_CLIENT_ID_FRONTEND}",
    "client_secret": "${KEYCLOAK_CLIENT_SECRET}",
    "discovery": "${DISCOVERY_URL}",
    "introspection_endpoint": "${TOKEN_ENDPOINT}",
    "bearer_only": "no",
    "realm": "${KEYCLOAK_REALM}",
    "redirect_uri_path": "/callback",
    "logout_path": "/logout",
    "redirect_after_logout_uri": "${PUBLIC_FRONTEND_URL}",
    "scope": "openid email profile",
    "response_type": "code",
    "ssl_verify": "no",
    "token_endpoint_auth_method": "client_secret_post",
    "filters": null,
    "logout_query_arg": "logout",
    "redirect_uri": "${CALLBACK_URL}",
    "introspection_endpoint_auth_method": "client_secret_post",
    "timeout": 10000,
    "session_secret": "${SESSION_SECRET:-change-me-in-production}",
    "cookie_domain": null,
    "cookie_secure": true,
    "cookie_samesite": "Lax",
    "pass_userinfo": true,
    "recovery_page_path": null
  }
}
EOF
)

if [ -n "$PLUGIN_ID" ]; then
  echo "Updating existing OIDC plugin for frontend service..."
  curl -s -X PATCH $KONG_ADMIN_URL/plugins/$PLUGIN_ID \
    -H "Content-Type: application/json" \
    -d "$PLUGIN_CONFIG" || echo "Failed to update OIDC plugin"
else
  echo "Creating new OIDC plugin for frontend service..."
  curl -s -X POST $KONG_ADMIN_URL/services/$FRONTEND_SERVICE_NAME/plugins \
    -H "Content-Type: application/json" \
    -d "$PLUGIN_CONFIG" || echo "Failed to create OIDC plugin"
fi

echo "OIDC Authentication configuration complete!" 