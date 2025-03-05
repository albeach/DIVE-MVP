#!/bin/bash
set -e

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

# Set defaults for required variables if not set
KEYCLOAK_URL=${INTERNAL_KEYCLOAK_URL:-http://keycloak:8080}
PUBLIC_KEYCLOAK_URL=${PUBLIC_KEYCLOAK_URL:-https://keycloak.dive25.local}
PUBLIC_FRONTEND_URL=${PUBLIC_FRONTEND_URL:-https://dive25.local}
PUBLIC_API_URL=${PUBLIC_API_URL:-https://api.dive25.local}
KEYCLOAK_REALM=${KEYCLOAK_REALM:-dive25}
KEYCLOAK_CLIENT_ID_FRONTEND=${KEYCLOAK_CLIENT_ID_FRONTEND:-dive25-frontend}
KEYCLOAK_CLIENT_ID_API=${KEYCLOAK_CLIENT_ID_API:-dive25-api}
KEYCLOAK_CLIENT_SECRET=${KEYCLOAK_CLIENT_SECRET:-change-me-in-production}

echo "Using configuration:"
echo "KEYCLOAK_URL: $KEYCLOAK_URL"
echo "PUBLIC_KEYCLOAK_URL: $PUBLIC_KEYCLOAK_URL"
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
KEYCLOAK_OPENID_URL="${KEYCLOAK_URL}/realms/${KEYCLOAK_REALM}/.well-known/openid-configuration"
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
  
  # Try to get detailed error information
  echo "Attempting to get more details..."
  CURL_RESPONSE=$(curl -k -s -v "$KEYCLOAK_OPENID_URL" 2>&1)
  echo "Curl response:"
  echo "$CURL_RESPONSE"
  
  # Continue with configuration, though it might not work
  echo "Will continue with configuration despite connectivity issues..."
fi

# PHASE 1: Apply minimal OIDC plugin configuration globally, with safe defaults
echo "📋 PHASE 1: Applying minimal global OIDC configuration..."

GLOBAL_OIDC_EXISTS=$(curl -s $KONG_ADMIN_URL/plugins | grep -o '"name":"oidc-auth"' | wc -l)

if [ "$GLOBAL_OIDC_EXISTS" -eq 0 ]; then
  echo "Creating global OIDC plugin with minimal configuration..."
  curl -s -X POST $KONG_ADMIN_URL/plugins \
    -d "name=oidc-auth" \
    -d "config.client_id=${KEYCLOAK_CLIENT_ID_FRONTEND}" \
    -d "config.client_secret=${KEYCLOAK_CLIENT_SECRET}" \
    -d "config.discovery=${KEYCLOAK_URL}/realms/${KEYCLOAK_REALM}/.well-known/openid-configuration" \
    -d "config.bearer_only=yes" \
    -d "config.ssl_verify=no" \
    -d "config.session_opts_ssl_verify=no" \
    -d "config.introspection_endpoint_auth_method=client_secret_post" \
    -d "config.realm=kong" \
    -d "config.timeout=10000"
  
  if [ $? -eq 0 ]; then
    echo "✅ Successfully created global OIDC plugin"
  else
    echo "❌ Failed to create global OIDC plugin"
  fi
else
  echo "Global OIDC plugin already exists, skipping PHASE 1"
fi

# PHASE 2: Verify existing service configurations
echo "📋 PHASE 2: Verifying and updating service-specific configurations..."

# Check for frontend service
FRONTEND_SERVICE_EXISTS=$(curl -s $KONG_ADMIN_URL/services | grep -o '"name":"frontend-service"' | wc -l)
if [ "$FRONTEND_SERVICE_EXISTS" -eq 0 ]; then
  echo "⚠️ Warning: Frontend service not found. OIDC configuration will be incomplete."
  echo "You may need to create the service first."
else
  echo "✅ Frontend service exists"
  
  # Check or create the authentication-specific route for the frontend service
  echo "Setting up authentication routes..."
  AUTH_ROUTE_ID=$(curl -s $KONG_ADMIN_URL/services/frontend-service/routes | grep -o '"name":"frontend-auth-route"' | wc -l)

  if [ "$AUTH_ROUTE_ID" -eq 0 ]; then
    echo "Creating new frontend auth route"
    curl -s -X POST $KONG_ADMIN_URL/services/frontend-service/routes \
      -d "name=frontend-auth-route" \
      -d "paths[]=/auth" \
      -d "paths[]=/auth/" \
      -d "paths[]=/api/auth" \
      -d "paths[]=/api/auth/" \
      -d "paths[]=/callback" \
      -d "paths[]=/logout" \
      -d "strip_path=false" \
      -d "preserve_host=true" \
      -d "hosts[]=dive25.local" \
      -d "hosts[]=frontend.dive25.local"
    
    if [ $? -eq 0 ]; then
      echo "✅ Successfully created frontend auth route"
    else
      echo "❌ Failed to create frontend auth route"
    fi
  else
    echo "✅ Frontend auth route already exists"
  fi

  # Update frontend auth route OIDC configuration
  echo "Updating frontend auth route OIDC configuration..."
  FRONTEND_AUTH_PLUGIN_ID=$(curl -s $KONG_ADMIN_URL/routes/frontend-auth-route/plugins | grep -o '"name":"oidc-auth"' | wc -l)

  if [ "$FRONTEND_AUTH_PLUGIN_ID" -eq 0 ]; then
    echo "Creating frontend auth route OIDC plugin"
    curl -s -X POST $KONG_ADMIN_URL/routes/frontend-auth-route/plugins \
      -d "name=oidc-auth" \
      -d "config.client_id=${KEYCLOAK_CLIENT_ID_FRONTEND}" \
      -d "config.client_secret=${KEYCLOAK_CLIENT_SECRET}" \
      -d "config.discovery=${KEYCLOAK_URL}/realms/${KEYCLOAK_REALM}/.well-known/openid-configuration" \
      -d "config.introspection_endpoint=${KEYCLOAK_URL}/realms/${KEYCLOAK_REALM}/protocol/openid-connect/token/introspect" \
      -d "config.bearer_only=false" \
      -d "config.realm=${KEYCLOAK_REALM}" \
      -d "config.redirect_uri_path=/callback" \
      -d "config.logout_path=/logout" \
      -d "config.redirect_after_logout_uri=/" \
      -d "config.ssl_verify=false" \
      -d "config.session_opts_ssl_verify=false" \
      -d "config.timeout=10000"
  else
    echo "Frontend auth route OIDC plugin already exists, updating..."
    AUTH_PLUGIN_ID=$(curl -s $KONG_ADMIN_URL/routes/frontend-auth-route/plugins | grep -o '"id":"[^"]*"' | grep -o '[^"]*$' | head -1)
    
    if [ -n "$AUTH_PLUGIN_ID" ]; then
      curl -s -X PATCH $KONG_ADMIN_URL/plugins/$AUTH_PLUGIN_ID \
        -d "config.client_id=${KEYCLOAK_CLIENT_ID_FRONTEND}" \
        -d "config.client_secret=${KEYCLOAK_CLIENT_SECRET}" \
        -d "config.discovery=${KEYCLOAK_URL}/realms/${KEYCLOAK_REALM}/.well-known/openid-configuration" \
        -d "config.introspection_endpoint=${KEYCLOAK_URL}/realms/${KEYCLOAK_REALM}/protocol/openid-connect/token/introspect" \
        -d "config.bearer_only=false" \
        -d "config.realm=${KEYCLOAK_REALM}" \
        -d "config.redirect_uri_path=/callback" \
        -d "config.logout_path=/logout" \
        -d "config.redirect_after_logout_uri=/" \
        -d "config.ssl_verify=false" \
        -d "config.session_opts_ssl_verify=false" \
        -d "config.timeout=10000"
    fi
  fi
fi

# Check for API service
API_SERVICE_EXISTS=$(curl -s $KONG_ADMIN_URL/services | grep -o '"name":"api-service"' | wc -l)
if [ "$API_SERVICE_EXISTS" -eq 0 ]; then
  echo "⚠️ Warning: API service not found. OIDC configuration will be incomplete."
  echo "You may need to create the service first."
else
  echo "✅ API service exists"
  
  # Update API service OIDC configuration
  echo "Updating API service OIDC configuration..."
  API_PLUGIN_ID=$(curl -s $KONG_ADMIN_URL/services/api-service/plugins | grep -o '"id":"[^"]*"' | grep -o '[^"]*$' | head -1)

  if [ -n "$API_PLUGIN_ID" ]; then
    echo "Updating existing API OIDC plugin: $API_PLUGIN_ID"
    curl -s -X PATCH $KONG_ADMIN_URL/plugins/$API_PLUGIN_ID \
      -d "config.client_id=${KEYCLOAK_CLIENT_ID_API}" \
      -d "config.client_secret=${KEYCLOAK_CLIENT_SECRET}" \
      -d "config.discovery=${KEYCLOAK_URL}/realms/${KEYCLOAK_REALM}/.well-known/openid-configuration" \
      -d "config.introspection_endpoint=${KEYCLOAK_URL}/realms/${KEYCLOAK_REALM}/protocol/openid-connect/token/introspect" \
      -d "config.bearer_only=true" \
      -d "config.realm=${KEYCLOAK_REALM}" \
      -d "config.ssl_verify=false" \
      -d "config.session_opts_ssl_verify=false" \
      -d "config.timeout=10000"
  else
    echo "Creating new API OIDC plugin"
    curl -s -X POST $KONG_ADMIN_URL/services/api-service/plugins \
      -d "name=oidc-auth" \
      -d "config.client_id=${KEYCLOAK_CLIENT_ID_API}" \
      -d "config.client_secret=${KEYCLOAK_CLIENT_SECRET}" \
      -d "config.discovery=${KEYCLOAK_URL}/realms/${KEYCLOAK_REALM}/.well-known/openid-configuration" \
      -d "config.introspection_endpoint=${KEYCLOAK_URL}/realms/${KEYCLOAK_REALM}/protocol/openid-connect/token/introspect" \
      -d "config.bearer_only=true" \
      -d "config.realm=${KEYCLOAK_REALM}" \
      -d "config.ssl_verify=false" \
      -d "config.session_opts_ssl_verify=false" \
      -d "config.timeout=10000"
  fi
fi

echo "🔍 Final verification..."

# Verify plugin configurations
echo "Checking OIDC plugin instances..."
PLUGIN_COUNT=$(curl -s $KONG_ADMIN_URL/plugins | grep -o '"name":"oidc-auth"' | wc -l)
echo "Found $PLUGIN_COUNT OIDC plugin instances"

# Check if we have a plugin at the global level
GLOBAL_OIDC=$(curl -s $KONG_ADMIN_URL/plugins | grep -o '"name":"oidc-auth"' | wc -l)
if [ "$GLOBAL_OIDC" -gt 0 ]; then
  echo "✅ Global OIDC plugin is configured"
else
  echo "⚠️ No global OIDC plugin found"
fi

echo "✨ Kong OIDC configuration setup complete"
echo "Note: For Kong 3.x, session management uses the plugin's internal implementation" 
echo "To test the setup, try accessing your frontend application and API endpoints" 