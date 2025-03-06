#!/bin/bash
set -e

echo "==== Kong Configuration Fix Script ===="
echo "This script will properly configure Kong routes and fix OIDC plugin issues"

# Get environment variables
source .env || echo "Warning: Cannot load .env file"

# Kong Admin URL (local direct access to avoid network issues)
KONG_ADMIN_URL="http://localhost:9444"
echo "Using Kong Admin URL: $KONG_ADMIN_URL"

# Verify Kong Admin API is accessible
if ! curl -s $KONG_ADMIN_URL > /dev/null; then
  echo "ERROR: Cannot connect to Kong Admin API at $KONG_ADMIN_URL"
  echo "Make sure Kong is running and the Admin API is accessible"
  exit 1
fi

echo "✅ Kong Admin API is accessible"

# Get Keycloak configuration
KEYCLOAK_URL=${PUBLIC_KEYCLOAK_URL:-https://keycloak.dive25.local:4432}
KEYCLOAK_REALM=${KEYCLOAK_REALM:-dive25}
KEYCLOAK_CLIENT_ID=${KEYCLOAK_CLIENT_ID_FRONTEND:-dive25-frontend}
KEYCLOAK_CLIENT_SECRET=${KEYCLOAK_CLIENT_SECRET:-change-me-in-production}
PUBLIC_FRONTEND_URL=${PUBLIC_FRONTEND_URL:-https://frontend.dive25.local:4430}

# Verify routes exist and are properly configured
echo "Checking routes and services..."

# Check and fix frontend service
echo "Configuring frontend service..."
FRONTEND_SERVICE=$(curl -s $KONG_ADMIN_URL/services/frontend-service)
if echo "$FRONTEND_SERVICE" | grep -q "not found"; then
  echo "Creating frontend service..."
  curl -s -X POST $KONG_ADMIN_URL/services \
    -d "name=frontend-service" \
    -d "url=http://frontend:3000"
else
  echo "Frontend service exists, updating..."
  curl -s -X PATCH $KONG_ADMIN_URL/services/frontend-service \
    -d "url=http://frontend:3000"
fi

# Check and fix frontend route
echo "Configuring frontend route..."
FRONTEND_ROUTE=$(curl -s $KONG_ADMIN_URL/services/frontend-service/routes/frontend-route)
if echo "$FRONTEND_ROUTE" | grep -q "not found"; then
  echo "Creating frontend route..."
  curl -s -X POST $KONG_ADMIN_URL/services/frontend-service/routes \
    -d "name=frontend-route" \
    -d "hosts[]=frontend.dive25.local" \
    -d "preserve_host=true" \
    -d "protocols[]=http" \
    -d "protocols[]=https"
else
  echo "Frontend route exists, updating..."
  curl -s -X PATCH $KONG_ADMIN_URL/services/frontend-service/routes/frontend-route \
    -d "hosts[]=frontend.dive25.local" \
    -d "preserve_host=true" \
    -d "protocols[]=http" \
    -d "protocols[]=https"
fi

# Check and fix API service
echo "Configuring API service..."
API_SERVICE=$(curl -s $KONG_ADMIN_URL/services/api-service)
if echo "$API_SERVICE" | grep -q "not found"; then
  echo "Creating API service..."
  curl -s -X POST $KONG_ADMIN_URL/services \
    -d "name=api-service" \
    -d "url=http://api:3000"
else
  echo "API service exists, updating..."
  curl -s -X PATCH $KONG_ADMIN_URL/services/api-service \
    -d "url=http://api:3000"
fi

# Check and fix API route
echo "Configuring API route..."
API_ROUTE=$(curl -s $KONG_ADMIN_URL/services/api-service/routes/api-route)
if echo "$API_ROUTE" | grep -q "not found"; then
  echo "Creating API route..."
  curl -s -X POST $KONG_ADMIN_URL/services/api-service/routes \
    -d "name=api-route" \
    -d "hosts[]=api.dive25.local" \
    -d "preserve_host=true" \
    -d "protocols[]=http" \
    -d "protocols[]=https"
else
  echo "API route exists, updating..."
  curl -s -X PATCH $KONG_ADMIN_URL/services/api-service/routes/api-route \
    -d "hosts[]=api.dive25.local" \
    -d "preserve_host=true" \
    -d "protocols[]=http" \
    -d "protocols[]=https"
fi

# Create Kong route for kong.dive25.local
echo "Checking Kong proxy route..."
KONG_SERVICE=$(curl -s $KONG_ADMIN_URL/services/kong-proxy-service)
if echo "$KONG_SERVICE" | grep -q "not found"; then
  echo "Creating Kong proxy service..."
  curl -s -X POST $KONG_ADMIN_URL/services \
    -d "name=kong-proxy-service" \
    -d "url=http://localhost:8000"
else
  echo "Kong proxy service exists, updating..."
  curl -s -X PATCH $KONG_ADMIN_URL/services/kong-proxy-service \
    -d "url=http://localhost:8000"
fi

# Check and fix Kong route
echo "Configuring Kong proxy route..."
KONG_ROUTE=$(curl -s $KONG_ADMIN_URL/services/kong-proxy-service/routes/kong-proxy-route)
if echo "$KONG_ROUTE" | grep -q "not found"; then
  echo "Creating Kong proxy route..."
  curl -s -X POST $KONG_ADMIN_URL/services/kong-proxy-service/routes \
    -d "name=kong-proxy-route" \
    -d "hosts[]=kong.dive25.local" \
    -d "preserve_host=true" \
    -d "protocols[]=http" \
    -d "protocols[]=https"
else
  echo "Kong proxy route exists, updating..."
  curl -s -X PATCH $KONG_ADMIN_URL/services/kong-proxy-service/routes/kong-proxy-route \
    -d "hosts[]=kong.dive25.local" \
    -d "preserve_host=true" \
    -d "protocols[]=http" \
    -d "protocols[]=https"
fi

# Remove any existing OIDC plugin with schema violations
echo "Checking for existing OIDC plugin..."
PLUGIN_ID=$(curl -s $KONG_ADMIN_URL/plugins?name=oidc-auth | jq -r '.data[0].id')
if [ "$PLUGIN_ID" != "null" ] && [ -n "$PLUGIN_ID" ]; then
  echo "Removing existing OIDC plugin with ID: $PLUGIN_ID"
  curl -s -X DELETE $KONG_ADMIN_URL/plugins/$PLUGIN_ID
fi

# Add fixed OIDC plugin configuration
echo "Configuring OIDC plugin with corrected schema..."
OPENID_CONFIG_URL="$KEYCLOAK_URL/realms/$KEYCLOAK_REALM/.well-known/openid-configuration"

# Check if Keycloak OpenID configuration is accessible
if ! curl -s -k $OPENID_CONFIG_URL > /dev/null; then
  echo "WARNING: Cannot access Keycloak OpenID configuration at $OPENID_CONFIG_URL"
  echo "OIDC plugin may not work correctly. Continuing anyway..."
fi

# Adding the plugin with correct boolean types
curl -s -X POST $KONG_ADMIN_URL/plugins \
  -d "name=oidc-auth" \
  -d "config.client_id=$KEYCLOAK_CLIENT_ID" \
  -d "config.client_secret=$KEYCLOAK_CLIENT_SECRET" \
  -d "config.discovery=$OPENID_CONFIG_URL" \
  -d "config.bearer_only=false" \
  -d "config.realm=$KEYCLOAK_REALM" \
  -d "config.redirect_uri_path=/callback" \
  -d "config.logout_path=/logout" \
  -d "config.redirect_after_logout_uri=$PUBLIC_FRONTEND_URL" \
  -d "config.scope=openid email profile" \
  -d "config.response_type=code" \
  -d "config.ssl_verify=false" \
  -d "config.token_endpoint_auth_method=client_secret_post" \
  -d "config.introspection_endpoint_auth_method=client_secret_post"

echo "==== Kong Configuration Complete ===="
echo "You should now be able to access Kong at https://kong.dive25.local:4433"
echo "If you still have issues, please check:"
echo "  1. Your SSL certificates are valid for *.dive25.local"
echo "  2. Your DNS/hosts file is correctly configured"
echo "  3. Kong is properly listening on port 4433"
echo "  4. Keycloak is accessible from Kong"

exit 0 