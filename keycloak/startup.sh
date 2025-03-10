#!/bin/bash
set -e

echo "Starting Keycloak with realm import..."
/opt/keycloak/bin/kc.sh start --optimized --import-realm &
KEYCLOAK_PID=$!

# Wait for Keycloak to start
echo "Waiting for Keycloak to start..."
until curl -s http://localhost:8080 > /dev/null; do
  echo "Waiting for Keycloak..."
  sleep 5
done

echo "Keycloak started, checking realm..."
# Let Keycloak have more time to initialize before checking for realm
sleep 10

# Check if realm exists, create if it doesn't
ADMIN_TOKEN=$(curl -s -X POST "http://localhost:8080/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=${KEYCLOAK_ADMIN}" \
  -d "password=${KEYCLOAK_ADMIN_PASSWORD}" \
  -d "grant_type=password" \
  -d "client_id=admin-cli" | grep -o '"access_token":"[^"]*"' | cut -d':' -f2 | tr -d '"' )

REALM_EXISTS=$(curl -s -o /dev/null -w "%{http_code}" \
  -X GET "http://localhost:8080/admin/realms/dive25" \
  -H "Authorization: Bearer $ADMIN_TOKEN")

if [ "$REALM_EXISTS" = "200" ]; then
  echo "Realm dive25 already exists."
else
  echo "Creating realm dive25..."
  curl -s -X POST "http://localhost:8080/admin/realms" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    --data-binary @/opt/keycloak/data/import/realm-export.json
  echo "Realm created."
fi

# Keep the container running with the original Keycloak process
wait $KEYCLOAK_PID 