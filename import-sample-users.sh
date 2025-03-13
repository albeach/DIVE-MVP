#!/bin/bash
set -e

echo "Importing sample users into Keycloak..."

# Get admin token
TOKEN=$(curl -s -X POST "http://dive25-staging-keycloak:8080/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=admin" \
  -d "password=admin" \
  -d "grant_type=password" \
  -d "client_id=admin-cli" | grep -o '"access_token":"[^"]*"' | cut -d':' -f2 | tr -d '"')

if [ -z "$TOKEN" ]; then
  echo "Failed to get admin token"
  exit 1
fi

echo "Admin token acquired: ${TOKEN:0:10}..."

# Import Alice user
ALICE_USER='{
  "username": "alice",
  "email": "alice@us.gov",
  "firstName": "Alice",
  "lastName": "Johnson",
  "enabled": true,
  "emailVerified": true,
  "credentials": [
    {
      "type": "password",
      "value": "password123",
      "temporary": false
    }
  ],
  "attributes": {
    "countryOfAffiliation": ["USA"],
    "clearance": ["TOP SECRET"],
    "organization": ["Department of Defense"],
    "caveats": ["FVEY", "NATO"],
    "coi": ["OpAlpha", "OpBravo"]
  }
}'

echo "Importing user: alice"
# Check if user exists
EXISTING_USER=$(curl -s -X GET "http://dive25-staging-keycloak:8080/admin/realms/dive25/users?username=alice" \
  -H "Authorization: Bearer $TOKEN")

if [[ "$EXISTING_USER" == "[]" ]]; then
  # Create user
  RESPONSE=$(curl -s -X POST "http://dive25-staging-keycloak:8080/admin/realms/dive25/users" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "$ALICE_USER")
  
  if [[ "$RESPONSE" == *"error"* ]]; then
    echo "Error creating user alice: $RESPONSE"
  else
    echo "User alice created successfully"
  fi
else
  echo "User alice already exists, updating attributes..."
  USER_ID=$(echo "$EXISTING_USER" | grep -o '"id":"[^"]*"' | head -1 | cut -d':' -f2 | tr -d '"')
  
  if [ -n "$USER_ID" ]; then
    # Update user attributes
    RESPONSE=$(curl -s -X PUT "http://dive25-staging-keycloak:8080/admin/realms/dive25/users/$USER_ID" \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json" \
      -d "$ALICE_USER")
    
    if [[ "$RESPONSE" == *"error"* ]]; then
      echo "Error updating user alice: $RESPONSE"
    else
      echo "User alice updated successfully"
    fi
  else
    echo "Failed to extract user ID for alice"
  fi
fi

# Import Bob user
BOB_USER='{
  "username": "bob",
  "email": "bob@mod.uk",
  "firstName": "Bob",
  "lastName": "Smith",
  "enabled": true,
  "emailVerified": true,
  "credentials": [
    {
      "type": "password",
      "value": "password123",
      "temporary": false
    }
  ],
  "attributes": {
    "countryOfAffiliation": ["GBR"],
    "clearance": ["SECRET"],
    "organization": ["Ministry of Defence"],
    "caveats": ["FVEY"],
    "coi": ["OpAlpha"]
  }
}'

echo "Importing user: bob"
# Check if user exists
EXISTING_USER=$(curl -s -X GET "http://dive25-staging-keycloak:8080/admin/realms/dive25/users?username=bob" \
  -H "Authorization: Bearer $TOKEN")

if [[ "$EXISTING_USER" == "[]" ]]; then
  # Create user
  RESPONSE=$(curl -s -X POST "http://dive25-staging-keycloak:8080/admin/realms/dive25/users" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "$BOB_USER")
  
  if [[ "$RESPONSE" == *"error"* ]]; then
    echo "Error creating user bob: $RESPONSE"
  else
    echo "User bob created successfully"
  fi
else
  echo "User bob already exists, updating attributes..."
  USER_ID=$(echo "$EXISTING_USER" | grep -o '"id":"[^"]*"' | head -1 | cut -d':' -f2 | tr -d '"')
  
  if [ -n "$USER_ID" ]; then
    # Update user attributes
    RESPONSE=$(curl -s -X PUT "http://dive25-staging-keycloak:8080/admin/realms/dive25/users/$USER_ID" \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json" \
      -d "$BOB_USER")
    
    if [[ "$RESPONSE" == *"error"* ]]; then
      echo "Error updating user bob: $RESPONSE"
    else
      echo "User bob updated successfully"
    fi
  else
    echo "Failed to extract user ID for bob"
  fi
fi

echo "Sample users import completed"
exit 0 