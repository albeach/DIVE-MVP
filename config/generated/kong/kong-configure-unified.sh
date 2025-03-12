#!/bin/bash
#
# DIVE25 - Unified Kong Gateway Configuration Script
# =================================================
#
# This script consolidates all Kong configuration tasks in one place:
# - OIDC authentication setup with Keycloak
# - DNS resolution for services
# - Port 8443 configuration
# - Route creation and management
# - SSL certificate setup
# - Health checks and status monitoring
# - Environment processing
#
# Usage:
#   ./kong-configure-unified.sh [command]
#
# Commands:
#   oidc           - Configure OIDC authentication with Keycloak
#   dns-reset      - Reset Kong's DNS cache to ensure proper service resolution
#   port-8443      - Configure Kong routes for port 8443
#   ssl            - Set up SSL certificates for Kong
#   status         - Check Kong and service status
#   troubleshoot   - Perform basic troubleshooting
#   all            - Run all configuration steps (default)
#   help           - Display this help message
#
# Environment Variables:
#   KONG_ADMIN_URL  - Kong Admin API URL (default: http://localhost:9444)
#   BASE_DOMAIN     - Base domain for services (default: dive25.local)
#   KONG_CONTAINER  - Name of Kong container (default: dive25-kong)
#   FRONTEND_CONTAINER - Name of frontend container (default: dive25-frontend)
#   API_CONTAINER   - Name of API container (default: dive25-api)
#   KEYCLOAK_CONTAINER - Name of Keycloak container (default: dive25-keycloak)

set -e

# Set colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
KONG_ADMIN_URL=${KONG_ADMIN_URL:-"http://kong:8001"}
BASE_DOMAIN=${BASE_DOMAIN:-"dive25.local"}
KONG_CONTAINER=${KONG_CONTAINER:-dive25-kong}
FRONTEND_CONTAINER=${FRONTEND_CONTAINER:-dive25-frontend}
API_CONTAINER=${API_CONTAINER:-dive25-api}
KEYCLOAK_CONTAINER=${KEYCLOAK_CONTAINER:-dive25-keycloak}
INTERNAL_FRONTEND_URL=${INTERNAL_FRONTEND_URL:-"http://frontend:3000"}
INTERNAL_API_URL=${INTERNAL_API_URL:-"http://api:3000"}
INTERNAL_KEYCLOAK_URL=${INTERNAL_KEYCLOAK_URL:-"http://keycloak:8080"}
PUBLIC_KEYCLOAK_URL=${PUBLIC_KEYCLOAK_URL:-"https://keycloak.$BASE_DOMAIN:8443"}
PUBLIC_FRONTEND_URL=${PUBLIC_FRONTEND_URL:-"https://frontend.$BASE_DOMAIN:8443"}
PUBLIC_API_URL=${PUBLIC_API_URL:-"https://api.$BASE_DOMAIN:8443"}
KEYCLOAK_REALM=${KEYCLOAK_REALM:-"dive25"}
KEYCLOAK_CLIENT_ID_FRONTEND=${KEYCLOAK_CLIENT_ID_FRONTEND:-"dive25-frontend"}
KEYCLOAK_CLIENT_ID_API=${KEYCLOAK_CLIENT_ID_API:-"dive25-api"}
KEYCLOAK_CLIENT_SECRET=${KEYCLOAK_CLIENT_SECRET:-"change-me-in-production"}
MAX_RETRIES=20
RETRY_INTERVAL=5

# Load environment variables if they exist
load_environment_variables() {
  echo "Checking for environment variables..."
  
  if [ -f "/.env" ]; then
    echo "Loading environment variables from /.env"
    source /.env
  elif [ -f "/app/.env" ]; then
    echo "Loading environment variables from /app/.env"
    source /app/.env
  elif [ -f ".env" ]; then
    echo "Loading environment variables from .env"
    source .env
  else
    echo "No .env file found, using default values"
  fi
  
  # Force HTTP protocol for internal Keycloak communication
  if [[ "$INTERNAL_KEYCLOAK_URL" == "https://"* ]]; then
    echo "Converting internal Keycloak URL from HTTPS to HTTP to avoid SSL issues"
    INTERNAL_KEYCLOAK_URL=${INTERNAL_KEYCLOAK_URL/https:\/\//http:\/\/}
  fi
  
  echo -e "${BLUE}Using the following configuration:${NC}"
  echo "Kong Admin URL: $KONG_ADMIN_URL"
  echo "Base Domain: $BASE_DOMAIN"
  echo "Kong Container: $KONG_CONTAINER"
  echo "Frontend Container: $FRONTEND_CONTAINER"
  echo "API Container: $API_CONTAINER"
  echo "Keycloak Container: $KEYCLOAK_CONTAINER"
  echo "Internal Keycloak URL: $INTERNAL_KEYCLOAK_URL"
  echo "Public Keycloak URL: $PUBLIC_KEYCLOAK_URL"
  echo "Keycloak Realm: $KEYCLOAK_REALM"
}

# Function to check if Kong is alive
check_kong_health() {
  echo -e "${BLUE}Checking if Kong is alive...${NC}"
  if curl -s $KONG_ADMIN_URL > /dev/null; then
    echo -e "${GREEN}✅ Kong Admin API is accessible at $KONG_ADMIN_URL${NC}"
    return 0
  else
    echo -e "${RED}❌ Cannot connect to Kong Admin API at $KONG_ADMIN_URL${NC}"
    echo "Make sure Kong is running and the Admin API is accessible"
    return 1
  fi
}

# Function to wait for Kong to become healthy
wait_for_kong() {
  echo "Waiting for Kong Admin API to be ready..."
  local retry=0
  while [ $retry -lt $MAX_RETRIES ]; do
    if curl -s -o /dev/null -w "%{http_code}" "$KONG_ADMIN_URL" | grep -q "200"; then
      echo "✅ Kong Admin API is ready"
      return 0
    fi
    retry=$((retry+1))
    echo "Attempt $retry/$MAX_RETRIES: Kong Admin API not ready yet, waiting $RETRY_INTERVAL seconds..."
    sleep $RETRY_INTERVAL
  done
  echo "❌ Kong Admin API did not become ready after $MAX_RETRIES attempts"
  return 1
}

# Function to check for realm marker file
check_keycloak_realm_ready() {
  echo "Checking if Keycloak realm is ready..."
  
  # First check the marker file
  if [ -f "/tmp/keycloak-config/realm-ready" ]; then
    echo "✅ Found realm marker file"
    return 0
  fi
  
  # Then try direct check with Keycloak
  local retry=0
  while [ $retry -lt $MAX_RETRIES ]; do
    local status_code=$(curl -s -o /dev/null -w "%{http_code}" "${INTERNAL_KEYCLOAK_URL}/realms/${KEYCLOAK_REALM}")
    
    if [ "$status_code" == "200" ]; then
      echo "✅ Keycloak realm ${KEYCLOAK_REALM} is accessible"
      # Create marker file for future reference
      mkdir -p /tmp/keycloak-config
      echo "${KEYCLOAK_REALM}" > /tmp/keycloak-config/realm-ready
      return 0
    fi
    
    retry=$((retry+1))
    echo "Attempt $retry/$MAX_RETRIES: Keycloak realm not ready yet, waiting $RETRY_INTERVAL seconds..."
    sleep $RETRY_INTERVAL
  done
  
  echo "⚠️ Could not verify Keycloak realm readiness after $MAX_RETRIES attempts"
  echo "Will attempt to configure Kong anyway, but routes to Keycloak may not work correctly"
  return 1
}

# Function to create/update a service
create_or_update_service() {
  local name=$1
  local url=$2
  
  echo "Creating/updating service: $name -> $url"
  
  # Check if service exists
  local service_exists=$(curl -s "$KONG_ADMIN_URL/services/$name" | grep -c "id")
  
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
  local route_exists=$(curl -s "$KONG_ADMIN_URL/routes/$name" | grep -c "id")
  
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

# Configure Keycloak routes
configure_keycloak_routes() {
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
}

# Configure API routes
configure_api_routes() {
  echo "Configuring API routes..."
  
  # Create API service
  create_or_update_service "api-service" "$INTERNAL_API_URL"
  
  # Create API routes
  create_or_update_route "api-domain-route" "api-service" "api.${BASE_DOMAIN}" "/" true false
  
  echo "✅ API routes configured successfully"
}

# Configure Frontend routes
configure_frontend_routes() {
  echo "Configuring Frontend routes..."
  
  # Create Frontend service
  create_or_update_service "frontend-service" "$INTERNAL_FRONTEND_URL"
  
  # Create Frontend routes
  create_or_update_route "frontend-domain-route" "frontend-service" "frontend.${BASE_DOMAIN}" "/" true false
  create_or_update_route "root-domain-route" "frontend-service" "${BASE_DOMAIN}" "/" true false
  
  echo "✅ Frontend routes configured successfully"
}

# Function to check Kong status
check_kong_status() {
  echo -e "${BLUE}Checking Kong status...${NC}"
  
  # Test the Kong Admin API
  local kong_status=$(curl -s -o /dev/null -w "%{http_code}" "$KONG_ADMIN_URL/status")
  
  if [ "$kong_status" = "200" ]; then
    echo -e "${GREEN}✅ Kong admin API is responding${NC}"
    
    # Get Kong status response
    local status_response=$(curl -s "$KONG_ADMIN_URL/status")
    echo -e "Kong Status: $status_response"
    
    # Check configured plugins
    echo -e "${BLUE}Checking configured plugins...${NC}"
    curl -s "$KONG_ADMIN_URL/plugins" | grep -o '"name":"[^"]*"' | sort || echo "No plugins found"
    
    # Check routes
    echo -e "${BLUE}Checking routes...${NC}"
    local routes_count=$(curl -s "$KONG_ADMIN_URL/routes" | grep -o '"data":' | wc -l | tr -d ' ')
    echo -e "Routes configured: $routes_count"
    
    # Check services
    echo -e "${BLUE}Checking services...${NC}"
    local services_count=$(curl -s "$KONG_ADMIN_URL/services" | grep -o '"data":' | wc -l | tr -d ' ')
    echo -e "Services configured: $services_count"
    
    return 0
  else
    echo -e "${RED}❌ Kong container is not running or not accessible${NC}"
    echo -e "HTTP status: $kong_status"
    echo -e "${YELLOW}Make sure Kong is running and properly configured.${NC}"
    return 1
  fi
}

# Function for basic troubleshooting
troubleshoot() {
  echo -e "${BLUE}Performing basic troubleshooting...${NC}"
  
  # Check if Kong is accessible
  echo -e "${BLUE}Testing Kong Admin API...${NC}"
  curl -s -I $KONG_ADMIN_URL || echo "Cannot connect to Kong Admin API"
  
  # Check SSL configuration
  echo -e "${BLUE}Checking SSL configuration...${NC}"
  curl -s $KONG_ADMIN_URL/certificates | grep -o '"data":\[[^]]*\]' || echo "No certificates configured"
  
  # Check for routes
  echo -e "${BLUE}Checking for routes...${NC}"
  curl -s $KONG_ADMIN_URL/routes | grep -o '"next":[^,]*' || echo "No routes found"
  
  # Check for services 
  echo -e "${BLUE}Checking for services...${NC}"
  curl -s $KONG_ADMIN_URL/services | grep -o '"next":[^,]*' || echo "No services found"
  
  # Check for plugins
  echo -e "${BLUE}Checking for plugins...${NC}"
  curl -s $KONG_ADMIN_URL/plugins | grep -o '"next":[^,]*' || echo "No plugins found"
  
  # Testing Kong proxy
  echo -e "${BLUE}Testing Kong proxy...${NC}"
  curl -s -I -o /dev/null -w "%{http_code}" "http://localhost:8000" || echo "Kong proxy not accessible"
  
  # Testing Kong HTTPS proxy 
  echo -e "${BLUE}Testing Kong HTTPS proxy...${NC}"
  curl -s -k -I -o /dev/null -w "%{http_code}" "https://localhost:8443" || echo "Kong HTTPS proxy not accessible"
  
  echo -e "${GREEN}✅ Troubleshooting completed${NC}"
  echo -e "If you're still experiencing issues, please check the following:"
  echo -e "1. Make sure your Docker containers are running"
  echo -e "2. Check that your SSL certificates are properly configured"
  echo -e "3. Verify that Kong has access to backend services via their DNS names"
  echo -e "4. Check the Kong container logs for detailed error messages"
}

# Usage information
show_help() {
  echo -e "${BLUE}DIVE25 - Unified Kong Gateway Configuration Script${NC}"
  echo -e "${BLUE}======================================================${NC}"
  echo "Usage: $0 [command]"
  echo ""
  echo "Commands:"
  echo "  oidc           - Configure OIDC authentication with Keycloak"
  echo "  dns-reset      - Reset Kong's DNS cache to ensure proper service resolution"
  echo "  port-8443      - Configure Kong routes for port 8443"
  echo "  ssl            - Set up SSL certificates for Kong"
  echo "  status         - Check Kong and service status"
  echo "  troubleshoot   - Perform basic troubleshooting"
  echo "  all            - Run all configuration steps (default)"
  echo "  help           - Display this help message"
  echo ""
  echo "Environment Variables:"
  echo "  KONG_ADMIN_URL        - Kong Admin API URL (default: http://localhost:9444)"
  echo "  BASE_DOMAIN           - Base domain for services (default: dive25.local)"
  echo "  KONG_CONTAINER        - Name of Kong container (default: dive25-kong)"
  echo "  FRONTEND_CONTAINER    - Name of frontend container (default: dive25-frontend)"
  echo "  API_CONTAINER         - Name of API container (default: dive25-api)"
  echo "  KEYCLOAK_CONTAINER    - Name of Keycloak container (default: dive25-keycloak)"
}

# Main function to run all configuration steps
run_all() {
  echo -e "${BLUE}Running all configuration steps...${NC}"
  
  # Initialize failure tracking
  local has_failures=false
  
  # First, reset DNS to ensure proper service resolution
  reset_kong_dns || {
    echo -e "${YELLOW}DNS reset had issues, continuing...${NC}"
    has_failures=true
  }
  
  # Set up SSL certificates
  setup_ssl || {
    echo -e "${YELLOW}SSL setup had issues, continuing...${NC}"
    has_failures=true
  }
  
  # Configure port 8443 routes
  configure_port_8443 || {
    echo -e "${YELLOW}Port 8443 configuration had issues, continuing...${NC}"
    has_failures=true
  }
  
  # Configure OIDC authentication
  configure_oidc || {
    echo -e "${YELLOW}OIDC configuration had issues, continuing...${NC}"
    has_failures=true
  }
  
  # Check final status
  check_kong_status || {
    echo -e "${YELLOW}Status check had issues, continuing...${NC}"
    has_failures=true
  }
  
  # If there were any failures, run the troubleshooting routine
  if [ "$has_failures" = true ]; then
    echo -e "${YELLOW}Some configuration steps had issues. Running troubleshooting...${NC}"
    troubleshoot
  fi
  
  echo -e "${GREEN}✅ All Kong configuration steps completed${NC}"
  
  # Final verification of essential services and routes
  echo -e "${BLUE}Verifying essential services and routes...${NC}"
  
  # Check if frontend route exists
  FRONTEND_ROUTE=$(curl -s $KONG_ADMIN_URL/routes | jq -r '.data[] | select(.name == "frontend-route") | .id')
  if [ -z "$FRONTEND_ROUTE" ] || [ "$FRONTEND_ROUTE" == "null" ]; then
    echo -e "${RED}❌ Frontend route is missing! Try accessing http://localhost:4433/frontend manually.${NC}"
  else
    echo -e "${GREEN}✅ Frontend route exists${NC}"
  fi
  
  # Check if API route exists
  API_ROUTE=$(curl -s $KONG_ADMIN_URL/routes | jq -r '.data[] | select(.name == "api-route") | .id')
  if [ -z "$API_ROUTE" ] || [ "$API_ROUTE" == "null" ]; then
    echo -e "${RED}❌ API route is missing! Try accessing http://localhost:4433/api manually.${NC}"
  else
    echo -e "${GREEN}✅ API route exists${NC}"
  fi
  
  # Provide final instructions
  echo -e "${BLUE}Configuration complete. You can now access:${NC}"
  echo -e "  Frontend: ${GREEN}http://localhost:4433/frontend${NC} or ${GREEN}https://localhost:8443/frontend${NC}"
  echo -e "  API: ${GREEN}http://localhost:4433/api${NC} or ${GREEN}https://localhost:8443/api${NC}"
  
  return 0
}

# Main execution flow
load_environment_variables

# Process command-line arguments
COMMAND=$1
if [ -z "$COMMAND" ]; then
  COMMAND="all"  # Default command
fi

case $COMMAND in
  oidc)
    configure_oidc
    ;;
  dns-reset)
    reset_kong_dns
    ;;
  port-8443)
    configure_port_8443
    ;;
  ssl)
    setup_ssl
    ;;
  status)
    check_kong_status
    ;;
  troubleshoot)
    troubleshoot
    ;;
  all)
    run_all
    ;;
  help|--help|-h)
    show_help
    ;;
  *)
    echo -e "${RED}Unknown command: $COMMAND${NC}"
    show_help
    exit 1
    ;;
esac

echo -e "${GREEN}Kong configuration command '$COMMAND' completed${NC}" 