#!/bin/bash
# Quick script to update the UK OIDC provider configuration to a working test version

set -e

# Get admin token
echo "Getting admin token..."
ADMIN_TOKEN=$(curl -s -X POST 'http://localhost:8444/realms/master/protocol/openid-connect/token' \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d 'username=admin' \
  -d 'password=admin' \
  -d 'grant_type=password' \
  -d 'client_id=admin-cli' | jq -r '.access_token')

if [ -z "$ADMIN_TOKEN" ] || [ "$ADMIN_TOKEN" = "null" ]; then
  echo "Failed to get admin token"
  exit 1
else
  echo "✅ Got admin token"
fi

# Update the UK-OIDC provider
echo "Updating UK-OIDC provider..."
curl -s -X PUT "http://localhost:8444/admin/realms/dive25/identity-provider/instances/uk-oidc" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "alias": "uk-oidc",
    "displayName": "UK Government OIDC",
    "providerId": "oidc",
    "enabled": true,
    "updateProfileFirstLoginMode": "on",
    "trustEmail": true,
    "storeToken": false,
    "addReadTokenRoleOnCreate": false,
    "authenticateByDefault": false,
    "linkOnly": false,
    "firstBrokerLoginFlowAlias": "first broker login",
    "config": {
        "clientId": "admin-cli",
        "clientSecret": "admin",
        "tokenUrl": "https://keycloak.dive25.local:8443/realms/dive25/protocol/openid-connect/token",
        "authorizationUrl": "https://keycloak.dive25.local:8443/realms/dive25/protocol/openid-connect/auth",
        "jwksUrl": "https://keycloak.dive25.local:8443/realms/dive25/protocol/openid-connect/certs",
        "userInfoUrl": "https://keycloak.dive25.local:8443/realms/dive25/protocol/openid-connect/userinfo",
        "logoutUrl": "https://keycloak.dive25.local:8443/realms/dive25/protocol/openid-connect/logout",
        "validateSignature": "true",
        "useJwksUrl": "true",
        "clientAuthMethod": "client_secret_basic",
        "syncMode": "IMPORT",
        "defaultScope": "openid profile email",
        "disableUserInfo": "false",
        "allowedClockSkew": "10"
    }
}'

echo "✅ UK-OIDC provider updated"

# Create a test user if it doesn't exist
echo "Creating test user..."
curl -s -X POST "http://localhost:8444/admin/realms/dive25/users" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "uk-test",
    "enabled": true,
    "emailVerified": true,
    "firstName": "UK",
    "lastName": "Test",
    "email": "uk-test@example.com",
    "credentials": [
      {
        "type": "password",
        "value": "password",
        "temporary": false
      }
    ]
  }' || echo "User may already exist"

# Set password for user
USER_ID=$(curl -s "http://localhost:8444/admin/realms/dive25/users?username=uk-test" \
  -H "Authorization: Bearer $ADMIN_TOKEN" | jq -r '.[0].id')

if [ -n "$USER_ID" ] && [ "$USER_ID" != "null" ]; then
  echo "Setting password for user $USER_ID..."
  curl -s -X PUT "http://localhost:8444/admin/realms/dive25/users/$USER_ID/reset-password" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
      "type": "password",
      "value": "password",
      "temporary": false
    }'
  echo "✅ Password set"
else
  echo "⚠️ Could not find user ID"
fi

echo "✅ Configuration complete" 