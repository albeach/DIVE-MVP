#!/bin/bash
#
# DIVE25 - Kong Routes Setup Script
# =================================
#
# This script sets up the Kong routes for the API, Frontend, and Keycloak services.
#

set -e

# Set colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
KONG_ADMIN_URL=${KONG_ADMIN_URL:-"http://localhost:9444"}
BASE_DOMAIN=${BASE_DOMAIN:-"dive25.local"}
INTERNAL_FRONTEND_URL=${INTERNAL_FRONTEND_URL:-"http://frontend:3000"}
INTERNAL_API_URL=${INTERNAL_API_URL:-"http://api:3000"}
INTERNAL_KEYCLOAK_URL=${INTERNAL_KEYCLOAK_URL:-"http://keycloak:8080"}

echo "Using the following configuration:"
echo "Kong Admin URL: $KONG_ADMIN_URL"
echo "Base Domain: $BASE_DOMAIN"
echo "Internal Frontend URL: $INTERNAL_FRONTEND_URL"
echo "Internal API URL: $INTERNAL_API_URL"
echo "Internal Keycloak URL: $INTERNAL_KEYCLOAK_URL"

# Function to create/update a service
create_or_update_service() {
  local name=$1
  local url=$2
  
  echo "Creating/updating service: $name -> $url"
  
  # Check if service exists
  local service_exists=$(curl -s "$KONG_ADMIN_URL/services/$name" | grep -c "id" || echo "0")
  
  if [ "$service_exists" -gt 0 ]; then
    echo "Service $name exists, updating..."
    curl -s -X PATCH "$KONG_ADMIN_URL/services/$name" \
      -d "name=$name" \
      -d "url=$url" > /dev/null
  else
    echo "Service $name does not exist, creating..."
    curl -s -X POST "$KONG_ADMIN_URL/services/" \
      -d "name=$name" \
      -d "url=$url" > /dev/null
  fi
  
  echo "✅ Service $name configured successfully"
}

# Function to create/update a route
create_or_update_route() {
  local name=$1
  local service_name=$2
  local hosts=$3
  local paths=$4
  local strip_path=${5:-true}
  local preserve_host=${6:-false}
  
  echo "Creating/updating route: $name -> $service_name (hosts: $hosts, paths: $paths)"
  
  # Check if route exists
  local route_exists=$(curl -s "$KONG_ADMIN_URL/routes/$name" | grep -c "id" || echo "0")
  
  if [ "$route_exists" -gt 0 ]; then
    echo "Route $name exists, updating..."
    curl -s -X PATCH "$KONG_ADMIN_URL/routes/$name" \
      -d "name=$name" \
      -d "service.name=$service_name" \
      -d "hosts=$hosts" \
      -d "paths=$paths" \
      -d "strip_path=$strip_path" \
      -d "preserve_host=$preserve_host" > /dev/null
  else
    echo "Route $name does not exist, creating..."
    curl -s -X POST "$KONG_ADMIN_URL/routes/" \
      -d "name=$name" \
      -d "service.name=$service_name" \
      -d "hosts=$hosts" \
      -d "paths=$paths" \
      -d "strip_path=$strip_path" \
      -d "preserve_host=$preserve_host" > /dev/null
  fi
  
  echo "✅ Route $name configured successfully"
}

# Function to update OIDC plugin to enable SSL verification
update_oidc_plugin_config() {
  echo "Checking for OIDC plugins to update..."
  
  # Get all OIDC plugins
  OIDC_PLUGINS=$(curl -s http://kong:8001/plugins?name=oidc-auth)
  
  # Check if we have any OIDC plugins
  if echo "$OIDC_PLUGINS" | grep -q "\"data\":\\[\\]"; then
    echo "No OIDC plugins found."
    return 0
  fi
  
  # Extract plugin IDs
  PLUGIN_IDS=$(echo "$OIDC_PLUGINS" | jq -r '.data[].id')
  
  # Update each plugin to enable SSL verification
  for PLUGIN_ID in $PLUGIN_IDS; do
    echo "Updating OIDC plugin $PLUGIN_ID to enable SSL verification..."
    RESULT=$(curl -s -X PATCH http://kong:8001/plugins/$PLUGIN_ID \
      --data "config.ssl_verify=true")
    
    if echo "$RESULT" | grep -q "\"ssl_verify\":true"; then
      echo "Successfully updated OIDC plugin $PLUGIN_ID - SSL verification is now enabled."
    else
      echo "Failed to update OIDC plugin $PLUGIN_ID. Response: $RESULT"
    fi
  done
}

# Configure Keycloak routes
echo "Configuring Keycloak routes..."
  
# Create Keycloak service
create_or_update_service "keycloak-service" "$INTERNAL_KEYCLOAK_URL"
  
# Create Keycloak routes
create_or_update_route "keycloak-domain-route" "keycloak-service" "keycloak.${BASE_DOMAIN}" "/" false true
create_or_update_route "keycloak-auth-route" "keycloak-service" "keycloak.${BASE_DOMAIN}" "/auth" false true
create_or_update_route "keycloak-realms-route" "keycloak-service" "keycloak.${BASE_DOMAIN}" "/realms" false true
create_or_update_route "keycloak-resources-route" "keycloak-service" "keycloak.${BASE_DOMAIN}" "/resources" false true
create_or_update_route "keycloak-js-route" "keycloak-service" "keycloak.${BASE_DOMAIN}" "/js" false true
create_or_update_route "keycloak-admin-route" "keycloak-service" "keycloak.${BASE_DOMAIN}" "/admin" false true
  
echo "✅ Keycloak routes configured successfully"

# Configure API routes
echo "Configuring API routes..."
  
# Create API service
create_or_update_service "api-service" "$INTERNAL_API_URL"
  
# Create API routes
create_or_update_route "api-domain-route" "api-service" "api.${BASE_DOMAIN}" "/" true false
  
echo "✅ API routes configured successfully"

# Configure Frontend routes
echo "Configuring Frontend routes..."
  
# Create Frontend service
create_or_update_service "frontend-service" "$INTERNAL_FRONTEND_URL"
  
# Create Frontend routes
create_or_update_route "frontend-domain-route" "frontend-service" "frontend.${BASE_DOMAIN}" "/" true false
create_or_update_route "root-domain-route" "frontend-service" "${BASE_DOMAIN}" "/" true false
  
echo "✅ Frontend routes configured successfully"

# After all routes and plugins have been created,
# update OIDC plugin configurations to enable SSL verification
update_oidc_plugin_config

echo -e "${GREEN}✅ All Kong routes configured successfully${NC}" 

echo "Kong configuration completed successfully!" 