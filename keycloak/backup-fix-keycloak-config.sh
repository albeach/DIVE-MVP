#!/bin/bash
set -e

# This script fixes the Keycloak realm configuration
# It will create the dive25 realm properly using the existing setup

echo "=== Keycloak Configuration Fix Script ==="
echo "This script will properly configure Keycloak with the dive25 realm"

# Source the environment variables from .env
if [ -f .env ]; then
  echo "Loading environment variables from .env"
  set -a
  source .env
  set +a
else
  echo "ERROR: .env file not found. Please run this script from the project root."
  exit 1
fi

# Make sure required environment variables are set
if [ -z "$KEYCLOAK_ADMIN" ] || [ -z "$KEYCLOAK_ADMIN_PASSWORD" ]; then
  echo "KEYCLOAK_ADMIN and KEYCLOAK_ADMIN_PASSWORD are required. Please set them in .env"
  KEYCLOAK_ADMIN="${KEYCLOAK_ADMIN:-admin}"
  KEYCLOAK_ADMIN_PASSWORD="${KEYCLOAK_ADMIN_PASSWORD:-admin}"
  echo "Using defaults: KEYCLOAK_ADMIN=$KEYCLOAK_ADMIN, KEYCLOAK_ADMIN_PASSWORD=$KEYCLOAK_ADMIN_PASSWORD"
fi

# Set other variables from environment if available
KEYCLOAK_REALM="${KEYCLOAK_REALM:-dive25}"
INTERNAL_KEYCLOAK_URL="${INTERNAL_KEYCLOAK_URL:-http://keycloak:8080}"
KEYCLOAK_DOMAIN="${KEYCLOAK_DOMAIN:-keycloak.dive25.local}"
KEYCLOAK_PORT="${KEYCLOAK_PORT:-4432}"
INTERNAL_KONG_ADMIN_URL="${INTERNAL_KONG_ADMIN_URL:-http://kong:8001}"
KONG_ADMIN_PORT="${KONG_ADMIN_PORT:-9444}"
KONG_ADMIN_URL="http://localhost:${KONG_ADMIN_PORT}"
KONG_PROXY_PORT="${KONG_PROXY_PORT:-4433}"
KONG_DOMAIN="${KONG_DOMAIN:-kong.dive25.local}"
FRONTEND_DOMAIN="${FRONTEND_DOMAIN:-frontend.dive25.local}"
FRONTEND_PORT="${FRONTEND_PORT:-4430}"
API_DOMAIN="${API_DOMAIN:-api.dive25.local}"
API_PORT="${API_PORT:-4431}"

echo "Using configuration:"
echo "KEYCLOAK_REALM: $KEYCLOAK_REALM"
echo "INTERNAL_KEYCLOAK_URL: $INTERNAL_KEYCLOAK_URL"
echo "KONG_ADMIN_URL: $KONG_ADMIN_URL"
echo "FRONTEND_DOMAIN: $FRONTEND_DOMAIN:$FRONTEND_PORT"
echo "API_DOMAIN: $API_DOMAIN:$API_PORT"
echo "KONG_DOMAIN: $KONG_DOMAIN:$KONG_PROXY_PORT"

# Make sure our realm export file exists
REALM_EXPORT_PATH="./keycloak/realm-export.json"
if [ ! -f "$REALM_EXPORT_PATH" ]; then
    echo "ERROR: Realm export file not found at $REALM_EXPORT_PATH"
    exit 1
fi

# Check if Keycloak is running
if ! docker ps | grep -q dive25-keycloak; then
    echo "ERROR: Keycloak container is not running. Please start it with docker-compose up -d"
    exit 1
fi

# Copy the realm export to a temporary directory that we'll mount
echo "Creating temporary directory for Keycloak configuration..."
TEMP_DIR=$(mktemp -d)
cp "$REALM_EXPORT_PATH" "$TEMP_DIR/realm-export.json"

# Create environment file for the container
cat > "$TEMP_DIR/env.sh" << EOF
export KEYCLOAK_URL="$INTERNAL_KEYCLOAK_URL"
export KEYCLOAK_ADMIN="$KEYCLOAK_ADMIN"
export KEYCLOAK_ADMIN_PASSWORD="$KEYCLOAK_ADMIN_PASSWORD"
export REALM_NAME="$KEYCLOAK_REALM"
export FRONTEND_URL="https://$FRONTEND_DOMAIN:$FRONTEND_PORT"
export API_URL="https://$API_DOMAIN:$API_PORT"
export KEYCLOAK_URL_PUBLIC="https://$KEYCLOAK_DOMAIN:$KEYCLOAK_PORT"
EOF

# Create a script to run inside the container
cat > "$TEMP_DIR/import-realm.sh" << 'EOF'
#!/bin/bash
set -e

echo "Running realm import script in container..."

# Source environment variables
source /tmp/config/env.sh

# Set variables
REALM_FILE="/tmp/config/realm-export.json"

echo "Using Keycloak URL: $KEYCLOAK_URL"
echo "Realm name: $REALM_NAME"

# Get admin token
echo "Getting admin token..."
ADMIN_TOKEN=$(curl -s -X POST "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=${KEYCLOAK_ADMIN}" \
  -d "password=${KEYCLOAK_ADMIN_PASSWORD}" \
  -d "grant_type=password" \
  -d "client_id=admin-cli" | grep -o '"access_token":"[^"]*"' | cut -d':' -f2 | tr -d '"')

if [ -z "$ADMIN_TOKEN" ]; then
    echo "Failed to get admin token"
    exit 1
fi
echo "✅ Admin token acquired"

# Check if realm exists
echo "Checking if ${REALM_NAME} realm exists..."
REALM_EXISTS=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $ADMIN_TOKEN" "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}")

if [ "$REALM_EXISTS" -eq 404 ]; then
    echo "Creating ${REALM_NAME} realm..."
    
    # Create realm with minimal configuration first
    curl -s -X POST "${KEYCLOAK_URL}/admin/realms" \
      -H "Authorization: Bearer $ADMIN_TOKEN" \
      -H "Content-Type: application/json" \
      -d "{\"realm\":\"${REALM_NAME}\", \"enabled\":true}"
    
    # Sleep to allow the realm to be created
    sleep 2
    
    # Update realm with full configuration
    curl -s -X PUT "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}" \
      -H "Authorization: Bearer $ADMIN_TOKEN" \
      -H "Content-Type: application/json" \
      --data-binary @${REALM_FILE}
    
    echo "✅ Realm ${REALM_NAME} created successfully"
else
    echo "✅ Realm ${REALM_NAME} already exists"
fi

# Create frontend client
echo "Creating frontend client..."
curl -s -X POST "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/clients" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"clientId\": \"dive25-frontend\",
    \"name\": \"DIVE25 Frontend\",
    \"enabled\": true,
    \"publicClient\": true,
    \"redirectUris\": [\"${FRONTEND_URL}/*\", \"http://localhost:3000/*\"],
    \"webOrigins\": [\"${FRONTEND_URL}\", \"http://localhost:3000\"],
    \"standardFlowEnabled\": true,
    \"directAccessGrantsEnabled\": true
  }"

# Create API client
echo "Creating API client..."
curl -s -X POST "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/clients" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"clientId\": \"dive25-api\",
    \"name\": \"DIVE25 API\",
    \"enabled\": true,
    \"bearerOnly\": false,
    \"publicClient\": false,
    \"clientAuthenticatorType\": \"client-secret\",
    \"secret\": \"change-me-in-production\",
    \"redirectUris\": [\"${API_URL}/*\", \"http://localhost:3001/*\"],
    \"webOrigins\": [\"${API_URL}\", \"http://localhost:3001\"],
    \"standardFlowEnabled\": true,
    \"serviceAccountsEnabled\": true,
    \"authorizationServicesEnabled\": true
  }"

# Create test users
echo "Creating test users..."

# Create user alice
curl -s -X POST "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/users" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "alice",
    "enabled": true,
    "emailVerified": true,
    "firstName": "Alice",
    "lastName": "Anderson",
    "email": "alice@example.com",
    "attributes": {
      "clearance": ["TS/SCI"],
      "organization": ["US-GOV"]
    }
  }'

# Set password for alice
USER_ID=$(curl -s -H "Authorization: Bearer $ADMIN_TOKEN" "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/users?username=alice" | grep -o '"id":"[^"]*"' | head -1 | cut -d':' -f2 | tr -d '"')
if [ -n "$USER_ID" ]; then
  curl -s -X PUT "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/users/${USER_ID}/reset-password" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
      "type": "password",
      "value": "password",
      "temporary": false
    }'
fi

# Create user bob
curl -s -X POST "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/users" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "bob",
    "enabled": true,
    "emailVerified": true,
    "firstName": "Bob",
    "lastName": "Brown",
    "email": "bob@example.com",
    "attributes": {
      "clearance": ["SECRET"],
      "organization": ["NATO"]
    }
  }'

# Set password for bob
USER_ID=$(curl -s -H "Authorization: Bearer $ADMIN_TOKEN" "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/users?username=bob" | grep -o '"id":"[^"]*"' | head -1 | cut -d':' -f2 | tr -d '"')
if [ -n "$USER_ID" ]; then
  curl -s -X PUT "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/users/${USER_ID}/reset-password" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
      "type": "password",
      "value": "password",
      "temporary": false
    }'
fi

echo "Realm import completed!"
EOF

# Make the script executable
chmod +x "$TEMP_DIR/import-realm.sh"

# Create a temporary container with curl and run the script
echo "Running temporary container to configure Keycloak..."
docker run --rm \
  --network dive-mvp_dive25-network \
  -v "$TEMP_DIR:/tmp/config" \
  curlimages/curl:latest \
  sh /tmp/config/import-realm.sh

# Clean up the temporary directory
rm -rf "$TEMP_DIR"

# Update Kong OIDC configuration to use the configured realm
echo "Updating Kong OIDC configuration to use the ${KEYCLOAK_REALM} realm..."
PLUGIN_ID=$(curl -s ${KONG_ADMIN_URL}/plugins | jq -r '.data[] | select(.name=="oidc-auth") | .id')
if [ -n "$PLUGIN_ID" ]; then
  echo "Deleting existing OIDC plugin with ID: $PLUGIN_ID"
  curl -s -X DELETE ${KONG_ADMIN_URL}/plugins/$PLUGIN_ID
fi

echo "Creating new OIDC plugin with ${KEYCLOAK_REALM} realm..."
curl -s -X POST ${KONG_ADMIN_URL}/plugins \
  -d "name=oidc-auth" \
  -d "config.client_id=dive25-frontend" \
  -d "config.client_secret=change-me-in-production" \
  -d "config.discovery=${INTERNAL_KEYCLOAK_URL}/realms/${KEYCLOAK_REALM}/.well-known/openid-configuration" \
  -d "config.bearer_only=false" \
  -d "config.realm=${KEYCLOAK_REALM}" \
  -d "config.redirect_uri_path=/callback" \
  -d "config.logout_path=/logout" \
  -d "config.redirect_after_logout_uri=https://${FRONTEND_DOMAIN}:${FRONTEND_PORT}" \
  -d "config.scope=openid email profile" \
  -d "config.response_type=code" \
  -d "config.ssl_verify=false" \
  -d "config.token_endpoint_auth_method=client_secret_post" \
  -d "config.introspection_endpoint_auth_method=client_secret_post"

echo "=== Keycloak Configuration Complete ==="
echo "The ${KEYCLOAK_REALM} realm has been created in Keycloak."
echo "Users: alice/password, bob/password"
echo "Kong OIDC plugin has been updated to use the ${KEYCLOAK_REALM} realm."
echo "You should now be able to access Kong at:"
echo "- http://${KONG_DOMAIN}:${KONG_PROXY_PORT}"
echo "- https://${KONG_DOMAIN}:8443" 