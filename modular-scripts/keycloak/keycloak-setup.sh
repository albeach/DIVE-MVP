#!/bin/bash
# Keycloak configuration functions

# Import required utility functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/logging.sh"
source "$SCRIPT_DIR/../utils/system.sh"
source "$SCRIPT_DIR/../utils/config.sh"

# Check and wait for Keycloak readiness
wait_for_keycloak() {
  print_step "Waiting for Keycloak"
  
  # Get variables from environment or defaults
  local internal_keycloak_url=${INTERNAL_KEYCLOAK_URL:-"http://keycloak:8080"}
  local keycloak_realm=${KEYCLOAK_REALM:-"dive25"}
  local max_retries=${1:-20}
  local retry_interval=${2:-5}
  
  show_progress "Checking if Keycloak is ready..."
  
  # First check the marker file
  if [ -f "/tmp/keycloak-config/realm-ready" ]; then
    success "Found realm marker file"
    return 0
  fi
  
  # Then try direct check with Keycloak
  local retry=0
  while [ $retry -lt $max_retries ]; do
    local status_code=$(curl -s -o /dev/null -w "%{http_code}" "${internal_keycloak_url}/realms/${keycloak_realm}")
    
    if [ "$status_code" == "200" ]; then
      success "Keycloak realm ${keycloak_realm} is accessible"
      # Create marker file for future reference
      mkdir -p /tmp/keycloak-config
      echo "${keycloak_realm}" > /tmp/keycloak-config/realm-ready
      return 0
    fi
    
    retry=$((retry+1))
    echo "Attempt $retry/$max_retries: Keycloak realm not ready yet, waiting $retry_interval seconds..."
    sleep $retry_interval
  done
  
  warning "Could not verify Keycloak realm readiness after $max_retries attempts"
  return 1
}

# Function to fix identity providers in Keycloak
fix_identity_providers() {
  print_step "Fixing Identity Providers"
  
  show_progress "Updating Keycloak identity provider configurations..."
  
  # Get Keycloak container
  local keycloak_container=$(docker ps --format '{{.Names}}' | grep -E 'keycloak' | grep -v "config" | head -n 1)
  
  if [ -z "$keycloak_container" ]; then
    warning "Keycloak container not found. Cannot fix identity providers."
    return 1
  fi
  
  # Configure Keycloak CLI
  echo "Authenticating with Keycloak admin CLI..."
  if ! docker exec $keycloak_container /opt/keycloak/bin/kcadm.sh config credentials \
    --server http://localhost:8080 \
    --realm master \
    --user admin \
    --password admin >/dev/null 2>&1; then
    warning "Could not authenticate with Keycloak admin CLI. Identity provider fixes may fail."
  fi
  
  # Fix redirect URLs for identity providers
  show_progress "Updating identity provider redirect URIs..."
  
  # List of identity providers to update
  local identity_providers="usa uk canada australia newzealand"
  
  # Get base URL from env
  local base_domain=${BASE_DOMAIN:-"dive25.local"}
  local frontend_url="https://frontend.${base_domain}:3001"
  
  # Create temporary JSON update file
  local temp_file=$(mktemp)
  
  cat > $temp_file << EOF
{
  "config": {
    "validateSignature": "true",
    "useJwksUrl": "true",
    "loginHint": "false",
    "uiLocales": "false",
    "backchannelSupported": "false",
    "disableUserInfo": "false",
    "acceptsPromptNoneForwFrdFromClient": "false",
    "validateSignature.alt": "",
    "useJwksUrl.alt": "",
    "backchannelSupported.alt": "",
    "disableUserInfo.alt": "",
    "validateSignature.new": "",
    "useJwksUrl.new": "",
    "backchannelSupported.new": "",
    "disableUserInfo.new": "",
    "clientId.new": "",
    "tokenUrl.new": "",
    "authorizationUrl.new": "",
    "jwksUrl.new": "",
    "userInfoUrl.new": "",
    "issuer.new": "",
    "defaultScope.new": "",
    "redirectUris": [
      "${frontend_url}/*"
    ]
  }
}
EOF
  
  # Apply updates to each identity provider
  for provider in $identity_providers; do
    show_progress "Updating $provider identity provider..."
    
    # Check if the provider exists
    if docker exec $keycloak_container /opt/keycloak/bin/kcadm.sh get identity-provider/instances/$provider -r dive25 >/dev/null 2>&1; then
      # Update the provider
      docker exec -i $keycloak_container /opt/keycloak/bin/kcadm.sh update identity-provider/instances/$provider -r dive25 -f - < $temp_file >/dev/null 2>&1
      
      if [ $? -eq 0 ]; then
        success "Updated $provider identity provider successfully"
      else
        warning "Failed to update $provider identity provider"
      fi
    else
      info "Identity provider $provider does not exist, skipping"
    fi
  done
  
  # Clean up
  rm -f $temp_file
  
  success "Identity provider fixes completed"
  return 0
}

# Update Keycloak client configuration
update_keycloak_client_config() {
  print_step "Updating Keycloak Client Configuration"
  
  show_progress "Updating frontend client configuration for proper redirects..."
  
  # Get Keycloak container
  local keycloak_container=$(docker ps --format '{{.Names}}' | grep -E 'keycloak' | grep -v "config" | head -n 1)
  
  if [ -z "$keycloak_container" ]; then
    warning "Keycloak container not found. Cannot update client configuration."
    return 1
  fi
  
  # First make sure we're authenticated
  show_progress "Authenticating with Keycloak admin CLI..."
  if ! docker exec $keycloak_container /opt/keycloak/bin/kcadm.sh config credentials \
    --server http://localhost:8080 \
    --realm master \
    --user admin \
    --password admin >/dev/null 2>&1; then
    warning "Could not authenticate with Keycloak admin CLI. Client config updates may fail."
  fi
  
  # Get frontend client ID
  show_progress "Getting frontend client ID..."
  local client_id=$(docker exec $keycloak_container /opt/keycloak/bin/kcadm.sh get clients -r dive25 --fields id,clientId -q clientId=dive25-frontend | grep '"id"' | sed 's/.*"id" : "\([^"]*\)".*/\1/')
  
  if [ -z "$client_id" ]; then
    warning "Frontend client not found. Cannot update client configuration."
    return 1
  fi
  
  success "Found frontend client with ID: $client_id"
  
  # Update client configuration for proper IdP redirects
  show_progress "Updating frontend client configuration..."
  
  # Create a JSON file with the updated configuration
  docker exec $keycloak_container bash -c "cat > /tmp/frontend-client-update.json << EOF
{
  \"webOrigins\": [\"*\"],
  \"attributes\": {
    \"post.logout.redirect.uris\": \"*\",
    \"oauth2.device.authorization.grant.enabled\": \"true\",
    \"backchannel.logout.session.required\": \"true\",
    \"backchannel.logout.revoke.offline.tokens\": \"false\",
    \"access.token.lifespan\": \"1800\",
    \"oauth2.device.polling.interval\": \"5\"
  },
  \"standardFlowEnabled\": true,
  \"implicitFlowEnabled\": false,
  \"directAccessGrantsEnabled\": true,
  \"authenticationFlowBindingOverrides\": {
    \"browser\": \"browser\"
  }
}
EOF"
  
  # Apply the configuration update
  if docker exec $keycloak_container /opt/keycloak/bin/kcadm.sh update clients/$client_id -r dive25 -f /tmp/frontend-client-update.json >/dev/null 2>&1; then
    success "Frontend client configuration updated successfully"
  else
    warning "Failed to update frontend client configuration"
  fi
  
  # Make sure all identity providers are enabled for the client
  show_progress "Ensuring identity providers are enabled for the client..."
  
  # Get the base domain
  local base_domain=${BASE_DOMAIN:-"dive25.local"}
  local frontend_url="https://frontend.${base_domain}:3001"
  
  for provider in usa uk canada australia newzealand; do
    # Check if the provider exists
    if docker exec $keycloak_container /opt/keycloak/bin/kcadm.sh get identity-provider/instances/$provider -r dive25 >/dev/null 2>&1; then
      # Enable the provider for the client
      docker exec $keycloak_container /opt/keycloak/bin/kcadm.sh create clients/$client_id/identity-provider-mappers -r dive25 -f - << EOF >/dev/null 2>&1
{
  "identityProviderAlias": "$provider",
  "identityProviderMapper": "oidc-user-attribute-idp-mapper",
  "name": "$provider-username-mapper",
  "config": {
    "syncMode": "INHERIT",
    "claim": "preferred_username",
    "user.attribute": "username"
  }
}
EOF
      
      if [ $? -eq 0 ]; then
        success "Enabled $provider identity provider for frontend client"
      else
        warning "Failed to enable $provider identity provider for frontend client"
      fi
    fi
  done
  
  success "Keycloak client configuration updated"
  return 0
}

# Create a new Keycloak realm
create_keycloak_realm() {
  print_step "Creating Keycloak Realm"
  
  # Get variables from environment or defaults
  local keycloak_realm=${KEYCLOAK_REALM:-"dive25"}
  
  # Get Keycloak container
  local keycloak_container=$(docker ps --format '{{.Names}}' | grep -E 'keycloak' | grep -v "config" | head -n 1)
  
  if [ -z "$keycloak_container" ]; then
    warning "Keycloak container not found. Cannot create realm."
    return 1
  fi
  
  # Configure Keycloak CLI
  show_progress "Authenticating with Keycloak admin CLI..."
  if ! docker exec $keycloak_container /opt/keycloak/bin/kcadm.sh config credentials \
    --server http://localhost:8080 \
    --realm master \
    --user admin \
    --password admin >/dev/null 2>&1; then
    warning "Could not authenticate with Keycloak admin CLI. Realm creation may fail."
  fi
  
  # Check if realm already exists
  if docker exec $keycloak_container /opt/keycloak/bin/kcadm.sh get realms/$keycloak_realm >/dev/null 2>&1; then
    info "Realm $keycloak_realm already exists"
    return 0
  fi
  
  # Create the realm
  show_progress "Creating realm $keycloak_realm..."
  
  # Create realm JSON
  docker exec $keycloak_container bash -c "cat > /tmp/realm-create.json << EOF
{
  \"realm\": \"$keycloak_realm\",
  \"enabled\": true,
  \"displayName\": \"DIVE25 Realm\",
  \"displayNameHtml\": \"<div class=\\\"kc-logo-text\\\"><span>DIVE25</span></div>\",
  \"loginTheme\": \"keycloak\",
  \"accountTheme\": \"keycloak\",
  \"adminTheme\": \"keycloak\",
  \"emailTheme\": \"keycloak\",
  \"sslRequired\": \"external\",
  \"registrationAllowed\": false,
  \"editUsernameAllowed\": false,
  \"resetPasswordAllowed\": true,
  \"verifyEmail\": false,
  \"loginWithEmailAllowed\": true,
  \"duplicateEmailsAllowed\": false,
  \"bruteForceProtected\": true,
  \"permanentLockout\": false,
  \"maxFailureWaitSeconds\": 900,
  \"minimumQuickLoginWaitSeconds\": 60,
  \"waitIncrementSeconds\": 60,
  \"quickLoginCheckMilliSeconds\": 1000,
  \"maxDeltaTimeSeconds\": 43200,
  \"failureFactor\": 3,
  \"defaultSignatureAlgorithm\": \"RS256\",
  \"offlineSessionMaxLifespan\": 5184000,
  \"offlineSessionMaxLifespanEnabled\": false,
  \"accessTokenLifespan\": 1800,
  \"accessTokenLifespanForImplicitFlow\": 900,
  \"ssoSessionIdleTimeout\": 1800,
  \"ssoSessionMaxLifespan\": 36000,
  \"accessCodeLifespan\": 60,
  \"accessCodeLifespanUserAction\": 300,
  \"accessCodeLifespanLogin\": 1800,
  \"actionTokenGeneratedByAdminLifespan\": 43200,
  \"actionTokenGeneratedByUserLifespan\": 300,
  \"revokeRefreshToken\": false,
  \"refreshTokenMaxReuse\": 0,
  \"ssoSessionIdleTimeoutRememberMe\": 0,
  \"ssoSessionMaxLifespanRememberMe\": 0,
  \"rememberMe\": false
}
EOF"
  
  # Create the realm
  if docker exec $keycloak_container /opt/keycloak/bin/kcadm.sh create realms -f /tmp/realm-create.json >/dev/null 2>&1; then
    success "Realm $keycloak_realm created successfully"
    
    # Create marker file
    mkdir -p /tmp/keycloak-config
    echo "$keycloak_realm" > /tmp/keycloak-config/realm-ready
    
    return 0
  else
    error "Failed to create realm $keycloak_realm"
    return 1
  fi
}

# Main function to configure Keycloak
main() {
  # Wait for Keycloak to be ready
  wait_for_keycloak
  
  # Update Keycloak client configuration
  update_keycloak_client_config
  
  # Fix identity providers
  fix_identity_providers
  
  success "Keycloak configuration completed successfully"
  return 0
}

# Execute main function if script is run directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi 