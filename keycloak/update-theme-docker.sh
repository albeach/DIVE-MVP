#!/bin/bash
# Script to update Keycloak theme configuration using Docker and curl

# Copy the theme JSON file to the container
docker cp keycloak/update-theme.json dive25-keycloak:/tmp/

# Use curl image to update the theme
docker run --rm --network dive-mvp_dive25-network curlimages/curl:latest \
  -X POST "http://dive25-keycloak:8080/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=admin" \
  -d "password=admin" \
  -d "grant_type=password" \
  -d "client_id=admin-cli" \
  | tee /tmp/token-response.json

# Extract token from response
TOKEN=$(cat /tmp/token-response.json | grep -o '"access_token":"[^"]*"' | cut -d':' -f2 | tr -d '"')

if [ -z "$TOKEN" ]; then
    echo "Failed to get admin token"
    exit 1
fi
echo "Admin token acquired"

# Update the dive25 realm theme settings
echo "Updating dive25 realm theme settings..."
docker run --rm --network dive-mvp_dive25-network \
  -v $(pwd)/keycloak/update-theme.json:/tmp/update-theme.json \
  curlimages/curl:latest \
  -X PUT "http://dive25-keycloak:8080/admin/realms/dive25" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d @/tmp/update-theme.json

echo "Theme settings updated!" 