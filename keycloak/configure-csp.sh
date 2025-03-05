#!/bin/sh
# keycloak/configure-csp.sh
# This script configures Content Security Policy settings for Keycloak

# Get Internal Keycloak URL from environment variable
INTERNAL_KEYCLOAK_URL=${KEYCLOAK_URL}
echo "Internal Keycloak URL: ${INTERNAL_KEYCLOAK_URL}"

# Wait for Keycloak to be ready
echo "Waiting for Keycloak to be ready..."
while ! curl -s ${INTERNAL_KEYCLOAK_URL}/; do
    echo "Keycloak not ready yet... waiting 5 seconds"
    sleep 5
done
echo "Keycloak is ready!"

# Get admin token
echo "Getting admin token..."
ADMIN_TOKEN=$(curl -s -X POST "${INTERNAL_KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=${KEYCLOAK_ADMIN}" \
  -d "password=${KEYCLOAK_ADMIN_PASSWORD}" \
  -d "grant_type=password" \
  -d "client_id=admin-cli" | grep -o '"access_token":"[^"]*"' | cut -d':' -f2 | tr -d '"')

if [ -z "$ADMIN_TOKEN" ]; then
    echo "Failed to get admin token"
    exit 1
fi
echo "Admin token acquired"

# Get current realm settings
echo "Getting current master realm settings..."
curl -s -X GET "${INTERNAL_KEYCLOAK_URL}/admin/realms/master" \
  -H "Authorization: Bearer $ADMIN_TOKEN" | grep -i securityHeaders

# Update master realm to use minimal CSP settings
# We're using the absolute minimum CSP and letting Kong handle the rest
echo "Updating master realm security headers..."
MASTER_RESPONSE=$(curl -s -X PUT "${INTERNAL_KEYCLOAK_URL}/admin/realms/master" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "browserSecurityHeaders": {
      "contentSecurityPolicy": "frame-src *; frame-ancestors *; object-src '\''none'\''"
    }
  }')
echo "Master realm update status: $?"

# Update dive25 realm to use minimal CSP settings
echo "Updating dive25 realm security headers..."
DIVE25_RESPONSE=$(curl -s -X PUT "${INTERNAL_KEYCLOAK_URL}/admin/realms/dive25" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "browserSecurityHeaders": {
      "contentSecurityPolicy": "frame-src *; frame-ancestors *; object-src '\''none'\''"
    }
  }')
echo "Dive25 realm update status: $?"

# Check settings after update
echo "Getting master realm settings after update..."
curl -s -X GET "${INTERNAL_KEYCLOAK_URL}/admin/realms/master" \
  -H "Authorization: Bearer $ADMIN_TOKEN" | grep -i securityHeaders

echo "CSP settings have been updated successfully!" 