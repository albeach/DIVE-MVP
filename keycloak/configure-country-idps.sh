#!/bin/bash
# keycloak/configure-country-idps.sh
# Script to configure country-specific Identity Providers in Keycloak

set -e

echo "=============================================="
echo "DIVE25 - Country-Specific IdP Configuration"
echo "=============================================="

# Default values for environment variables
KEYCLOAK_URL=${INTERNAL_KEYCLOAK_URL:-"http://localhost:8080"}
KEYCLOAK_REALM=${KEYCLOAK_REALM:-"dive25"}
KEYCLOAK_ADMIN=${KEYCLOAK_ADMIN:-"admin"}
KEYCLOAK_ADMIN_PASSWORD=${KEYCLOAK_ADMIN_PASSWORD:-"admin"}
IDP_CONFIG_DIR=${IDP_CONFIG_DIR:-"/opt/keycloak/data/identity-providers"}
CURL_TOOLS_CONTAINER=${CURL_TOOLS_CONTAINER:-"curl_tools"}

# Validate important directories exist
if [ ! -d "$IDP_CONFIG_DIR" ]; then
  echo "⚠️ Identity provider config directory ($IDP_CONFIG_DIR) does not exist or is not accessible"
  echo "Creating directory and setting permissions..."
  mkdir -p "$IDP_CONFIG_DIR" || { echo "❌ Failed to create $IDP_CONFIG_DIR"; exit 1; }
fi

# Show exactly which directory we're using for configs
echo "Using identity provider configs from: $IDP_CONFIG_DIR"
ls -la "$IDP_CONFIG_DIR" || echo "⚠️ Failed to list config directory contents"

# Initialize Keycloak admin CLI
echo "Setting up Keycloak admin credentials..."
/opt/keycloak/bin/kcadm.sh config credentials --server "$KEYCLOAK_URL" --realm master --user "$KEYCLOAK_ADMIN" --password "$KEYCLOAK_ADMIN_PASSWORD" || {
  echo "❌ Failed to authenticate with Keycloak admin CLI"
  exit 1
}

# Function to verify if identity provider exists
check_idp_exists() {
  local idp_alias="$1"
  echo "Checking if identity provider $idp_alias exists..."
  
  # Get current identity providers
  local result=$(/opt/keycloak/bin/kcadm.sh get identity-provider/instances -r "$KEYCLOAK_REALM" 2>/dev/null || echo '[]')
  
  # Check if this identity provider already exists
  if echo "$result" | grep -q "\"alias\" : \"$idp_alias\""; then
    echo "✅ Identity provider $idp_alias already exists"
    return 0
  else
    echo "Identity provider $idp_alias does not exist yet"
    return 1
  fi
}

# Function to create or update a country-specific IdP
create_country_idp() {
  local country_id="$1"
  local config_file="$2"
  
  echo "Processing $country_id Identity Provider..."
  
  # Make sure config file exists
  if [ ! -f "$config_file" ]; then
    echo "❌ Config file $config_file does not exist!"
    return 1
  fi
  
  # Try the direct method first (using kcadm.sh)
  if which kcadm.sh >/dev/null 2>&1 || [ -f "/opt/keycloak/bin/kcadm.sh" ]; then
    echo "Using direct Keycloak CLI method..."
    # Check if the IdP already exists
    if check_idp_exists "$country_id"; then
      echo "Updating existing $country_id Identity Provider..."
      
      # Update existing IdP
      /opt/keycloak/bin/kcadm.sh update identity-provider/instances/$country_id -r "$KEYCLOAK_REALM" -f "$config_file" || {
        echo "⚠️ Direct method failed, falling back to Docker method..."
        create_country_idp_docker "$country_id" "$config_file"
        return $?
      }
        
      echo "✅ Updated $country_id Identity Provider"
    else
      echo "Creating new $country_id Identity Provider..."
      
      # Create new IdP
      /opt/keycloak/bin/kcadm.sh create identity-provider/instances -r "$KEYCLOAK_REALM" -f "$config_file" || {
        echo "⚠️ Direct method failed, falling back to Docker method..."
        create_country_idp_docker "$country_id" "$config_file"
        return $?
      }
        
      echo "✅ Created $country_id Identity Provider"
    fi
  else
    echo "Keycloak CLI not available, using Docker method..."
    create_country_idp_docker "$country_id" "$config_file"
    return $?
  fi
  
  return 0
}

# Function to get a fresh admin token using curl tool container
get_admin_token() {
  echo "Getting admin token..."
  
  # Get new token using curl-tools container
  local response=$(docker exec $CURL_TOOLS_CONTAINER curl -s -X POST "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "username=${KEYCLOAK_ADMIN}" \
    -d "password=${KEYCLOAK_ADMIN_PASSWORD}" \
    -d "grant_type=password" \
    -d "client_id=admin-cli")
  
  # Extract the token
  local token=$(echo "$response" | docker exec -i $CURL_TOOLS_CONTAINER jq -r ".access_token")
  
  if [ -n "$token" ] && [ "$token" != "null" ]; then
    echo "✅ Successfully obtained admin token"
    echo "$token"
    return 0
  else
    echo "❌ Failed to get admin token: $response" >&2
    return 1
  fi
}

# Function to create a country-specific IdP using Docker method
create_country_idp_docker() {
  local country_id="$1"
  local config_file="$2"
  local TOKEN=$(get_admin_token)
  
  if [ -z "$TOKEN" ]; then
    echo "❌ Failed to get admin token for IdP creation"
    return 1
  fi
  
  echo "Creating $country_id Identity Provider using Docker method..."
  
  # Check if the IdP already exists
  local idp_exists=$(docker exec $CURL_TOOLS_CONTAINER curl -s -o /dev/null -w "%{http_code}" \
    -H "Authorization: Bearer $TOKEN" \
    "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/identity-provider/instances/${country_id}")
  
  if [ "$idp_exists" = "200" ]; then
    echo "⚠️ Identity Provider $country_id already exists, updating configuration"
    
    # Update existing IdP
    docker exec $CURL_TOOLS_CONTAINER curl -s -X PUT \
      "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/identity-provider/instances/${country_id}" \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json" \
      -d @"$config_file"
      
    echo "✅ Updated $country_id Identity Provider"
  else
    # Create new IdP
    docker exec $CURL_TOOLS_CONTAINER curl -s -X POST \
      "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/identity-provider/instances" \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json" \
      -d @"$config_file"
      
    echo "✅ Created $country_id Identity Provider"
  fi
  
  return 0
}

# Function to create mappers for an IdP
create_country_idp_mappers() {
  local idp_alias="$1"
  local country_name="$2"
  
  echo "Creating mappers for $idp_alias Identity Provider..."
  
  # Try the direct method first (using kcadm.sh)
  if which kcadm.sh >/dev/null 2>&1 || [ -f "/opt/keycloak/bin/kcadm.sh" ]; then
    echo "Using direct Keycloak CLI method for mappers..."
    
    # Create mapper for country attribute
    echo "Creating country-of-affiliation mapper..."
    cat > /tmp/country-mapper.json << EOF
{
  "name": "country-of-affiliation",
  "identityProviderAlias": "$idp_alias",
  "identityProviderMapper": "hardcoded-attribute-idp-mapper",
  "config": {
    "attribute.name": "countryOfAffiliation",
    "attribute.value": "$country_name",
    "user.session.note": "false"
  }
}
EOF

    /opt/keycloak/bin/kcadm.sh create identity-provider/instances/$idp_alias/mappers -r "$KEYCLOAK_REALM" -f /tmp/country-mapper.json || {
      echo "⚠️ Direct method failed for country mapper, falling back to Docker method..."
      create_country_idp_mappers_docker "$idp_alias" "$country_name"
      return $?
    }
    
    # Create mapper for security clearance
    echo "Creating security-clearance mapper..."
    cat > /tmp/clearance-mapper.json << EOF
{
  "name": "security-clearance",
  "identityProviderAlias": "$idp_alias",
  "identityProviderMapper": "oidc-user-attribute-idp-mapper",
  "config": {
    "user.attribute": "clearance",
    "claim": "security_clearance",
    "syncMode": "INHERIT"
  }
}
EOF

    /opt/keycloak/bin/kcadm.sh create identity-provider/instances/$idp_alias/mappers -r "$KEYCLOAK_REALM" -f /tmp/clearance-mapper.json || {
      echo "⚠️ Failed to create clearance mapper (may already exist)"
    }
      
    # Create mapper for caveats
    echo "Creating security-caveats mapper..."
    cat > /tmp/caveats-mapper.json << EOF
{
  "name": "security-caveats",
  "identityProviderAlias": "$idp_alias",
  "identityProviderMapper": "oidc-user-attribute-idp-mapper",
  "config": {
    "user.attribute": "caveats",
    "claim": "security_caveats",
    "syncMode": "INHERIT"
  }
}
EOF

    /opt/keycloak/bin/kcadm.sh create identity-provider/instances/$idp_alias/mappers -r "$KEYCLOAK_REALM" -f /tmp/caveats-mapper.json || {
      echo "⚠️ Failed to create caveats mapper (may already exist)"
    }
    
    # Create mapper for conflicts of interest
    echo "Creating conflicts-of-interest mapper..."
    cat > /tmp/coi-mapper.json << EOF
{
  "name": "conflicts-of-interest",
  "identityProviderAlias": "$idp_alias",
  "identityProviderMapper": "oidc-user-attribute-idp-mapper",
  "config": {
    "user.attribute": "coi",
    "claim": "conflicts_of_interest",
    "syncMode": "INHERIT"
  }
}
EOF

    /opt/keycloak/bin/kcadm.sh create identity-provider/instances/$idp_alias/mappers -r "$KEYCLOAK_REALM" -f /tmp/coi-mapper.json || {
      echo "⚠️ Failed to create COI mapper (may already exist)"
    }
  else
    echo "Keycloak CLI not available for mappers, using Docker method..."
    create_country_idp_mappers_docker "$idp_alias" "$country_name"
    return $?
  fi
    
  echo "✅ Created/updated mappers for $idp_alias Identity Provider"
}

# Function to create mappers for an IdP using Docker method
create_country_idp_mappers_docker() {
  local idp_alias="$1"
  local country_name="$2"
  local TOKEN=$(get_admin_token)
  
  if [ -z "$TOKEN" ]; then
    echo "❌ Failed to get admin token for mapper creation"
    return 1
  fi
  
  echo "Creating mappers for $idp_alias Identity Provider using Docker method..."
  
  # Create mapper for country attribute
  docker exec $CURL_TOOLS_CONTAINER curl -s -X POST \
    "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/identity-provider/instances/${idp_alias}/mappers" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
      "name": "country-of-affiliation",
      "identityProviderAlias": "'$idp_alias'",
      "identityProviderMapper": "hardcoded-attribute-idp-mapper",
      "config": {
        "attribute.name": "countryOfAffiliation",
        "attribute.value": "'$country_name'",
        "user.session.note": "false"
      }
    }'
  
  # Create mapper for security clearance
  docker exec $CURL_TOOLS_CONTAINER curl -s -X POST \
    "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/identity-provider/instances/${idp_alias}/mappers" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
      "name": "security-clearance",
      "identityProviderAlias": "'$idp_alias'",
      "identityProviderMapper": "oidc-user-attribute-idp-mapper",
      "config": {
        "user.attribute": "clearance",
        "claim": "security_clearance",
        "syncMode": "INHERIT"
      }
    }'
    
  # Create mapper for caveats
  docker exec $CURL_TOOLS_CONTAINER curl -s -X POST \
    "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/identity-provider/instances/${idp_alias}/mappers" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
      "name": "security-caveats",
      "identityProviderAlias": "'$idp_alias'",
      "identityProviderMapper": "oidc-user-attribute-idp-mapper",
      "config": {
        "user.attribute": "caveats",
        "claim": "security_caveats",
        "syncMode": "INHERIT"
      }
    }'
  
  # Create mapper for conflicts of interest
  docker exec $CURL_TOOLS_CONTAINER curl -s -X POST \
    "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/identity-provider/instances/${idp_alias}/mappers" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
      "name": "conflicts-of-interest",
      "identityProviderAlias": "'$idp_alias'",
      "identityProviderMapper": "oidc-user-attribute-idp-mapper",
      "config": {
        "user.attribute": "coi",
        "claim": "conflicts_of_interest",
        "syncMode": "INHERIT"
      }
    }'
    
  echo "✅ Created mappers for $idp_alias Identity Provider using Docker method"
}

# Function to verify all identity providers are created
verify_idps() {
  echo "Verifying identity providers are properly configured..."
  
  # Try the direct method first
  if which kcadm.sh >/dev/null 2>&1 || [ -f "/opt/keycloak/bin/kcadm.sh" ]; then
    echo "Using direct Keycloak CLI method for verification..."
    local idps=$(/opt/keycloak/bin/kcadm.sh get identity-provider/instances -r "$KEYCLOAK_REALM" 2>/dev/null || echo '[]')
  else
    echo "Keycloak CLI not available, using Docker method for verification..."
    local TOKEN=$(get_admin_token)
    
    if [ -z "$TOKEN" ]; then
      echo "❌ Failed to get admin token for verification"
      return 1
    fi
    
    local idps=$(docker exec $CURL_TOOLS_CONTAINER curl -s -H "Authorization: Bearer $TOKEN" \
      "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/identity-provider/instances" 2>/dev/null || echo '[]')
  fi
  
  # Check if we have any identity providers
  if [ "$idps" = "[]" ]; then
    echo "❌ No identity providers found! Configuration failed."
    return 1
  fi
  
  # Check for each of our expected identity providers
  local missing=0
  for idp in "usa-oidc" "uk-oidc" "canada-oidc" "australia-oidc" "newzealand-oidc"; do
    if ! echo "$idps" | grep -q "\"alias\" : \"$idp\""; then
      echo "❌ Identity provider $idp is missing!"
      missing=$((missing + 1))
    else
      echo "✅ Identity provider $idp exists"
    fi
  done
  
  if [ $missing -gt 0 ]; then
    echo "⚠️ $missing identity providers are missing!"
    return 1
  else
    echo "✅ All identity providers are properly configured"
    return 0
  fi
}

# Main execution
echo "Configuring country-specific Identity Providers..."

# Process each country IdP configuration
process_country_idp() {
  local country_id="$1"
  local config_file="$2"
  local country_name="$3"
  
  if create_country_idp "$country_id" "$config_file"; then
    create_country_idp_mappers "$country_id" "$country_name"
    echo "--------------------------------------------"
  else
    echo "❌ Failed to configure $country_id identity provider"
    echo "--------------------------------------------"
  fi
}

# USA IdP
process_country_idp "usa-oidc" "$IDP_CONFIG_DIR/usa-oidc-idp-config.json" "USA"

# UK IdP
process_country_idp "uk-oidc" "$IDP_CONFIG_DIR/uk-oidc-idp-config.json" "UK" 

# Canada IdP
process_country_idp "canada-oidc" "$IDP_CONFIG_DIR/canada-oidc-idp-config.json" "Canada"

# Australia IdP
process_country_idp "australia-oidc" "$IDP_CONFIG_DIR/australia-oidc-idp-config.json" "Australia"

# New Zealand IdP
process_country_idp "newzealand-oidc" "$IDP_CONFIG_DIR/newzealand-oidc-idp-config.json" "New Zealand"

# Verify all IdPs are configured
verify_idps

echo "Identity Provider configuration process completed!"

# Create a marker file to indicate successful setup
touch /tmp/keycloak-config/idps-configured

exit 0 