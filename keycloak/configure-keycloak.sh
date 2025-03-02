#!/bin/sh
# keycloak/configure-keycloak.sh

# Wait for Keycloak to be ready
echo "Waiting for Keycloak to be ready..."
while ! curl -s http://keycloak:8080/health/ready; do
    echo "Keycloak not ready yet... waiting 5 seconds"
    sleep 5
done
echo "Keycloak is ready!"

# Get admin token
echo "Getting admin token..."
ADMIN_TOKEN=$(curl -s -X POST "http://keycloak:8080/realms/master/protocol/openid-connect/token" \
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
REALM_EXISTS=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $ADMIN_TOKEN" http://keycloak:8080/admin/realms/dive25)
if [ "$REALM_EXISTS" -eq 404 ]; then
    echo "Creating dive25 realm..."
    curl -s -X POST "http://keycloak:8080/admin/realms" \
      -H "Authorization: Bearer $ADMIN_TOKEN" \
      -H "Content-Type: application/json" \
      --data-binary @/realm-export.json
    echo "Realm created"
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
    IDP_EXISTS=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $ADMIN_TOKEN" "http://keycloak:8080/admin/realms/dive25/identity-provider/instances/$IDP_ALIAS")
    
    if [ "$IDP_EXISTS" -eq 404 ]; then
        echo "Creating identity provider $IDP_ALIAS..."
        curl -s -X POST "http://keycloak:8080/admin/realms/dive25/identity-provider/instances" \
          -H "Authorization: Bearer $ADMIN_TOKEN" \
          -H "Content-Type: application/json" \
          --data-binary @"$file"
        echo "Identity provider $IDP_ALIAS created"
    else
        echo "Identity provider $IDP_ALIAS already exists, updating..."
        curl -s -X PUT "http://keycloak:8080/admin/realms/dive25/identity-provider/instances/$IDP_ALIAS" \
          -H "Authorization: Bearer $ADMIN_TOKEN" \
          -H "Content-Type: application/json" \
          --data-binary @"$file"
        echo "Identity provider $IDP_ALIAS updated"
    fi
done

# Import test users
echo "Importing test users from /test-users/sample-users.json..."
for user in $(grep -o '"username": "[^"]*"' /test-users/sample-users.json | cut -d':' -f2 | tr -d '"' | tr -d ' '); do
    echo "Processing user $user"
    
    # Check if user exists
    USER_EXISTS=$(curl -s -H "Authorization: Bearer $ADMIN_TOKEN" "http://keycloak:8080/admin/realms/dive25/users?username=$user" | grep -c "username")
    
    if [ "$USER_EXISTS" -eq 0 ]; then
        echo "Creating user $user..."
        # Extract the user JSON object
        USER_JSON=$(grep -A 100 "\"username\": \"$user\"" /test-users/sample-users.json | awk 'BEGIN{c=1} {if($0~/{/) c++; if($0~/}/) c--; print; if(c==0) exit}')
        
        # Create user
        curl -s -X POST "http://keycloak:8080/admin/realms/dive25/users" \
          -H "Authorization: Bearer $ADMIN_TOKEN" \
          -H "Content-Type: application/json" \
          -d "$USER_JSON"
        echo "User $user created"
    else
        echo "User $user already exists"
    fi
done

echo "Keycloak configuration completed successfully!"