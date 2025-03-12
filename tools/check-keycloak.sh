#!/bin/bash
# Script to check Keycloak health and perform API operations

set -e

# Default values
KEYCLOAK_URL=${KEYCLOAK_URL:-"http://keycloak:8080"}
KEYCLOAK_ADMIN=${KEYCLOAK_ADMIN:-"admin"}
KEYCLOAK_ADMIN_PASSWORD=${KEYCLOAK_ADMIN_PASSWORD:-"admin"}
KEYCLOAK_REALM=${KEYCLOAK_REALM:-"dive25"}
OPERATION=${1:-"health"}

# Show usage information
show_usage() {
  echo "Usage: check-keycloak [OPERATION]"
  echo ""
  echo "Operations:"
  echo "  health       - Check basic Keycloak health"
  echo "  realm        - Check if realm exists"
  echo "  token        - Get admin token"
  echo "  users        - List users in realm"
  echo "  clients      - List clients in realm"
  echo "  create-realm - Create realm if it doesn't exist"
  echo "  ready-marker - Create realm-ready marker file"
  echo ""
  echo "Environment variables:"
  echo "  KEYCLOAK_URL             (default: http://keycloak:8080)"
  echo "  KEYCLOAK_ADMIN           (default: admin)"
  echo "  KEYCLOAK_ADMIN_PASSWORD  (default: admin)"
  echo "  KEYCLOAK_REALM           (default: dive25)"
  echo ""
  echo "Examples:"
  echo "  check-keycloak health"
  echo "  KEYCLOAK_URL=http://localhost:8080 check-keycloak token"
}

# Check Keycloak health
check_health() {
  echo "Checking Keycloak health at $KEYCLOAK_URL..."
  
  # Check if base URL is accessible
  STATUS_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$KEYCLOAK_URL")
  if [ "$STATUS_CODE" = "200" ]; then
    echo "✅ Keycloak base URL is accessible (HTTP 200)"
    
    # Check if OpenID configuration is available
    OPENID_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$KEYCLOAK_URL/realms/master/.well-known/openid-configuration")
    if [ "$OPENID_STATUS" = "200" ]; then
      echo "✅ Keycloak OpenID configuration is accessible (HTTP 200)"
      echo "✅ Keycloak appears to be healthy!"
      return 0
    else
      echo "❌ Keycloak OpenID configuration returned: HTTP $OPENID_STATUS"
    fi
  else
    echo "❌ Keycloak base URL returned: HTTP $STATUS_CODE"
  fi
  return 1
}

# Get admin token
get_admin_token() {
  echo "Getting admin token from $KEYCLOAK_URL..."
  
  # Get token
  RESPONSE=$(curl -s -X POST "$KEYCLOAK_URL/realms/master/protocol/openid-connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "username=$KEYCLOAK_ADMIN" \
    -d "password=$KEYCLOAK_ADMIN_PASSWORD" \
    -d "grant_type=password" \
    -d "client_id=admin-cli")
  
  # Extract token
  TOKEN=$(echo "$RESPONSE" | jq -r '.access_token')
  
  if [ "$TOKEN" != "null" ] && [ -n "$TOKEN" ]; then
    echo "✅ Successfully obtained admin token"
    echo "$TOKEN"
    return 0
  else
    echo "❌ Failed to get admin token: $RESPONSE"
    return 1
  fi
}

# Check if realm exists
check_realm() {
  echo "Checking if realm $KEYCLOAK_REALM exists..."
  
  # First try direct HTTP check
  REALM_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$KEYCLOAK_URL/realms/$KEYCLOAK_REALM")
  
  if [ "$REALM_STATUS" = "200" ]; then
    echo "✅ Realm $KEYCLOAK_REALM exists (HTTP 200)"
    return 0
  else
    echo "⚠️ Realm $KEYCLOAK_REALM HTTP check: $REALM_STATUS"
    
    # Get admin token and try with admin API
    TOKEN=$(get_admin_token)
    if [ -n "$TOKEN" ]; then
      ADMIN_CHECK=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "Authorization: Bearer $TOKEN" \
        "$KEYCLOAK_URL/admin/realms/$KEYCLOAK_REALM")
      
      if [ "$ADMIN_CHECK" = "200" ]; then
        echo "✅ Realm $KEYCLOAK_REALM exists (Admin API)"
        return 0
      else
        echo "❌ Realm $KEYCLOAK_REALM does not exist (Admin API: $ADMIN_CHECK)"
      fi
    fi
  fi
  
  return 1
}

# List users in realm
list_users() {
  echo "Listing users in realm $KEYCLOAK_REALM..."
  
  # Get admin token
  TOKEN=$(get_admin_token)
  if [ -z "$TOKEN" ]; then
    return 1
  fi
  
  # Get users
  USERS=$(curl -s \
    -H "Authorization: Bearer $TOKEN" \
    "$KEYCLOAK_URL/admin/realms/$KEYCLOAK_REALM/users")
  
  echo "$USERS" | jq '.'
}

# List clients in realm
list_clients() {
  echo "Listing clients in realm $KEYCLOAK_REALM..."
  
  # Get admin token
  TOKEN=$(get_admin_token)
  if [ -z "$TOKEN" ]; then
    return 1
  fi
  
  # Get clients
  CLIENTS=$(curl -s \
    -H "Authorization: Bearer $TOKEN" \
    "$KEYCLOAK_URL/admin/realms/$KEYCLOAK_REALM/clients")
  
  echo "$CLIENTS" | jq '.'
}

# Create realm if it doesn't exist
create_realm() {
  echo "Creating realm $KEYCLOAK_REALM if it doesn't exist..."
  
  # Check if realm exists first
  if check_realm; then
    echo "✅ Realm already exists, no need to create it"
    return 0
  fi
  
  # Get admin token
  TOKEN=$(get_admin_token)
  if [ -z "$TOKEN" ]; then
    return 1
  fi
  
  # Create realm
  REALM_JSON="{
    \"realm\": \"$KEYCLOAK_REALM\",
    \"enabled\": true,
    \"displayName\": \"DIVE25 Document Access System\"
  }"
  
  CREATE_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST "$KEYCLOAK_URL/admin/realms" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "$REALM_JSON")
  
  if [ "$CREATE_STATUS" = "201" ]; then
    echo "✅ Successfully created realm $KEYCLOAK_REALM"
    return 0
  else
    echo "❌ Failed to create realm: HTTP $CREATE_STATUS"
    return 1
  fi
}

# Create realm-ready marker file
create_ready_marker() {
  echo "Creating realm-ready marker file..."
  
  # Create directory if it doesn't exist
  mkdir -p /tmp/keycloak-config
  
  # Create marker file
  echo "$KEYCLOAK_REALM" > /tmp/keycloak-config/realm-ready
  echo "✅ Created realm-ready marker file at /tmp/keycloak-config/realm-ready"
  
  # Attempt to create the marker in the Keycloak volume if possible
  if [ -d "/keycloak-data" ]; then
    mkdir -p /keycloak-data
    echo "$KEYCLOAK_REALM" > /keycloak-data/realm-ready
    echo "✅ Created realm-ready marker file in Keycloak volume"
  fi
  
  return 0
}

# Main script execution
case "$OPERATION" in
  "health")
    check_health
    ;;
  "realm")
    check_realm
    ;;
  "token")
    get_admin_token
    ;;
  "users")
    list_users
    ;;
  "clients")
    list_clients
    ;;
  "create-realm")
    create_realm
    ;;
  "ready-marker")
    create_ready_marker
    ;;
  "help"|"-h"|"--help")
    show_usage
    ;;
  *)
    echo "Unknown operation: $OPERATION"
    show_usage
    exit 1
    ;;
esac 