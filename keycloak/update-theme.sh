#!/bin/sh
# Script to update Keycloak theme configuration

# Wait for Keycloak to be ready
echo "Waiting for Keycloak to be ready..."
while ! curl -s http://localhost:8080/health/ready; do
    echo "Keycloak not ready yet... waiting 5 seconds"
    sleep 5
done
echo "Keycloak is ready!"

# Get admin token
echo "Getting admin token..."
ADMIN_TOKEN=$(curl -s -X POST "http://localhost:8080/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=admin" \
  -d "password=admin" \
  -d "grant_type=password" \
  -d "client_id=admin-cli" | grep -o '"access_token":"[^"]*"' | cut -d':' -f2 | tr -d '"')

if [ -z "$ADMIN_TOKEN" ]; then
    echo "Failed to get admin token"
    exit 1
fi
echo "Admin token acquired"

# Update the dive25 realm theme settings
echo "Updating dive25 realm theme settings..."
curl -s -X PUT "http://localhost:8080/admin/realms/dive25" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "id": "dive25",
    "realm": "dive25",
    "displayName": "DIVE25",
    "displayNameHtml": "<div>DIVE25</div>",
    "loginTheme": "dive25",
    "accountTheme": "dive25",
    "adminTheme": "dive25",
    "emailTheme": "dive25",
    "enabled": true,
    "sslRequired": "external",
    "registrationAllowed": false,
    "registrationEmailAsUsername": false,
    "rememberMe": true,
    "verifyEmail": false,
    "loginWithEmailAllowed": true,
    "duplicateEmailsAllowed": false,
    "resetPasswordAllowed": true,
    "editUsernameAllowed": false,
    "bruteForceProtected": true
  }'

echo "Theme settings updated!"

# Verify the theme settings
echo "Verifying theme settings..."
curl -s -H "Authorization: Bearer $ADMIN_TOKEN" "http://localhost:8080/admin/realms/dive25" | grep -E "Theme|theme"

echo "Theme update completed!" 