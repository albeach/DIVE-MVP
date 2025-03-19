#!/bin/bash
# keycloak/configure-keycloak-unified.sh
# A unified script to configure Keycloak with all necessary settings
# This consolidates functionality from multiple configuration scripts

set -e

echo "=============================================="
echo "DIVE25 - Unified Keycloak Configuration Script"
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
KEYCLOAK_CONTAINER=${KEYCLOAK_CONTAINER:-"dive25-keycloak"}

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
  local max_attempts=30
  local attempt=1
  
  while [ $attempt -le $max_attempts ]; do
    if curl -s --fail "$KEYCLOAK_URL" > /dev/null; then
      echo "✅ Keycloak is ready!"
      return 0
    fi
    echo "Attempt $attempt/$max_attempts: Keycloak not ready yet... waiting 5 seconds"
    sleep 5
    attempt=$((attempt+1))
  done
  
  echo "❌ Keycloak did not become ready after $max_attempts attempts"
  return 1
}

# Function to get admin token
get_admin_token() {
  echo "Getting admin token..."
  local token=$(curl -s -X POST "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "username=${KEYCLOAK_ADMIN}" \
    -d "password=${KEYCLOAK_ADMIN_PASSWORD}" \
    -d "grant_type=password" \
    -d "client_id=admin-cli" | grep -o '"access_token":"[^"]*"' | cut -d':' -f2 | tr -d '"')
    
  if [ -z "$token" ]; then
    echo "❌ Failed to get admin token"
    return 1
  fi
  
  echo "✅ Admin token acquired"
  echo "$token"
}

# Function to check if realm exists
check_realm_exists() {
  local token=$1
  local status_code=$(curl -s -o /dev/null -w "%{http_code}" \
    -X GET "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}" \
    -H "Authorization: Bearer $token")
    
  if [ "$status_code" = "200" ]; then
    echo "✅ Realm ${KEYCLOAK_REALM} exists"
    return 0
  else
    echo "❌ Realm ${KEYCLOAK_REALM} does not exist"
    return 1
  fi
}

# Function to create realm from JSON
create_realm_from_json() {
  local token=$1
  local realm_file=${2:-"./realm-export.json"}
  
  echo "Creating realm from $realm_file..."
  
  if [ ! -f "$realm_file" ]; then
    echo "❌ Realm export file not found at $realm_file"
    return 1
  fi
  
  local response=$(curl -s -X POST "${KEYCLOAK_URL}/admin/realms" \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: application/json" \
    --data-binary @"$realm_file")
    
  if [ -z "$response" ]; then
    echo "✅ Realm created successfully"
    return 0
  else
    echo "❌ Failed to create realm: $response"
    return 1
  fi
}

# Function to configure Content Security Policy
configure_csp() {
  local token=$1
  
  echo "Configuring Content Security Policy for realm ${KEYCLOAK_REALM}..."
  
  # Update master realm to use minimal CSP settings
  echo "Updating master realm security headers..."
  local master_response=$(curl -s -X PUT "${KEYCLOAK_URL}/admin/realms/master" \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: application/json" \
    -d '{
      "browserSecurityHeaders": {
        "contentSecurityPolicy": "frame-src *; frame-ancestors *; object-src '\''none'\''"
      }
    }')
  
  # Update dive25 realm to use minimal CSP settings
  echo "Updating ${KEYCLOAK_REALM} realm security headers..."
  local dive25_response=$(curl -s -X PUT "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}" \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: application/json" \
    -d '{
      "browserSecurityHeaders": {
        "contentSecurityPolicy": "frame-src *; frame-ancestors *; object-src '\''none'\''"
      }
    }')
    
  echo "✅ CSP settings have been updated successfully"
}

# Function to update issuer URL
update_issuer_url() {
  local token=$1
  
  echo "Updating issuer URL for realm ${KEYCLOAK_REALM}..."
  
  # Force the issuer URL to use port 8443
  curl -s -X PUT "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}" \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: application/json" \
    -d "{
      \"attributes\": {
        \"frontendUrl\": \"${PUBLIC_KEYCLOAK_URL}\",
        \"hostname-url\": \"${PUBLIC_KEYCLOAK_URL}\",
        \"hostname-admin-url\": \"${PUBLIC_KEYCLOAK_URL}\"
      }
    }"
    
  echo "✅ Issuer URL updated to ${PUBLIC_KEYCLOAK_URL}"
}

# Function to configure clients
configure_clients() {
  local token=$1
  
  echo "Configuring clients for realm ${KEYCLOAK_REALM}..."
  
  # Get frontend client ID
  local frontend_id=$(curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/clients" \
    -H "Authorization: Bearer $token" | grep -o "\"id\":\"[^\"]*\",\"clientId\":\"${KEYCLOAK_CLIENT_ID_FRONTEND}\"" | cut -d'"' -f4)
    
  if [ -z "$frontend_id" ]; then
    echo "❌ Frontend client not found"
  else
    echo "Updating frontend client configuration..."
    # Update frontend client redirects
    curl -s -X PUT "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/clients/${frontend_id}" \
      -H "Authorization: Bearer $token" \
      -H "Content-Type: application/json" \
      -d "{
        \"clientId\": \"${KEYCLOAK_CLIENT_ID_FRONTEND}\",
        \"redirectUris\": [
          \"${PUBLIC_FRONTEND_URL}/*\",
          \"https://frontend.dive25.local:8443/*\",
          \"https://dive25.local:8443/*\"
        ],
        \"webOrigins\": [
          \"${PUBLIC_FRONTEND_URL}\",
          \"https://frontend.dive25.local:8443\",
          \"https://dive25.local:8443\"
        ]
      }"
    echo "✅ Frontend client updated"
  fi
  
  # Get API client ID
  local api_id=$(curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/clients" \
    -H "Authorization: Bearer $token" | grep -o "\"id\":\"[^\"]*\",\"clientId\":\"${KEYCLOAK_CLIENT_ID_API}\"" | cut -d'"' -f4)
    
  if [ -z "$api_id" ]; then
    echo "❌ API client not found"
  else
    echo "Updating API client configuration..."
    # Update API client redirects
    curl -s -X PUT "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/clients/${api_id}" \
      -H "Authorization: Bearer $token" \
      -H "Content-Type: application/json" \
      -d "{
        \"clientId\": \"${KEYCLOAK_CLIENT_ID_API}\",
        \"redirectUris\": [
          \"${PUBLIC_API_URL}/*\",
          \"https://api.dive25.local:8443/*\"
        ],
        \"webOrigins\": [
          \"${PUBLIC_API_URL}\",
          \"https://api.dive25.local:8443\"
        ]
      }"
    echo "✅ API client updated"
  fi
}

# Function to update URL in environment files
update_environment_files() {
  echo "Checking for environment files to update..."
  
  # Update .env file if it exists in the project root
  if [ -f "/.env" ]; then
    echo "Updating Keycloak port in /.env"
    sed -i 's/KEYCLOAK_PORT=4432/KEYCLOAK_PORT=8443/g' /.env
    echo "✅ Updated Keycloak port in /.env"
  elif [ -f "/app/.env" ]; then
    echo "Updating Keycloak port in /app/.env"
    sed -i 's/KEYCLOAK_PORT=4432/KEYCLOAK_PORT=8443/g' /app/.env
    echo "✅ Updated Keycloak port in /app/.env"
  else
    echo "⚠️ No .env file found to update"
  fi
  
  # Update docker-compose.yml if it exists
  if [ -f "/docker-compose.yml" ]; then
    echo "Updating Keycloak port mapping in /docker-compose.yml"
    sed -i 's/- "${KEYCLOAK_PORT}:8443"/- "8443:8443"/g' /docker-compose.yml
    echo "✅ Updated port mapping in /docker-compose.yml"
  elif [ -f "/app/docker-compose.yml" ]; then
    echo "Updating Keycloak port mapping in /app/docker-compose.yml"
    sed -i 's/- "${KEYCLOAK_PORT}:8443"/- "8443:8443"/g' /app/docker-compose.yml
    echo "✅ Updated port mapping in /app/docker-compose.yml"
  else
    echo "⚠️ No docker-compose.yml file found to update"
  fi
  
  echo "Updating PUBLIC_KEYCLOAK_URL to use port 8443"
  if grep -q "PUBLIC_KEYCLOAK_URL=" /.env 2>/dev/null; then
    sed -i 's|PUBLIC_KEYCLOAK_URL=.*|PUBLIC_KEYCLOAK_URL=https://keycloak.dive25.local:8443|g' /.env
    echo "✅ Updated PUBLIC_KEYCLOAK_URL in /.env"
  elif grep -q "PUBLIC_KEYCLOAK_URL=" /app/.env 2>/dev/null; then
    sed -i 's|PUBLIC_KEYCLOAK_URL=.*|PUBLIC_KEYCLOAK_URL=https://keycloak.dive25.local:8443|g' /app/.env
    echo "✅ Updated PUBLIC_KEYCLOAK_URL in /app/.env"
  fi
  
  echo "Updating PUBLIC_KEYCLOAK_AUTH_URL to use port 8443"
  if grep -q "PUBLIC_KEYCLOAK_AUTH_URL=" /.env 2>/dev/null; then
    sed -i 's|PUBLIC_KEYCLOAK_AUTH_URL=.*|PUBLIC_KEYCLOAK_AUTH_URL=https://keycloak.dive25.local:8443/auth|g' /.env
    echo "✅ Updated PUBLIC_KEYCLOAK_AUTH_URL in /.env"
  elif grep -q "PUBLIC_KEYCLOAK_AUTH_URL=" /app/.env 2>/dev/null; then
    sed -i 's|PUBLIC_KEYCLOAK_AUTH_URL=.*|PUBLIC_KEYCLOAK_AUTH_URL=https://keycloak.dive25.local:8443/auth|g' /app/.env
    echo "✅ Updated PUBLIC_KEYCLOAK_AUTH_URL in /app/.env"
  fi
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
  echo "For frontend issues, developers can use this script in browser console:"
  echo "---------------------------------------------------------"
  cat /tmp/dive25-keycloak-fix/update_config.js
  echo "---------------------------------------------------------"
}

# Function to create test users
create_test_users() {
  local token=$1
  local users_file="./test-users/sample-users.json"
  
  echo "Creating test users from $users_file..."
  
  if [ ! -f "$users_file" ]; then
    echo "❌ Users file not found at $users_file"
    return 1
  fi
  
  # Read the users file line by line and create each user
  while IFS= read -r user; do
    if [ ! -z "$user" ]; then
      echo "Creating user from data: $user"
      curl -s -X POST "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/users" \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json" \
        -d "$user"
    fi
  done < <(jq -c '.[]' "$users_file")
  
  echo "✅ Test users created successfully"
}

# Main execution flow
echo "Starting Keycloak configuration process..."

# Step 1: Wait for Keycloak to be ready
wait_for_keycloak || exit 1

# Step 2: Get admin token
ADMIN_TOKEN=$(get_admin_token)
if [ -z "$ADMIN_TOKEN" ]; then
  exit 1
fi

# Step 3: Check if realm exists, create if it doesn't
if ! check_realm_exists "$ADMIN_TOKEN"; then
  create_realm_from_json "$ADMIN_TOKEN" "./realm-export.json" || exit 1
  echo "✅ Realm creation completed"
fi

# Step 4: Configure Content Security Policy
configure_csp "$ADMIN_TOKEN" || echo "Warning: CSP configuration had issues"

# Step 5: Update issuer URL
update_issuer_url "$ADMIN_TOKEN" || echo "Warning: Issuer URL update had issues"

# Step 6: Configure clients
configure_clients "$ADMIN_TOKEN" || echo "Warning: Client configuration had issues"

# Step 7: Create test users
create_test_users "$ADMIN_TOKEN" || echo "Warning: Test users creation had issues"

# Step 8: Update environment files if running in project directory
update_environment_files || echo "Warning: Environment files update had issues"

# Step 9: Generate browser script for frontend issues
generate_browser_script || echo "Warning: Browser script generation had issues"

echo
echo "=============================================="
echo "✅ Keycloak configuration completed successfully!"
echo "=============================================="
echo
echo "The following configurations have been applied:"
echo "1. Realm setup (created if missing)"
echo "2. Content Security Policy settings"
echo "3. Issuer URL configured to use port 8443"
echo "4. Client redirects updated"
echo "5. Test users created"
echo "6. Environment files updated (if accessible)"
echo "7. Browser script generated for frontend fixes"
echo
echo "To access Keycloak admin console: ${PUBLIC_KEYCLOAK_URL}/admin"
echo "Realm: ${KEYCLOAK_REALM}"
echo "==============================================" 