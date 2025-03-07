#!/bin/sh
# keycloak/configure-keycloak.sh

# Get Internal and Public Keycloak URLs from environment variables
INTERNAL_KEYCLOAK_URL=${KEYCLOAK_URL}
PUBLIC_KEYCLOAK_URL=${PUBLIC_KEYCLOAK_URL}

echo "Internal Keycloak URL: ${INTERNAL_KEYCLOAK_URL}"
echo "Public Keycloak URL: ${PUBLIC_KEYCLOAK_URL}"

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

# Import realm if not exists
echo "Checking if dive25 realm exists..."
REALM_EXISTS=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $ADMIN_TOKEN" ${INTERNAL_KEYCLOAK_URL}/admin/realms/dive25)
echo "Realm exists check response code: $REALM_EXISTS"

if [ "$REALM_EXISTS" -eq 404 ]; then
    echo "Creating dive25 realm..."
    # Validate the realm export file
    if [ ! -f "/realm-export.json" ]; then
        echo "ERROR: Realm export file not found at /realm-export.json"
        exit 1
    fi
    
    echo "Realm export file exists, verifying content..."
    if ! grep -q "\"realm\": \"dive25\"" /realm-export.json; then
        echo "ERROR: Realm export file does not contain a dive25 realm configuration"
        exit 1
    fi
    
    # Create the realm with detailed error handling
    RESPONSE=$(curl -s -X POST "${INTERNAL_KEYCLOAK_URL}/admin/realms" \
      -H "Authorization: Bearer $ADMIN_TOKEN" \
      -H "Content-Type: application/json" \
      --data-binary @/realm-export.json)
    
    echo "Realm creation response: $RESPONSE"
    
    if [[ "$RESPONSE" == *"error"* ]]; then
        echo "Error creating realm: $RESPONSE"
        # Retry with a simpler realm configuration
        echo "Attempting to create a minimal realm..."
        MINIMAL_REALM="{\"realm\":\"dive25\",\"enabled\":true}"
        echo "$MINIMAL_REALM" > /tmp/minimal-realm.json
        
        RETRY_RESPONSE=$(curl -s -X POST "${INTERNAL_KEYCLOAK_URL}/admin/realms" \
          -H "Authorization: Bearer $ADMIN_TOKEN" \
          -H "Content-Type: application/json" \
          --data-binary @/tmp/minimal-realm.json)
        
        echo "Minimal realm creation response: $RETRY_RESPONSE"
        if [[ "$RETRY_RESPONSE" == *"error"* ]]; then
            echo "Failed to create even a minimal realm. Aborting."
            exit 1
        else
            echo "Successfully created minimal realm. Continuing with configuration..."
        fi
    else
        echo "Realm created successfully"
    fi
else
    echo "Realm already exists"
fi

# Import identity providers
echo "Importing identity providers..."
for file in /identity-providers/*.json; do
    echo "Processing $file"
    
    # Extract the identity provider alias from the file
    IDP_ALIAS=$(grep -o '"alias": "[^"]*"' "$file" | cut -d':' -f2 | tr -d '"' | tr -d ' ')
    
    # Check if the identity provider already exists
    IDP_EXISTS=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $ADMIN_TOKEN" "${INTERNAL_KEYCLOAK_URL}/admin/realms/dive25/identity-provider/instances/$IDP_ALIAS")
    
    if [ "$IDP_EXISTS" -eq 404 ]; then
        echo "Creating identity provider $IDP_ALIAS..."
        curl -s -X POST "${INTERNAL_KEYCLOAK_URL}/admin/realms/dive25/identity-provider/instances" \
          -H "Authorization: Bearer $ADMIN_TOKEN" \
          -H "Content-Type: application/json" \
          --data-binary @"$file"
        echo "Identity provider $IDP_ALIAS created"
    else
        echo "Identity provider $IDP_ALIAS already exists, updating..."
        curl -s -X PUT "${INTERNAL_KEYCLOAK_URL}/admin/realms/dive25/identity-provider/instances/$IDP_ALIAS" \
          -H "Authorization: Bearer $ADMIN_TOKEN" \
          -H "Content-Type: application/json" \
          --data-binary @"$file"
        echo "Identity provider $IDP_ALIAS updated"
    fi
done

# Import frontend client
echo "Importing frontend client..."
FRONTEND_CLIENT_ID="dive25-frontend"

# Function to validate URI format
validate_uri() {
  local uri="$1"
  local description="$2"
  echo "Validating URI: $uri (${description})"
  
  # Basic URI validation - check for scheme, host, etc.
  if [[ ! "$uri" =~ ^https?:// ]]; then
    echo "ERROR: Invalid URI format for ${description}: $uri (missing http:// or https:// scheme)"
    return 1
  fi
  
  # Check for invalid characters or spaces
  if [[ "$uri" =~ [[:space:]] ]]; then
    echo "ERROR: URI contains spaces or invalid characters: $uri"
    return 1
  fi
  
  echo "URI validation passed for ${description}: $uri"
  return 0
}

# Clean up URLs and validate them
PUBLIC_FRONTEND_URL_CLEAN=$(echo "${PUBLIC_FRONTEND_URL}" | sed 's|/*$||')
CALLBACK_URIS=""

# Add frontend URL with wildcard
FRONTEND_WILDCARD="${PUBLIC_FRONTEND_URL_CLEAN}/*"
if validate_uri "${PUBLIC_FRONTEND_URL_CLEAN}" "Frontend URL"; then
  CALLBACK_URIS="\"${FRONTEND_WILDCARD}\""
  echo "Added frontend wildcard URI: ${FRONTEND_WILDCARD}"
fi

# Add standard localhost URIs
LOCALHOST_3000="http://localhost:3000/*"
LOCALHOST_3001="http://localhost:3001/*"
CALLBACK_URIS="${CALLBACK_URIS}, \"${LOCALHOST_3000}\", \"${LOCALHOST_3001}\""
echo "Added localhost URIs: ${LOCALHOST_3000}, ${LOCALHOST_3001}"

# Add Kong callback
KONG_CALLBACK="https://kong:8443/callback"
if validate_uri "$KONG_CALLBACK" "Kong callback"; then
  CALLBACK_URIS="${CALLBACK_URIS}, \"${KONG_CALLBACK}\""
  echo "Added Kong callback URI: ${KONG_CALLBACK}"
fi

# Construct JSON array of redirect URIs
REDIRECT_URIS_JSON="[${CALLBACK_URIS}]"  # Wrap in brackets
echo "Final redirect URIs JSON: ${REDIRECT_URIS_JSON}"

# Add client using a safer approach with a temporary file
echo "Creating frontend client JSON configuration..."
cat > /tmp/frontend-client.json << EOF
{
  "clientId": "${FRONTEND_CLIENT_ID}",
  "rootUrl": "${PUBLIC_FRONTEND_URL_CLEAN}",
  "adminUrl": "${PUBLIC_FRONTEND_URL_CLEAN}",
  "surrogateAuthRequired": false,
  "enabled": true,
  "alwaysDisplayInConsole": false,
  "clientAuthenticatorType": "client-secret",
  "redirectUris": ${REDIRECT_URIS_JSON},
  "webOrigins": [
    "${PUBLIC_FRONTEND_URL_CLEAN}",
    "http://localhost:3000",
    "http://localhost:3001",
    "+"
  ],
  "notBefore": 0,
  "bearerOnly": false,
  "consentRequired": false,
  "standardFlowEnabled": true,
  "implicitFlowEnabled": false,
  "directAccessGrantsEnabled": true,
  "serviceAccountsEnabled": false,
  "publicClient": true,
  "frontchannelLogout": false,
  "protocol": "openid-connect",
  "fullScopeAllowed": true
}
EOF

# Validate the JSON file
echo "Validating frontend client JSON..."
if ! grep -q "redirectUris" /tmp/frontend-client.json; then
  echo "ERROR: JSON validation failed - redirectUris not found in generated JSON"
  cat /tmp/frontend-client.json
  exit 1
fi

# Check if the client already exists
FRONTEND_CLIENT_EXISTS=$(curl -s -H "Authorization: Bearer $ADMIN_TOKEN" "${INTERNAL_KEYCLOAK_URL}/admin/realms/dive25/clients" | grep -c "\"clientId\":\"$FRONTEND_CLIENT_ID\"")
    
if [ "$FRONTEND_CLIENT_EXISTS" -eq 0 ]; then
    echo "Creating client $FRONTEND_CLIENT_ID..."
    RESPONSE=$(curl -s -X POST "${INTERNAL_KEYCLOAK_URL}/admin/realms/dive25/clients" \
        -H "Authorization: Bearer $ADMIN_TOKEN" \
        -H "Content-Type: application/json" \
        --data-binary @/tmp/frontend-client.json)
    
    if [[ "$RESPONSE" == *"error"* ]]; then
        echo "Error creating client: $RESPONSE"
        exit 1
    else
        echo "Client $FRONTEND_CLIENT_ID created successfully"
    fi
else
    echo "Client $FRONTEND_CLIENT_ID already exists, updating..."
    # Get the client's internal ID
    FRONTEND_CLIENT_INTERNAL_ID=$(curl -s -H "Authorization: Bearer $ADMIN_TOKEN" "${INTERNAL_KEYCLOAK_URL}/admin/realms/dive25/clients" | grep -o "\"id\":\"[^\"]*\",\"clientId\":\"$FRONTEND_CLIENT_ID\"" | cut -d':' -f2 | cut -d',' -f1 | tr -d '"')
    
    RESPONSE=$(curl -s -X PUT "${INTERNAL_KEYCLOAK_URL}/admin/realms/dive25/clients/$FRONTEND_CLIENT_INTERNAL_ID" \
        -H "Authorization: Bearer $ADMIN_TOKEN" \
        -H "Content-Type: application/json" \
        --data-binary @/tmp/frontend-client.json)
    
    if [[ "$RESPONSE" == *"error"* ]]; then
        echo "Error updating client: $RESPONSE"
        exit 1
    else
        echo "Client $FRONTEND_CLIENT_ID updated successfully"
    fi
fi

# Import API client
echo "Importing API client..."
API_CLIENT_ID="dive25-api"

# Validate and clean API URL
PUBLIC_API_URL_CLEAN=$(echo "${PUBLIC_API_URL}" | sed 's|/*$||')
validate_uri "${PUBLIC_API_URL_CLEAN}" "API URL"

# Create temporary file for API client
cat > /tmp/api-client.json << EOF
{
  "clientId": "${API_CLIENT_ID}",
  "rootUrl": "${PUBLIC_API_URL_CLEAN}",
  "adminUrl": "${PUBLIC_API_URL_CLEAN}",
  "surrogateAuthRequired": false,
  "enabled": true,
  "alwaysDisplayInConsole": false,
  "clientAuthenticatorType": "client-secret",
  "secret": "change-me-in-production",
  "redirectUris": [
    "${PUBLIC_API_URL_CLEAN}/*"
  ],
  "webOrigins": [
    "${PUBLIC_API_URL_CLEAN}"
  ],
  "notBefore": 0,
  "bearerOnly": true,
  "consentRequired": false,
  "standardFlowEnabled": false,
  "implicitFlowEnabled": false,
  "directAccessGrantsEnabled": false,
  "serviceAccountsEnabled": true,
  "publicClient": false,
  "frontchannelLogout": false,
  "protocol": "openid-connect",
  "fullScopeAllowed": true
}
EOF

# Validate the JSON file
echo "Validating API client JSON..."
if ! grep -q "redirectUris" /tmp/api-client.json; then
  echo "ERROR: JSON validation failed - redirectUris not found in generated JSON"
  cat /tmp/api-client.json
  exit 1
fi

# Check if the client already exists
API_CLIENT_EXISTS=$(curl -s -H "Authorization: Bearer $ADMIN_TOKEN" "${INTERNAL_KEYCLOAK_URL}/admin/realms/dive25/clients" | grep -c "\"clientId\":\"$API_CLIENT_ID\"")
    
if [ "$API_CLIENT_EXISTS" -eq 0 ]; then
    echo "Creating client $API_CLIENT_ID..."
    RESPONSE=$(curl -s -X POST "${INTERNAL_KEYCLOAK_URL}/admin/realms/dive25/clients" \
        -H "Authorization: Bearer $ADMIN_TOKEN" \
        -H "Content-Type: application/json" \
        --data-binary @/tmp/api-client.json)
    
    if [[ "$RESPONSE" == *"error"* ]]; then
        echo "Error creating client: $RESPONSE"
        exit 1
    else
        echo "Client $API_CLIENT_ID created successfully"
    fi
else
    echo "Client $API_CLIENT_ID already exists, updating..."
    # Get the client's internal ID
    API_CLIENT_INTERNAL_ID=$(curl -s -H "Authorization: Bearer $ADMIN_TOKEN" "${INTERNAL_KEYCLOAK_URL}/admin/realms/dive25/clients" | grep -o "\"id\":\"[^\"]*\",\"clientId\":\"$API_CLIENT_ID\"" | cut -d':' -f2 | cut -d',' -f1 | tr -d '"')
    
    RESPONSE=$(curl -s -X PUT "${INTERNAL_KEYCLOAK_URL}/admin/realms/dive25/clients/$API_CLIENT_INTERNAL_ID" \
        -H "Authorization: Bearer $ADMIN_TOKEN" \
        -H "Content-Type: application/json" \
        --data-binary @/tmp/api-client.json)
    
    if [[ "$RESPONSE" == *"error"* ]]; then
        echo "Error updating client: $RESPONSE"
        exit 1
    else
        echo "Client $API_CLIENT_ID updated successfully"
    fi
fi

# Import test users - use curl for each user individually instead of awk
echo "Importing test users from /test-users/sample-users.json..."

# Alice user
echo "Creating user alice..."
ALICE_USER=$(cat <<EOF
{
    "username": "alice",
    "email": "alice@example.com",
    "firstName": "Alice",
    "lastName": "Johnson",
    "enabled": true,
    "emailVerified": true,
    "credentials": [
        {
            "type": "password",
            "value": "password",
            "temporary": false
        }
    ],
    "attributes": {
        "countryOfAffiliation": ["us"],
        "clearance": ["top_secret"],
        "organization": ["dod"],
        "caveats": ["sci"],
        "coi": ["alpha"]
    },
    "realmRoles": ["user", "admin"]
}
EOF
)

curl -s -X POST "${INTERNAL_KEYCLOAK_URL}/admin/realms/dive25/users" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$ALICE_USER"
echo "User alice created"

# Bob user
echo "Creating user bob..."
BOB_USER=$(cat <<EOF
{
    "username": "bob",
    "email": "bob@example.com",
    "firstName": "Bob",
    "lastName": "Smith",
    "enabled": true,
    "emailVerified": true,
    "credentials": [
        {
            "type": "password",
            "value": "password",
            "temporary": false
        }
    ],
    "attributes": {
        "countryOfAffiliation": ["uk"],
        "clearance": ["secret"],
        "organization": ["mod"],
        "caveats": ["noforn"],
        "coi": ["beta"]
    },
    "realmRoles": ["user"]
}
EOF
)

curl -s -X POST "${INTERNAL_KEYCLOAK_URL}/admin/realms/dive25/users" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$BOB_USER"
echo "User bob created"

# Charlie user
echo "Creating user charlie..."
CHARLIE_USER=$(cat <<EOF
{
    "username": "charlie",
    "email": "charlie@example.com",
    "firstName": "Charlie",
    "lastName": "Brown",
    "enabled": true,
    "emailVerified": true,
    "credentials": [
        {
            "type": "password",
            "value": "password",
            "temporary": false
        }
    ],
    "attributes": {
        "countryOfAffiliation": ["ca"],
        "clearance": ["confidential"],
        "organization": ["goc"],
        "caveats": ["rel_to_usa"],
        "coi": ["gamma"]
    },
    "realmRoles": ["user"]
}
EOF
)

curl -s -X POST "${INTERNAL_KEYCLOAK_URL}/admin/realms/dive25/users" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$CHARLIE_USER"
echo "User charlie created"

# Diana user
echo "Creating user diana..."
DIANA_USER=$(cat <<EOF
{
    "username": "diana",
    "email": "diana@example.com",
    "firstName": "Diana",
    "lastName": "Prince",
    "enabled": true,
    "emailVerified": true,
    "credentials": [
        {
            "type": "password",
            "value": "password",
            "temporary": false
        }
    ],
    "attributes": {
        "countryOfAffiliation": ["fr"],
        "clearance": ["restricted"],
        "organization": ["dgse"],
        "caveats": ["rel_nato"],
        "coi": ["delta"]
    },
    "realmRoles": ["user"]
}
EOF
)

curl -s -X POST "${INTERNAL_KEYCLOAK_URL}/admin/realms/dive25/users" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$DIANA_USER"
echo "User diana created"

# Update the realm settings to use the public URLs
echo "Updating realm settings to use public URLs..."
REALM_REPRESENTATION=$(curl -s -H "Authorization: Bearer $ADMIN_TOKEN" "${INTERNAL_KEYCLOAK_URL}/admin/realms/dive25")

# Create a temporary file with the updated settings
TMP_REALM_FILE=$(mktemp)
echo "$REALM_REPRESENTATION" > "$TMP_REALM_FILE"

# Update the realm settings with public URLs
sed -i "s|\"frontendUrl\": \"[^\"]*\"|\"frontendUrl\": \"${PUBLIC_KEYCLOAK_URL}\"|g" "$TMP_REALM_FILE"
sed -i "s|\"webOrigins\": \\[|\"webOrigins\": \\[ \"${PUBLIC_FRONTEND_URL}\", \"${PUBLIC_API_URL}\", |g" "$TMP_REALM_FILE"

# Update the realm settings
curl -s -X PUT "${INTERNAL_KEYCLOAK_URL}/admin/realms/dive25" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  --data-binary @"$TMP_REALM_FILE"

# Clean up temporary file
rm -f "$TMP_REALM_FILE"

echo "Keycloak configuration completed successfully!"