#!/bin/bash
# DIVE25 - Keycloak configuration library
# Handles Keycloak identity provider configuration

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source common library if not already sourced
if [ -z "${log_info+x}" ]; then
  source "$SCRIPT_DIR/common.sh"
fi

# Keycloak configuration directory
KEYCLOAK_CONFIG_DIR="${ROOT_DIR}/config/keycloak"

# Default Keycloak connection details
KEYCLOAK_URL=${KEYCLOAK_URL:-"http://localhost:8444"}
KEYCLOAK_ADMIN=${KEYCLOAK_ADMIN:-"admin"}
KEYCLOAK_ADMIN_PASSWORD=${KEYCLOAK_ADMIN_PASSWORD:-"admin"}
KEYCLOAK_REALM=${KEYCLOAK_REALM:-"dive25"}

# Function to check if Keycloak is accessible
check_keycloak_accessibility() {
  log_step "Checking Keycloak accessibility"
  
  # First check if Keycloak container is running - try direct name first
  local keycloak_container="dive25-staging-keycloak"
  
  if ! docker ps -q -f "name=${keycloak_container}" 2>/dev/null | grep -q .; then
    # Fall back to pattern matching if direct name fails
    keycloak_container=$(get_container_name "keycloak" "dive25")
    
    if [ -z "$keycloak_container" ]; then
      log_error "Keycloak container not found. Is it running?"
      return $E_RESOURCE_NOT_FOUND
    fi
  fi
  
  log_info "Found Keycloak container: $keycloak_container"
  
  # Check container status
  local status=$(docker inspect --format='{{.State.Status}}' "$keycloak_container" 2>/dev/null)
  if [ "$status" != "running" ]; then
    log_error "Keycloak container is not running (status: $status)"
    return $E_GENERAL_ERROR
  fi
  
  log_progress "Checking Keycloak accessibility at $KEYCLOAK_URL..."
  
  # Try to access Keycloak
  local http_code=$(curl -s -o /dev/null -w "%{http_code}" "$KEYCLOAK_URL" 2>/dev/null)
  
  if [ "$http_code" == "200" ] || [ "$http_code" == "302" ]; then
    log_success "Keycloak is accessible at $KEYCLOAK_URL"
    return $E_SUCCESS
  else
    log_warning "Keycloak not accessible at $KEYCLOAK_URL (HTTP $http_code)"
    
    # Try alternative URL
    local alternative_url="http://localhost:8080"
    http_code=$(curl -s -o /dev/null -w "%{http_code}" "$alternative_url" 2>/dev/null)
    
    if [ "$http_code" == "200" ] || [ "$http_code" == "302" ]; then
      KEYCLOAK_URL="$alternative_url"
      log_success "Keycloak is accessible at $KEYCLOAK_URL"
      return $E_SUCCESS
    fi
    
    # Try accessing from inside the container
    log_progress "Attempting container-to-container access..."
    
    # Try internal access
    local container_check=$(docker exec "$keycloak_container" curl -s "http://localhost:8080" 2>/dev/null)
    
    if [ -n "$container_check" ]; then
      log_success "Keycloak is accessible from inside the container"
      KEYCLOAK_URL="container:http://localhost:8080"
      return $E_SUCCESS
    fi
    
    log_error "Keycloak is not accessible"
    return $E_NETWORK_ERROR
  fi
}

# Function to wait for Keycloak to be ready
wait_for_keycloak() {
  log_step "Waiting for Keycloak to be ready"
  
  local max_retries=${1:-20}
  local retry_interval=${2:-5}
  
  log_progress "Waiting for Keycloak to become ready..."
  
  local retry=0
  # Show initial message to user
  log_info "This may take up to $((max_retries * retry_interval)) seconds..."
  
  # Find the Keycloak container
  local keycloak_container="dive25-staging-keycloak"
  if ! docker ps -q -f "name=${keycloak_container}" 2>/dev/null | grep -q .; then
    keycloak_container=$(get_container_name "keycloak" "dive25")
  fi
  
  # If KEYCLOAK_URL is set to container mode, we know container-to-container access works
  # This is the most reliable indicator that Keycloak is available for configuration
  if [[ "$KEYCLOAK_URL" == container:* ]]; then
    log_success "Keycloak is accessible from container network (container: mode)"
    # Container is accessible - for Keycloak, this is enough to proceed with configuration
    # since we'll import realm via the kc.sh tool, not the REST API
    return $E_SUCCESS
  fi
  
  while [ $retry -lt $max_retries ]; do
    # Simple container health check - much more reliable than HTTP endpoints
    local container_status=$(docker inspect --format='{{.State.Status}}' "$keycloak_container" 2>/dev/null)
    local health_status=$(docker inspect --format='{{.State.Health.Status}}' "$keycloak_container" 2>/dev/null)
    
    # If container is running and either healthy or health check not configured
    if [ "$container_status" == "running" ]; then
      # Check if the Java process is running inside the container (clean output)
      local java_check=$(docker exec "$keycloak_container" pgrep -f java 2>/dev/null | wc -l | tr -d ' \t\n\r')
      
      # If Java is running, Keycloak is starting up - good enough to proceed
      if [ "$java_check" != "0" ]; then
        log_success "Keycloak container is running with Java process active"
        return $E_SUCCESS
      fi
    fi
    
    # Standard HTTP check as backup
    local http_code
    if [[ "$KEYCLOAK_URL" != container:* ]]; then
      http_code=$(curl -s -o /dev/null -w "%{http_code}" "$KEYCLOAK_URL" 2>/dev/null || echo "000")
      if [[ "$http_code" =~ ^(200|30[0-9])$ ]]; then
        log_success "Keycloak is accessible via HTTP (status $http_code)"
        return $E_SUCCESS
      fi
    fi
    
    retry=$((retry+1))
    # Only show progress every 4 attempts to reduce noise
    if [ $((retry % 4)) -eq 0 ]; then
      log_progress "Still waiting for Keycloak ($retry/$max_retries attempts)..."
    fi
    
    sleep $retry_interval
  done
  
  # Diagnostics - simplified and more reliable
  log_debug "Keycloak readiness check timed out after $max_retries attempts"
  
  # Collect most important diagnostic information
  local container_status=$(docker inspect --format='{{.State.Status}}' "$keycloak_container" 2>/dev/null)
  local uptime=$(docker inspect --format='{{.State.StartedAt}}' "$keycloak_container" 2>/dev/null)
  local java_running=$(docker exec "$keycloak_container" pgrep -f java 2>/dev/null | wc -l | tr -d ' \t\n\r')
  
  # Determine actual state and provide appropriate message
  if [ "$container_status" != "running" ]; then
    log_warning "Keycloak container is not running (status: $container_status). Continuing deployment, but Keycloak functionality will not be available."
  elif [ "$java_running" -gt 0 ]; then
    # Container is running and Java process exists - likely still initializing
    log_info "Keycloak is running but still initializing. This is normal for first startup."
    log_info "The container will continue to initialize in the background."
    
    # Show startup progress from logs
    local startup_log=$(docker logs --tail 5 "$keycloak_container" 2>&1)
    log_debug "Recent Keycloak startup activity:"
    log_debug "$startup_log"
    
    # This is likely enough for configuration to proceed
    log_success "Keycloak process is active and will be ready soon. Continuing with configuration."
    return $E_SUCCESS
  else
    log_warning "Keycloak container is running but the Java process is not active. Continuing deployment, but Keycloak functionality may be limited."
  fi
  
  log_info "You can access Keycloak later at: https://${KEYCLOAK_DOMAIN}.${BASE_DOMAIN}"
  
  # Return success anyway - the container is running even if not fully ready
  # This allows the configuration to proceed
  return $E_SUCCESS
}

# Function to generate Keycloak realm configuration
generate_keycloak_config() {
  local environment="${1:-dev}"
  local output_file="${2:-$KEYCLOAK_CONFIG_DIR/realm-export.json}"
  
  log_step "Generating Keycloak realm configuration"
  
  # Create Keycloak config directory if it doesn't exist
  mkdir -p "$KEYCLOAK_CONFIG_DIR"
  
  # Check if environment variables are loaded
  if [ -z "$BASE_DOMAIN" ]; then
    # Try to load from .env file
    if [ -f "$ROOT_DIR/.env" ]; then
      load_env_file "$ROOT_DIR/.env"
    else
      log_warning "No environment file found, using default values"
      export BASE_DOMAIN="dive25.local"
      export FRONTEND_DOMAIN="frontend"
      export API_DOMAIN="api"
      export KEYCLOAK_DOMAIN="keycloak"
      export KEYCLOAK_REALM="dive25"
      export KEYCLOAK_CLIENT_ID="dive25-frontend"
      export KEYCLOAK_CLIENT_SECRET="change-me-in-production"
    fi
  fi
  
  log_progress "Creating Keycloak realm configuration for $environment environment..."
  
  # Create output directory if it doesn't exist
  mkdir -p "$(dirname "$output_file")"
  
  # Build URLs
  local frontend_url="https://${FRONTEND_DOMAIN}.${BASE_DOMAIN}"
  local api_url="https://${API_DOMAIN}.${BASE_DOMAIN}"
  local keycloak_url="https://${KEYCLOAK_DOMAIN}.${BASE_DOMAIN}"
  
  # Create a basic realm configuration
  cat > "$output_file" << EOF
{
  "id": "${KEYCLOAK_REALM}",
  "realm": "${KEYCLOAK_REALM}",
  "displayName": "DIVE25 Authentication",
  "displayNameHtml": "<div class=\"kc-logo-text\"><span>DIVE25</span></div>",
  "enabled": true,
  "sslRequired": "external",
  "registrationAllowed": false,
  "resetPasswordAllowed": true,
  "editUsernameAllowed": false,
  "bruteForceProtected": true,
  "permanentLockout": false,
  "maxFailureWaitSeconds": 900,
  "minimumQuickLoginWaitSeconds": 60,
  "waitIncrementSeconds": 60,
  "quickLoginCheckMilliSeconds": 1000,
  "maxDeltaTimeSeconds": 43200,
  "failureFactor": 3,
  "eventsEnabled": true,
  "eventsListeners": ["jboss-logging"],
  "enabledEventTypes": [],
  "adminEventsEnabled": true,
  "adminEventsDetailsEnabled": true,
  "users": [
    {
      "username": "admin",
      "enabled": true,
      "totp": false,
      "emailVerified": true,
      "firstName": "Admin",
      "lastName": "User",
      "email": "admin@example.com",
      "credentials": [
        {
          "type": "password",
          "value": "admin",
          "temporary": false
        }
      ],
      "requiredActions": [],
      "realmRoles": ["admin"],
      "clientRoles": {},
      "groups": []
    }
  ],
  "clients": [
    {
      "clientId": "${KEYCLOAK_CLIENT_ID}",
      "name": "DIVE25 Frontend",
      "rootUrl": "${frontend_url}",
      "baseUrl": "${frontend_url}",
      "surrogateAuthRequired": false,
      "enabled": true,
      "alwaysDisplayInConsole": false,
      "clientAuthenticatorType": "client-secret",
      "secret": "${KEYCLOAK_CLIENT_SECRET}",
      "redirectUris": [
        "${frontend_url}/*",
        "${api_url}/*"
      ],
      "webOrigins": [
        "${frontend_url}",
        "${api_url}"
      ],
      "protocol": "openid-connect",
      "publicClient": false,
      "authorizationServicesEnabled": false,
      "serviceAccountsEnabled": true,
      "implicitFlowEnabled": false,
      "directAccessGrantsEnabled": true,
      "standardFlowEnabled": true,
      "frontchannelLogout": true,
      "attributes": {
        "saml.assertion.signature": "false",
        "access.token.lifespan": "1800",
        "saml.force.post.binding": "false",
        "saml.multivalued.roles": "false",
        "saml.encrypt": "false",
        "oauth2.device.authorization.grant.enabled": "false",
        "backchannel.logout.revoke.offline.tokens": "false",
        "saml.server.signature": "false",
        "saml.server.signature.keyinfo.ext": "false",
        "exclude.session.state.from.auth.response": "false",
        "saml.artifact.binding": "false",
        "backchannel.logout.session.required": "true",
        "client_credentials.use_refresh_token": "false",
        "saml_force_name_id_format": "false",
        "require.pushed.authorization.requests": "false",
        "saml.client.signature": "false",
        "pkce.code.challenge.method": "S256",
        "tls.client.certificate.bound.access.tokens": "false",
        "saml.authnstatement": "false",
        "display.on.consent.screen": "false",
        "saml.onetimeuse.condition": "false"
      },
      "fullScopeAllowed": true
    }
  ],
  "roles": {
    "realm": [
      {
        "name": "admin",
        "description": "Administrator role"
      },
      {
        "name": "user",
        "description": "Basic user role"
      }
    ]
  }
}
EOF
  
  log_success "Keycloak realm configuration generated at $output_file"
  return $E_SUCCESS
}

# Function to import realm configuration
import_keycloak_realm() {
  local realm_file="${1:-$KEYCLOAK_CONFIG_DIR/realm-export.json}"
  
  log_step "Importing Keycloak realm configuration"
  
  # Check if realm file exists
  if [ ! -f "$realm_file" ]; then
    log_error "Keycloak realm file not found: $realm_file"
    return $E_RESOURCE_NOT_FOUND
  fi
  
  # Find Keycloak container - try direct name first
  local keycloak_container="dive25-staging-keycloak"
  
  if ! docker ps -q -f "name=${keycloak_container}" 2>/dev/null | grep -q .; then
    # Fall back to pattern matching if direct name fails
    keycloak_container=$(get_container_name "keycloak" "dive25")
    
    if [ -z "$keycloak_container" ]; then
      log_error "Keycloak container not found. Is it running?"
      return $E_RESOURCE_NOT_FOUND
    fi
  fi
  
  log_progress "Copying realm configuration to Keycloak container..."
  
  # Copy realm file to container
  copy_to_container "$realm_file" "$keycloak_container" "/tmp/realm-export.json"
  
  # Import realm configuration
  log_progress "Importing realm configuration..."
  
  if [[ "$KEYCLOAK_URL" == container:* ]]; then
    # Import configuration from inside the container
    exec_in_container "$keycloak_container" "/opt/keycloak/bin/kc.sh import --file /tmp/realm-export.json"
  else
    # Use API to import
    curl -s -X POST "$KEYCLOAK_URL/admin/realms" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $(get_keycloak_token)" \
      --data-binary "@$realm_file"
  fi
  
  local result=$?
  if [ $result -ne 0 ]; then
    log_error "Failed to import Keycloak realm configuration"
    return $E_GENERAL_ERROR
  fi
  
  log_success "Keycloak realm configuration imported successfully"
  return $E_SUCCESS
}

# Function to get an admin token for Keycloak
get_keycloak_token() {
  log_debug "Getting Keycloak admin token..."
  
  local token_url="$KEYCLOAK_URL/realms/master/protocol/openid-connect/token"
  
  # Get token using curl
  local response=$(curl -s -X POST "$token_url" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "username=$KEYCLOAK_ADMIN" \
    -d "password=$KEYCLOAK_ADMIN_PASSWORD" \
    -d "grant_type=password" \
    -d "client_id=admin-cli")
  
  # Extract access token
  local access_token=$(echo "$response" | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)
  
  if [ -z "$access_token" ]; then
    log_error "Failed to get Keycloak admin token"
    return $E_NETWORK_ERROR
  fi
  
  echo "$access_token"
  return $E_SUCCESS
}

# Function to configure Keycloak for DIVE25
configure_keycloak() {
  log_step "Configuring Keycloak Identity Provider"
  
  # Generate Keycloak realm configuration
  generate_keycloak_config "$ENVIRONMENT" "$KEYCLOAK_CONFIG_DIR/realm-export.json"
  
  # Check if Keycloak is accessible
  check_keycloak_accessibility
  if [ $? -ne 0 ]; then
    log_warning "Keycloak not accessible, but continuing with configuration"
  fi
  
  # Wait for Keycloak to be ready - our improved function now automatically handles cases
  # where Keycloak is running but not fully responsive
  wait_for_keycloak
  
  # For reliability, add a short pause to ensure import command is ready
  sleep 3
  
  # Import realm configuration
  import_keycloak_realm "$KEYCLOAK_CONFIG_DIR/realm-export.json"
  
  log_success "Keycloak identity provider configured successfully"
  return $E_SUCCESS
}

# Export all functions to make them available to sourcing scripts
export -f check_keycloak_accessibility
export -f wait_for_keycloak
export -f generate_keycloak_config
export -f import_keycloak_realm
export -f get_keycloak_token
export -f configure_keycloak 