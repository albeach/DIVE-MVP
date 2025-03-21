#!/bin/bash
# Direct script to configure mock IdP from the host

set -e

echo "=============================================="
echo "DIVE25 - Mock Identity Provider Configuration"
echo "=============================================="

# Default values for environment variables
INTERNAL_KEYCLOAK_URL="http://localhost:8080"
KEYCLOAK_HOST="dive25-staging-keycloak"
KEYCLOAK_ADMIN="admin"
KEYCLOAK_ADMIN_PASSWORD="admin"

# Function to get a fresh admin token
get_admin_token() {
  echo "Getting admin token..."
  
  # Get new token
  local response=$(curl -s -X POST "${INTERNAL_KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" \
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

# Create the mock-idp realm
create_mock_idp_realm() {
  local TOKEN=$(get_admin_token)
  
  if [ -z "$TOKEN" ]; then
    echo "❌ Failed to get admin token for realm creation"
    return 1
  fi
  
  echo "Creating mock-idp realm..."
  
  # Check if the realm already exists
  local realm_exists=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Authorization: Bearer $TOKEN" \
    "${INTERNAL_KEYCLOAK_URL}/admin/realms/mock-idp")
  
  if [ "$realm_exists" = "200" ]; then
    echo "⚠️ mock-idp realm already exists"
    return 0
  fi
  
  # Create the realm
  curl -s -X POST \
    "${INTERNAL_KEYCLOAK_URL}/admin/realms" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
      "realm": "mock-idp",
      "enabled": true,
      "displayName": "Mock Identity Provider",
      "displayNameHtml": "<div class=\"kc-logo-text\"><span>Mock Identity Provider</span></div>",
      "sslRequired": "external",
      "registrationAllowed": true,
      "loginWithEmailAllowed": true,
      "duplicateEmailsAllowed": false,
      "resetPasswordAllowed": true,
      "editUsernameAllowed": false,
      "bruteForceProtected": true
    }'
    
  echo "✅ Created mock-idp realm"
}

# Create a client in the mock-idp realm
create_mock_idp_client() {
  local TOKEN=$(get_admin_token)
  
  if [ -z "$TOKEN" ]; then
    echo "❌ Failed to get admin token for client creation"
    return 1
  fi
  
  echo "Creating client in mock-idp realm..."
  
  # Create the client
  curl -s -X POST \
    "${INTERNAL_KEYCLOAK_URL}/admin/realms/mock-idp/clients" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
      "clientId": "dive25",
      "name": "DIVE25 Mock Client",
      "enabled": true,
      "clientAuthenticatorType": "client-secret",
      "secret": "change-me-in-production",
      "redirectUris": ["https://keycloak.dive25.local:8443/realms/dive25/broker/uk-oidc/endpoint"],
      "webOrigins": ["+"],
      "standardFlowEnabled": true,
      "implicitFlowEnabled": false,
      "directAccessGrantsEnabled": true,
      "serviceAccountsEnabled": false,
      "publicClient": false,
      "frontchannelLogout": false,
      "protocol": "openid-connect",
      "attributes": {
        "saml.assertion.signature": "false",
        "saml.force.post.binding": "false",
        "saml.multivalued.roles": "false",
        "saml.encrypt": "false",
        "saml.server.signature": "false",
        "saml.server.signature.keyinfo.ext": "false",
        "exclude.session.state.from.auth.response": "false",
        "saml_force_name_id_format": "false",
        "saml.client.signature": "false",
        "tls.client.certificate.bound.access.tokens": "false",
        "saml.authnstatement": "false",
        "display.on.consent.screen": "false",
        "saml.onetimeuse.condition": "false"
      },
      "fullScopeAllowed": true,
      "nodeReRegistrationTimeout": -1,
      "protocolMappers": [
        {
          "name": "email",
          "protocol": "openid-connect",
          "protocolMapper": "oidc-usermodel-property-mapper",
          "consentRequired": false,
          "config": {
            "userinfo.token.claim": "true",
            "user.attribute": "email",
            "id.token.claim": "true",
            "access.token.claim": "true",
            "claim.name": "email",
            "jsonType.label": "String"
          }
        },
        {
          "name": "security_clearance",
          "protocol": "openid-connect",
          "protocolMapper": "oidc-usermodel-attribute-mapper",
          "consentRequired": false,
          "config": {
            "userinfo.token.claim": "true",
            "user.attribute": "security_clearance",
            "id.token.claim": "true",
            "access.token.claim": "true",
            "claim.name": "security_clearance",
            "jsonType.label": "String"
          }
        },
        {
          "name": "security_caveats",
          "protocol": "openid-connect",
          "protocolMapper": "oidc-usermodel-attribute-mapper",
          "consentRequired": false,
          "config": {
            "userinfo.token.claim": "true",
            "user.attribute": "security_caveats",
            "id.token.claim": "true",
            "access.token.claim": "true",
            "claim.name": "security_caveats",
            "jsonType.label": "String"
          }
        }
      ]
    }'
    
  echo "✅ Created client in mock-idp realm"
}

# Create test users in the mock-idp realm
create_mock_idp_users() {
  local TOKEN=$(get_admin_token)
  
  if [ -z "$TOKEN" ]; then
    echo "❌ Failed to get admin token for user creation"
    return 1
  fi
  
  echo "Creating test users in mock-idp realm..."
  
  # Create test user with UK attributes
  curl -s -X POST \
    "${INTERNAL_KEYCLOAK_URL}/admin/realms/mock-idp/users" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
      "username": "uk-test-user",
      "email": "uk-test@example.com",
      "firstName": "United",
      "lastName": "Kingdom",
      "enabled": true,
      "emailVerified": true,
      "attributes": {
        "security_clearance": ["TOP_SECRET"],
        "security_caveats": ["EYES_ONLY"],
        "country": ["UK"]
      },
      "credentials": [
        {
          "type": "password",
          "value": "password",
          "temporary": false
        }
      ]
    }'
  
  # Get the user ID
  local USER_ID=$(curl -s \
    "${INTERNAL_KEYCLOAK_URL}/admin/realms/mock-idp/users?username=uk-test-user" \
    -H "Authorization: Bearer $TOKEN" | jq -r '.[0].id')
  
  # Set password for user
  curl -s -X PUT \
    "${INTERNAL_KEYCLOAK_URL}/admin/realms/mock-idp/users/${USER_ID}/reset-password" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
      "type": "password",
      "value": "password",
      "temporary": false
    }'
    
  echo "✅ Created test users in mock-idp realm with ID: $USER_ID"
}

# Main execution
echo "Configuring mock Identity Provider realm..."

# Expose Keycloak's internal port to the host
echo "Exposing Keycloak's internal port to the host..."
docker run -d --rm --name keycloak-port-forward \
  --network dive-mvp_dive25-service \
  alpine/socat \
  tcp-listen:8080,fork,reuseaddr tcp-connect:$KEYCLOAK_HOST:8080

echo "Waiting for port forwarding to be established..."
sleep 5

create_mock_idp_realm
create_mock_idp_client
create_mock_idp_users

# Clean up the port forwarding
echo "Cleaning up port forwarding..."
docker rm -f keycloak-port-forward

echo "✅ Mock IdP realm has been configured successfully!" 