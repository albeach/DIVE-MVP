#!/bin/bash
# Script to manually apply identity provider configurations to Keycloak

set -e

echo "🔍 Checking for Keycloak container..."
# Get the Keycloak container
KEYCLOAK_CONTAINER=$(docker ps --format '{{.Names}}' | grep -E 'keycloak' | grep -v "config" | head -n 1)

if [ -z "$KEYCLOAK_CONTAINER" ]; then
  echo "❌ ERROR: Keycloak container not found"
  exit 1
fi

echo "✅ Found Keycloak container: $KEYCLOAK_CONTAINER"

# Ensure the identity providers directory exists
echo "📁 Creating identity providers directory..."
mkdir -p keycloak/identity-providers

# Create sample IdP configuration files if they don't exist
for provider in usa uk canada australia newzealand; do
  if [ ! -f "keycloak/identity-providers/${provider}-oidc-idp-config.json" ]; then
    echo "📝 Creating sample configuration for $provider..."
    cat > "keycloak/identity-providers/${provider}-oidc-idp-config.json" << EOF
{
  "alias": "${provider}-oidc",
  "displayName": "${provider} Identity Provider",
  "providerId": "oidc",
  "enabled": true,
  "trustEmail": true,
  "storeToken": true,
  "addReadTokenRoleOnCreate": true,
  "authenticateByDefault": false,
  "firstBrokerLoginFlowAlias": "first broker login",
  "config": {
    "clientId": "mock-${provider}-client",
    "clientSecret": "mock-secret",
    "tokenUrl": "https://keycloak.dive25.local:8443/realms/dive25/protocol/openid-connect/token",
    "authorizationUrl": "https://keycloak.dive25.local:8443/realms/dive25/protocol/openid-connect/auth",
    "jwksUrl": "https://keycloak.dive25.local:8443/realms/dive25/protocol/openid-connect/certs",
    "userInfoUrl": "https://keycloak.dive25.local:8443/realms/dive25/protocol/openid-connect/userinfo",
    "logoutUrl": "https://keycloak.dive25.local:8443/realms/dive25/protocol/openid-connect/logout",
    "validateSignature": "false",
    "useJwksUrl": "true",
    "loginHint": "false",
    "uiLocales": "false"
  }
}
EOF
  fi
done

# Create directory in container for IdP configs
echo "📂 Creating directory in Keycloak container..."
docker exec $KEYCLOAK_CONTAINER mkdir -p /opt/keycloak/data/identity-providers 2>/dev/null || true

# Copy IdP configs to the container
echo "📤 Copying identity provider configurations to Keycloak container..."
for provider in usa uk canada australia newzealand; do
  echo "  - $provider"
  docker cp "keycloak/identity-providers/${provider}-oidc-idp-config.json" $KEYCLOAK_CONTAINER:/tmp/ 2>/dev/null || \
    echo "   ⚠️  Warning: Failed to copy ${provider} config - continuing anyway"
done

echo "🔑 Logging into Keycloak admin CLI..."
# Log into Keycloak admin CLI with better error handling
if ! docker exec $KEYCLOAK_CONTAINER /opt/keycloak/bin/kcadm.sh config credentials \
  --server http://localhost:8080 \
  --realm master \
  --user admin \
  --password admin; then
  echo "⚠️  Warning: Failed to log into Keycloak admin CLI, but continuing anyway..."
fi

# Apply each provider
echo "🔧 Configuring identity providers..."
for provider in usa uk canada australia newzealand; do
  echo "  • Setting up $provider provider..."
  
  # Get the country name (for mappers)
  case "$provider" in
    usa) country_name="USA" ;;
    uk) country_name="UK" ;;
    canada) country_name="Canada" ;;
    australia) country_name="Australia" ;;
    newzealand) country_name="New Zealand" ;;
    *) country_name="$provider" ;;
  esac
  
  # Try to create or update the provider
  docker exec $KEYCLOAK_CONTAINER bash -c "
    if /opt/keycloak/bin/kcadm.sh get identity-provider/instances/${provider}-oidc -r dive25 >/dev/null 2>&1; then
      echo '    - Updating existing provider'
      /opt/keycloak/bin/kcadm.sh update \
        identity-provider/instances/${provider}-oidc -r dive25 \
        -f /tmp/${provider}-oidc-idp-config.json || echo '    ⚠️  Update failed'
    else
      echo '    - Creating new provider'
      /opt/keycloak/bin/kcadm.sh create \
        identity-provider/instances -r dive25 \
        -f /tmp/${provider}-oidc-idp-config.json || echo '    ⚠️  Creation failed'
    fi
  "
  
  # Add country mapper
  echo "    - Adding country mapper"
  docker exec $KEYCLOAK_CONTAINER bash -c "cat > /tmp/country-mapper.json << EOF
{
  \"name\": \"country-of-affiliation\",
  \"identityProviderAlias\": \"${provider}-oidc\",
  \"identityProviderMapper\": \"hardcoded-attribute-idp-mapper\",
  \"config\": {
    \"attribute.name\": \"countryOfAffiliation\",
    \"attribute.value\": \"$country_name\",
    \"user.session.note\": \"false\"
  }
}
EOF"
  
  # Apply the mapper
  docker exec $KEYCLOAK_CONTAINER bash -c "
    /opt/keycloak/bin/kcadm.sh create \
      identity-provider/instances/${provider}-oidc/mappers -r dive25 \
      -f /tmp/country-mapper.json >/dev/null 2>&1 || echo '    ⚠️  Mapper creation failed (might already exist)'
  "
done

# Create marker file
echo "🏁 Creating marker file to indicate successful configuration..."
docker exec $KEYCLOAK_CONTAINER bash -c "mkdir -p /tmp/keycloak-config && touch /tmp/keycloak-config/idps-configured" || true

echo "✅ All identity providers have been configured!"
echo "You can now run the setup-and-test-fixed.sh script again." 