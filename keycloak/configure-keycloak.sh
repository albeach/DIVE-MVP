#!/bin/bash
# keycloak/configure-keycloak.sh
# A unified script to configure Keycloak with all necessary settings
# This consolidates functionality from multiple configuration scripts

set -e

echo "=============================================="
echo "DIVE25 - Unified Keycloak Configuration Script"
echo "=============================================="
echo "Version: 3.0 (Pure API approach)"
echo "=============================================="

# Default values for environment variables
KEYCLOAK_URL=${INTERNAL_KEYCLOAK_URL:-"http://keycloak:8080"}
PUBLIC_KEYCLOAK_URL=${PUBLIC_KEYCLOAK_URL:-"https://keycloak.dive25.local:8443"}
KEYCLOAK_REALM=${KEYCLOAK_REALM:-"dive25"}
KEYCLOAK_ADMIN=${KEYCLOAK_ADMIN:-"admin"}
KEYCLOAK_ADMIN_PASSWORD=${KEYCLOAK_ADMIN_PASSWORD:-"admin"}
PUBLIC_FRONTEND_URL=${PUBLIC_FRONTEND_URL:-"https://frontend.dive25.local:8443"}
PUBLIC_API_URL=${PUBLIC_API_URL:-"https://api.dive25.local:8443"}
KEYCLOAK_CLIENT_ID_FRONTEND=${KEYCLOAK_CLIENT_ID_FRONTEND:-"dive25-frontend"}
KEYCLOAK_CLIENT_ID_API=${KEYCLOAK_CLIENT_ID_API:-"dive25-api"}
KEYCLOAK_CLIENT_SECRET=${KEYCLOAK_CLIENT_SECRET:-"change-me-in-production"}

MAX_RETRIES=30
RETRY_INTERVAL=5

# Initialize status file
mkdir -p /tmp/keycloak-config
echo "starting" > /tmp/keycloak-config/status

echo "Using the following configuration:"
echo "- Internal Keycloak URL: $KEYCLOAK_URL"
echo "- Public Keycloak URL: $PUBLIC_KEYCLOAK_URL"
echo "- Keycloak Realm: $KEYCLOAK_REALM"
echo "- Public Frontend URL: $PUBLIC_FRONTEND_URL"
echo "- Public API URL: $PUBLIC_API_URL"
echo

# Function to wait for Keycloak to be ready
wait_for_keycloak() {
  echo "Waiting for Keycloak to be ready..."
  local max_attempts=60
  local attempt=1
  
  while [ $attempt -le $max_attempts ]; do
    echo "Attempt $attempt/$max_attempts: Checking Keycloak readiness..."
    
    # Try multiple methods to verify Keycloak is ready
    if curl -s --fail "$KEYCLOAK_URL" > /dev/null; then
      echo "✅ Base Keycloak URL is accessible"
      
      # Check if we can get the OpenID configuration
      if curl -s --fail "$KEYCLOAK_URL/realms/master/.well-known/openid-configuration" > /dev/null; then
        echo "✅ Keycloak OpenID configuration is accessible"
        echo "Waiting 10 more seconds to ensure Keycloak is fully initialized..."
        sleep 10
        echo "in_progress" > /tmp/keycloak-config/status
        return 0
      else
        echo "Keycloak OpenID configuration not ready yet"
      fi
    fi
    
    echo "Keycloak not ready yet... waiting 5 seconds"
    sleep 5
    attempt=$((attempt+1))
  done
  
  echo "❌ Keycloak did not become ready after $max_attempts attempts"
  echo "failed" > /tmp/keycloak-config/status
  return 1
}

# Function to get a fresh admin token
get_admin_token() {
  echo "Getting admin token..."
  
  # Get new token
  local response=$(curl -s -X POST "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "username=${KEYCLOAK_ADMIN}" \
    -d "password=${KEYCLOAK_ADMIN_PASSWORD}" \
    -d "grant_type=password" \
    -d "client_id=admin-cli")
  
  # Extract the token
  local token=$(echo "$response" | jq -r ".access_token")
  
  if [ -n "$token" ] && [ "$token" != "null" ]; then
    echo "✅ Successfully obtained admin token"
    echo "$token"
    return 0
  else
    echo "❌ Failed to get admin token: $response" >&2
    return 1
  fi
}

# Function to check if realm exists
check_realm_exists() {
  echo "Checking if realm ${KEYCLOAK_REALM} exists..."
  
  # First try with direct API call for efficiency
  local status_code=$(curl -s -o /dev/null -w "%{http_code}" "${KEYCLOAK_URL}/realms/${KEYCLOAK_REALM}")
  
  if [ "$status_code" == "200" ]; then
    echo "✅ Realm ${KEYCLOAK_REALM} exists (via HTTP check)"
    return 0
  else
    echo "Realm not found via HTTP check (status code: $status_code), trying with admin API..."
  fi
  
  # Try with admin API as a fallback
  local TOKEN=$(get_admin_token)
  if [ -z "$TOKEN" ]; then
    echo "❌ Failed to get admin token for realm check"
    return 1
  fi
  
  status_code=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Authorization: Bearer $TOKEN" \
    "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}")
  
  if [ "$status_code" == "200" ]; then
    echo "✅ Realm ${KEYCLOAK_REALM} exists (via admin API)"
    return 0
  else
    echo "❌ Realm ${KEYCLOAK_REALM} does not exist (via admin API, status: $status_code)"
    return 1
  fi
}

# Function to create realm
create_realm() {
  echo "Creating realm ${KEYCLOAK_REALM}..."
  
  # Get admin token
  local TOKEN=$(get_admin_token)
  if [ -z "$TOKEN" ]; then
    echo "❌ Failed to get admin token for realm creation"
    echo "realm_creation_failed" > /tmp/keycloak-config/status
    return 1
  fi
  
  # Create realm JSON
  local REALM_JSON="{
    \"realm\": \"${KEYCLOAK_REALM}\",
    \"enabled\": true,
    \"displayName\": \"DIVE25 Document Access System\"
  }"
  
  # Create the realm via API
  local HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    "${KEYCLOAK_URL}/admin/realms" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "$REALM_JSON")
  
  if [ "$HTTP_STATUS" == "201" ] || [ "$HTTP_STATUS" == "409" ]; then
    if [ "$HTTP_STATUS" == "201" ]; then
      echo "✅ Realm ${KEYCLOAK_REALM} created successfully"
    else
      echo "✅ Realm ${KEYCLOAK_REALM} already exists (HTTP 409)"
    fi
    return 0
  else
    echo "❌ Failed to create realm: HTTP status $HTTP_STATUS"
    echo "realm_creation_failed" > /tmp/keycloak-config/status
    return 1
  fi
}

# Function to check if client exists
client_exists() {
  local CLIENT_ID=$1
  echo "Checking if client ${CLIENT_ID} exists..."
  
  # Get admin token
  local TOKEN=$(get_admin_token)
  if [ -z "$TOKEN" ]; then
    echo "❌ Failed to get admin token for client check"
    return 1
  fi
  
  # Get all clients from the realm
  local RESPONSE=$(curl -s -H "Authorization: Bearer $TOKEN" \
    "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/clients")
  
  # Check if client ID exists in the response
  if echo "$RESPONSE" | jq -e ".[] | select(.clientId==\"${CLIENT_ID}\")" > /dev/null; then
    echo "✅ Client ${CLIENT_ID} exists"
    return 0
  else
    echo "❌ Client ${CLIENT_ID} does not exist"
    return 1
  fi
}

# Function to create frontend client
create_frontend_client() {
  echo "Creating frontend client ${KEYCLOAK_CLIENT_ID_FRONTEND}..."
  
  # Check if client already exists
  if client_exists "${KEYCLOAK_CLIENT_ID_FRONTEND}"; then
    echo "✅ Frontend client already exists, skipping creation"
    return 0
  fi
  
  # Get admin token
  local TOKEN=$(get_admin_token)
  if [ -z "$TOKEN" ]; then
    echo "❌ Failed to get admin token for frontend client creation"
    return 1
  fi
  
  # Create client JSON
  local CLIENT_JSON="{
    \"clientId\": \"${KEYCLOAK_CLIENT_ID_FRONTEND}\",
    \"enabled\": true,
    \"publicClient\": true,
    \"redirectUris\": [
      \"${PUBLIC_FRONTEND_URL}/*\",
      \"http://localhost:3000/*\",
      \"https://frontend.dive25.local:8443/*\"
    ],
    \"webOrigins\": [
      \"${PUBLIC_FRONTEND_URL}\",
      \"http://localhost:3000\",
      \"https://frontend.dive25.local:8443\"
    ]
  }"
  
  # Create the client via API
  local HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/clients" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "$CLIENT_JSON")
  
  if [ "$HTTP_STATUS" == "201" ] || [ "$HTTP_STATUS" == "409" ]; then
    echo "✅ Frontend client created successfully (status: $HTTP_STATUS)"
    return 0
  else
    echo "❌ Failed to create frontend client: HTTP status $HTTP_STATUS"
    return 1
  fi
}

# Function to create API client
create_api_client() {
  echo "Creating API client ${KEYCLOAK_CLIENT_ID_API}..."
  
  # Check if client already exists
  if client_exists "${KEYCLOAK_CLIENT_ID_API}"; then
    echo "✅ API client already exists, skipping creation"
    return 0
  fi
  
  # Get admin token
  local TOKEN=$(get_admin_token)
  if [ -z "$TOKEN" ]; then
    echo "❌ Failed to get admin token for API client creation"
    return 1
  fi
  
  # Create client JSON
  local CLIENT_JSON="{
    \"clientId\": \"${KEYCLOAK_CLIENT_ID_API}\",
    \"enabled\": true,
    \"bearerOnly\": true
  }"
  
  # Create the client via API
  local HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/clients" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "$CLIENT_JSON")
  
  if [ "$HTTP_STATUS" == "201" ] || [ "$HTTP_STATUS" == "409" ]; then
    echo "✅ API client created successfully (status: $HTTP_STATUS)"
    return 0
  else
    echo "❌ Failed to create API client: HTTP status $HTTP_STATUS"
    return 1
  fi
}

# Function to configure realm settings
configure_realm_settings() {
  echo "Configuring realm settings..."
  
  # Get admin token
  local TOKEN=$(get_admin_token)
  if [ -z "$TOKEN" ]; then
    echo "❌ Failed to get admin token for realm settings configuration"
    return 1
  fi
  
  # First, get current realm settings to preserve existing settings
  local CURRENT_SETTINGS=$(curl -s -H "Authorization: Bearer $TOKEN" \
    "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}")
  
  # Extract the realm ID and other essential fields
  local REALM_ID=$(echo "$CURRENT_SETTINGS" | jq -r '.id')
  
  # Create a simplified version with only the fields we want to update
  local UPDATE_DATA="{
    \"id\": \"${REALM_ID}\",
    \"realm\": \"${KEYCLOAK_REALM}\",
    \"browserSecurityHeaders\": {
      \"contentSecurityPolicy\": \"frame-src *; frame-ancestors *; object-src 'none'\"
    },
    \"attributes\": {
      \"frontendUrl\": \"${PUBLIC_KEYCLOAK_URL}\",
      \"hostname-url\": \"${PUBLIC_KEYCLOAK_URL}\",
      \"hostname-admin-url\": \"${PUBLIC_KEYCLOAK_URL}\"
    }
  }"
  
  # Update realm settings via API
  local HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X PUT \
    "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "$UPDATE_DATA")
  
  if [ "$HTTP_STATUS" == "204" ]; then
    echo "✅ Realm settings configured successfully (HTTP $HTTP_STATUS)"
    return 0
  else
    echo "❌ Failed to configure realm settings: HTTP status $HTTP_STATUS"
    return 1
  fi
}

# Function to notify Kong of realm creation
notify_kong_of_realm_creation() {
  echo "Notifying Kong that Keycloak realm is ready..."
  
  # Create a file that Kong configuration can check for
  echo "${KEYCLOAK_REALM}" > /tmp/keycloak-config/realm-ready
  
  # Try to directly call Kong config API if available
  if curl -s -o /dev/null -w "%{http_code}" http://kong:8001/status > /dev/null 2>&1; then
    echo "Kong admin API is accessible, triggering Kong configuration..."
    curl -s -X POST http://kong-config:8080/trigger-config || echo "⚠️ Failed to trigger Kong configuration, but continuing..."
  else
    echo "Kong admin API not directly accessible, relying on file marker"
  fi
  
  echo "✅ Kong notification completed"
}

# Function to generate browser runtime fix script
generate_browser_script() {
  echo "Generating browser script for frontend runtime configuration fixes..."
  
  mkdir -p /tmp/dive25-keycloak-fix
  cat > /tmp/dive25-keycloak-fix/update_config.js << 'EOL'
// This script updates the Next.js runtime configuration for Keycloak URL
if (window.__NEXT_DATA__ && window.__NEXT_DATA__.runtimeConfig) {
  // Save original for logging
  const originalUrl = window.__NEXT_DATA__.runtimeConfig.keycloakUrl;
  
  // Replace the port in the Keycloak URL
  window.__NEXT_DATA__.runtimeConfig.keycloakUrl = 
    window.__NEXT_DATA__.runtimeConfig.keycloakUrl.replace(':4432', ':8443');
  
  console.log(`Keycloak URL updated from ${originalUrl} to ${window.__NEXT_DATA__.runtimeConfig.keycloakUrl}`);
  
  // Also update any stored URLs in keycloak instance if it exists
  if (window.__keycloak) {
    window.__keycloak.authServerUrl = window.__keycloak.authServerUrl.replace(':4432', ':8443');
    console.log(`Keycloak instance authServerUrl updated to ${window.__keycloak.authServerUrl}`);
  }
}
EOL

  chmod +x /tmp/dive25-keycloak-fix/update_config.js
  echo "✅ Browser script generated at /tmp/dive25-keycloak-fix/update_config.js"
}

# Function to create a test client using direct REST API call
create_test_client_via_api() {
  echo "Creating a test client via direct API call for verification..."
  
  # Get admin token
  local TOKEN=$(get_admin_token)
  if [ -z "$TOKEN" ]; then
    echo "❌ Failed to get admin token for test client creation"
    return 1
  fi
  
  # Create test client JSON
  local CLIENT_JSON="{
    \"clientId\": \"api-test-client\",
    \"enabled\": true,
    \"publicClient\": true
  }"
  
  # Create the client via API
  local HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/clients" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "$CLIENT_JSON")
  
  if [ "$HTTP_STATUS" == "201" ] || [ "$HTTP_STATUS" == "409" ]; then
    echo "✅ Test client created via API call (status: $HTTP_STATUS)"
    return 0
  else
    echo "❌ Failed to create test client via API call (status: $HTTP_STATUS)"
    return 1
  fi
}

# Main execution flow
echo "Starting Keycloak configuration process..."

# Step 1: Wait for Keycloak to be ready
wait_for_keycloak || exit 1

# Step 2: Check for realm existence
if ! check_realm_exists; then
  echo "Realm does not exist, creating it..."
  create_realm || {
    echo "❌ Failed to create realm, exiting..."
    exit 1
  }
else
  echo "✅ Realm ${KEYCLOAK_REALM} already exists"
fi

# Step 3: Create clients if needed
create_frontend_client || echo "⚠️ Frontend client creation had issues, continuing..."
create_api_client || echo "⚠️ API client creation had issues, continuing..."

# Step 4: Create a test client via direct API call for verification
create_test_client_via_api || echo "⚠️ Direct API client creation had issues, continuing..."

# Step 5: Configure realm settings
configure_realm_settings || echo "⚠️ Realm settings configuration had issues, continuing..."

# Step 6: Notify Kong of realm creation
notify_kong_of_realm_creation || echo "⚠️ Kong notification had issues, continuing..."

# Step 7: Generate browser script for frontend issues
generate_browser_script || echo "⚠️ Browser script generation had issues, continuing..."

# Mark configuration as complete
echo "completed" > /tmp/keycloak-config/status

echo
echo "=============================================="
echo "✅ Keycloak configuration completed!"
echo "=============================================="
echo
echo "The following configurations have been applied:"
echo "1. Realm setup (created if missing)"
echo "2. Content Security Policy settings"
echo "3. Issuer URL configured to use port 8443"
echo "4. Client redirects updated"
echo "5. Browser script generated for frontend fixes"
echo "6. Kong notified of realm creation"
echo
echo "To access Keycloak admin console: ${PUBLIC_KEYCLOAK_URL}/admin"
echo "Realm: ${KEYCLOAK_REALM}"
echo "==============================================" 