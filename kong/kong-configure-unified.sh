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
#   all            - Run all configuration steps (default)
#   help           - Display this help message
#
# Environment Variables:
#   KONG_ADMIN_URL  - Kong Admin API URL (default: http://localhost:8001)
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
KONG_ADMIN_URL=${KONG_ADMIN_URL:-http://localhost:8001}
BASE_DOMAIN=${BASE_DOMAIN:-dive25.local}
KONG_CONTAINER=${KONG_CONTAINER:-dive25-kong}
FRONTEND_CONTAINER=${FRONTEND_CONTAINER:-dive25-frontend}
API_CONTAINER=${API_CONTAINER:-dive25-api}
KEYCLOAK_CONTAINER=${KEYCLOAK_CONTAINER:-dive25-keycloak}
INTERNAL_FRONTEND_URL=${INTERNAL_FRONTEND_URL:-http://frontend:3000}
INTERNAL_API_URL=${INTERNAL_API_URL:-http://api:8000}
INTERNAL_KEYCLOAK_URL=${INTERNAL_KEYCLOAK_URL:-http://keycloak:8080}
PUBLIC_KEYCLOAK_URL=${PUBLIC_KEYCLOAK_URL:-https://keycloak.$BASE_DOMAIN:8443}
PUBLIC_FRONTEND_URL=${PUBLIC_FRONTEND_URL:-https://frontend.$BASE_DOMAIN:8443}
PUBLIC_API_URL=${PUBLIC_API_URL:-https://api.$BASE_DOMAIN:8443}
KEYCLOAK_REALM=${KEYCLOAK_REALM:-dive25}
KEYCLOAK_CLIENT_ID_FRONTEND=${KEYCLOAK_CLIENT_ID_FRONTEND:-dive25-frontend}
KEYCLOAK_CLIENT_ID_API=${KEYCLOAK_CLIENT_ID_API:-dive25-api}
KEYCLOAK_CLIENT_SECRET=${KEYCLOAK_CLIENT_SECRET:-change-me-in-production}

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
  echo -e "${BLUE}Waiting for Kong to become healthy...${NC}"
  local attempts=0
  local max_attempts=30
  
  while [ $attempts -lt $max_attempts ]; do
    if docker ps | grep -q "$KONG_CONTAINER"; then
      local status=$(docker inspect --format='{{.State.Health.Status}}' $KONG_CONTAINER 2>/dev/null)
      
      if [ "$status" == "healthy" ]; then
        echo -e "${GREEN}✅ Kong is healthy!${NC}"
        return 0
      fi
    fi
    
    echo "Waiting for Kong to become healthy (attempt $((attempts+1))/$max_attempts)..."
    sleep 2
    attempts=$((attempts+1))
  done
  
  echo -e "${RED}❌ Kong did not become healthy after $max_attempts attempts${NC}"
  return 1
}

# Function to reset Kong's DNS resolution
reset_kong_dns() {
  echo -e "${BLUE}Resetting Kong's DNS resolution...${NC}"
  
  # Check the frontend container's IP and hostname
  FRONTEND_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $FRONTEND_CONTAINER)
  echo -e "${GREEN}Frontend container IP: ${FRONTEND_IP}${NC}"
  echo -e "${YELLOW}Kong should connect to frontend container via hostname 'frontend' instead of IP${NC}"
  
  # Restart Kong to force DNS refresh
  echo -e "${BLUE}Restarting Kong container to force DNS refresh...${NC}"
  docker restart $KONG_CONTAINER
  
  # Wait for Kong to be healthy
  wait_for_kong || {
    echo -e "${RED}❌ Failed to wait for Kong after restart${NC}"
    return 1
  }
  
  # Test DNS resolution
  echo -e "${BLUE}Testing DNS resolution from Kong container...${NC}"
  docker exec $KONG_CONTAINER sh -c "cat /etc/resolv.conf" || echo "Couldn't check resolv.conf"
  
  # Test connectivity to frontend
  echo -e "${BLUE}Testing connectivity from Kong to frontend...${NC}"
  docker exec $KONG_CONTAINER sh -c "ping -c 1 frontend" || echo "Ping failed, but this may be normal"
  
  echo -e "${GREEN}✅ Kong DNS resolution reset completed${NC}"
  return 0
}

# Function to configure SSL certificates
setup_ssl() {
  echo -e "${BLUE}Setting up SSL certificates for Kong...${NC}"
  
  # Create SSL directory if it doesn't exist
  mkdir -p kong/ssl
  
  # Check if certs directory exists with certificates
  if [ -d "kong/certs" ] && [ -f "kong/certs/dive25-cert.pem" ] && [ -f "kong/certs/dive25-key.pem" ]; then
    echo -e "${GREEN}✅ Found existing certificates in kong/certs${NC}"
    
    # Copy certificates to Kong SSL directory
    echo -e "${BLUE}Copying certificates to kong/ssl...${NC}"
    cp kong/certs/dive25-cert.pem kong/ssl/kong.crt
    cp kong/certs/dive25-key.pem kong/ssl/kong.key
  else
    echo -e "${YELLOW}No existing certificates found in kong/certs${NC}"
    
    # Check if SSL certificates exist in the parent directory
    if [ -d "../certs" ] && [ -f "../certs/dive25-cert.pem" ] && [ -f "../certs/dive25-key.pem" ]; then
      echo -e "${GREEN}✅ Found existing certificates in ../certs${NC}"
      
      # Copy certificates to Kong SSL directory
      echo -e "${BLUE}Copying certificates to kong/ssl...${NC}"
      cp ../certs/dive25-cert.pem kong/ssl/kong.crt
      cp ../certs/dive25-key.pem kong/ssl/kong.key
    else
      echo -e "${RED}❌ No certificates found. Please generate them first.${NC}"
      echo "You can generate certificates using the setup-local-dev-certs.sh script."
      return 1
    fi
  fi
  
  # Configure Kong to use SSL certificates
  echo -e "${BLUE}Configuring Kong to use SSL certificates...${NC}"
  curl -s -X PATCH $KONG_ADMIN_URL/certificates/default \
    -d "cert=$(cat kong/ssl/kong.crt)" \
    -d "key=$(cat kong/ssl/kong.key)" || {
    echo -e "${RED}❌ Failed to configure Kong SSL certificates${NC}"
    return 1
  }
  
  echo -e "${GREEN}✅ SSL certificates configured successfully${NC}"
  return 0
}

# Function to configure OIDC authentication
configure_oidc() {
  echo -e "${BLUE}Configuring Kong with OIDC authentication for Keycloak...${NC}"
  echo "Using a phased approach for safer deployment..."
  
  # Verify Kong Admin API is accessible
  if ! check_kong_health; then
    echo -e "${RED}❌ Cannot proceed with OIDC configuration${NC}"
    return 1
  fi
  
  # Step 1: Create a consistent session secret for all OIDC plugins
  # This is critical for preventing state parameter mismatch errors
  echo -e "${BLUE}Creating consistent session secret...${NC}"
  SESSION_SECRET=$(openssl rand -base64 32)
  
  # Step 2: Create or update frontend route-specific OIDC plugin
  echo -e "${BLUE}Configuring route-specific OIDC authentication for frontend...${NC}"
  
  # Get the frontend service ID (needed for route)
  FRONTEND_SERVICE_ID=$(curl -s $KONG_ADMIN_URL/services | jq -r '.data[] | select(.name == "frontend").id')
  if [ -z "$FRONTEND_SERVICE_ID" ]; then
    echo -e "${RED}❌ Frontend service not found. Please make sure it exists.${NC}"
    return 1
  fi
  
  # Get frontend route ID
  FRONTEND_ROUTE_ID=$(curl -s $KONG_ADMIN_URL/routes | jq -r '.data[] | select(.name == "frontend-route").id')
  if [ -z "$FRONTEND_ROUTE_ID" ]; then
    echo -e "${RED}❌ Frontend route not found. Please make sure it exists.${NC}"
    return 1
  }
  
  # Delete existing OIDC plugin on frontend route if it exists
  OIDC_PLUGIN_ID=$(curl -s "$KONG_ADMIN_URL/routes/$FRONTEND_ROUTE_ID/plugins" | jq -r '.data[] | select(.name == "oidc-auth").id')
  if [ -n "$OIDC_PLUGIN_ID" ] && [ "$OIDC_PLUGIN_ID" != "null" ]; then
    echo -e "${YELLOW}Removing existing OIDC plugin on frontend route...${NC}"
    curl -s -X DELETE "$KONG_ADMIN_URL/routes/$FRONTEND_ROUTE_ID/plugins/$OIDC_PLUGIN_ID" || {
      echo -e "${RED}❌ Failed to delete existing OIDC plugin${NC}"
    }
  fi
  
  # Create a new OIDC plugin on the frontend route
  echo -e "${BLUE}Creating new OIDC plugin for frontend route...${NC}"
  curl -s -X POST "$KONG_ADMIN_URL/routes/$FRONTEND_ROUTE_ID/plugins" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "name=oidc-auth" \
    -d "config.client_id=${KEYCLOAK_CLIENT_ID_FRONTEND}" \
    -d "config.client_secret=${KEYCLOAK_CLIENT_SECRET}" \
    -d "config.discovery=${INTERNAL_KEYCLOAK_URL}/realms/${KEYCLOAK_REALM}/.well-known/openid-configuration" \
    -d "config.introspection_endpoint=${INTERNAL_KEYCLOAK_URL}/realms/${KEYCLOAK_REALM}/protocol/openid-connect/token/introspect" \
    -d "config.bearer_only=false" \
    -d "config.realm=${KEYCLOAK_REALM}" \
    -d "config.redirect_uri_path=/callback" \
    -d "config.logout_path=/logout" \
    -d "config.redirect_after_logout_uri=${PUBLIC_FRONTEND_URL}" \
    -d "config.scope=openid email profile" \
    -d "config.response_type=code" \
    -d "config.ssl_verify=false" \
    -d "config.token_endpoint_auth_method=client_secret_post" \
    -d "config.introspection_endpoint_auth_method=client_secret_post" \
    -d "config.session_secret=${SESSION_SECRET}" \
    -d "config.session_storage=cookie" \
    -d "config.session_lifetime=3600" \
    -d "config.cookie_lifetime=3600" \
    -d "config.cookie_domain=$BASE_DOMAIN" \
    -d "config.cookie_secure=true" \
    -d "config.cookie_httponly=true" \
    -d "config.cookie_samesite=None" || {
      echo -e "${RED}❌ Failed to create OIDC plugin for frontend route${NC}"
      return 1
    }
  
  echo -e "${GREEN}✅ OIDC authentication configured successfully${NC}"
  return 0
}

# Function to configure port 8443 routes
configure_port_8443() {
  echo -e "${BLUE}Configuring Kong for port 8443 access...${NC}"
  
  # Check if Kong is accessible
  if ! check_kong_health; then
    echo -e "${RED}❌ Cannot proceed with port 8443 configuration${NC}"
    return 1
  fi
  
  # Define services to be created or updated
  echo -e "${BLUE}Setting up services for frontend, API, and Keycloak...${NC}"
  
  # Create or update Frontend service
  echo -e "${BLUE}Creating/updating frontend service...${NC}"
  curl -s -X PUT "$KONG_ADMIN_URL/services/frontend" \
    -d "url=$INTERNAL_FRONTEND_URL" \
    -d "name=frontend" \
    -d "retries=5" || {
      echo -e "${RED}❌ Failed to create/update frontend service${NC}"
      return 1
    }
  
  # Create or update API service
  echo -e "${BLUE}Creating/updating API service...${NC}"
  curl -s -X PUT "$KONG_ADMIN_URL/services/api" \
    -d "url=$INTERNAL_API_URL" \
    -d "name=api" \
    -d "retries=5" || {
      echo -e "${RED}❌ Failed to create/update API service${NC}"
      return 1
    }
  
  # Create or update Keycloak service
  echo -e "${BLUE}Creating/updating Keycloak service...${NC}"
  curl -s -X PUT "$KONG_ADMIN_URL/services/keycloak" \
    -d "url=$INTERNAL_KEYCLOAK_URL" \
    -d "name=keycloak" \
    -d "retries=5" || {
      echo -e "${RED}❌ Failed to create/update Keycloak service${NC}"
      return 1
    }
  
  # Create routes for port 8443
  echo -e "${BLUE}Creating/updating routes for port 8443...${NC}"
  
  # Create or update Frontend route for port 8443
  echo -e "${BLUE}Creating/updating frontend route for port 8443...${NC}"
  curl -s -X PUT "$KONG_ADMIN_URL/routes/frontend-route" \
    -d "service.id=$(curl -s $KONG_ADMIN_URL/services/frontend | jq -r '.id')" \
    -d "name=frontend-route" \
    -d "protocols[]=https" \
    -d "protocols[]=http" \
    -d "hosts[]=frontend.$BASE_DOMAIN" \
    -d "hosts[]=$BASE_DOMAIN" \
    -d "https_redirect_status_code=308" \
    -d "port=8443" || {
      echo -e "${RED}❌ Failed to create/update frontend route${NC}"
      return 1
    }
  
  # Create or update API route for port 8443
  echo -e "${BLUE}Creating/updating API route for port 8443...${NC}"
  curl -s -X PUT "$KONG_ADMIN_URL/routes/api-route" \
    -d "service.id=$(curl -s $KONG_ADMIN_URL/services/api | jq -r '.id')" \
    -d "name=api-route" \
    -d "protocols[]=https" \
    -d "protocols[]=http" \
    -d "hosts[]=api.$BASE_DOMAIN" \
    -d "https_redirect_status_code=308" \
    -d "port=8443" || {
      echo -e "${RED}❌ Failed to create/update API route${NC}"
      return 1
    }
  
  # Create or update Keycloak route for port 8443
  echo -e "${BLUE}Creating/updating Keycloak route for port 8443...${NC}"
  curl -s -X PUT "$KONG_ADMIN_URL/routes/keycloak-route" \
    -d "service.id=$(curl -s $KONG_ADMIN_URL/services/keycloak | jq -r '.id')" \
    -d "name=keycloak-route" \
    -d "protocols[]=https" \
    -d "protocols[]=http" \
    -d "hosts[]=keycloak.$BASE_DOMAIN" \
    -d "https_redirect_status_code=308" \
    -d "port=8443" || {
      echo -e "${RED}❌ Failed to create/update Keycloak route${NC}"
      return 1
    }
  
  echo -e "${GREEN}✅ Port 8443 configuration complete${NC}"
  return 0
}

# Function to check Kong status
check_status() {
  echo -e "${BLUE}Checking Kong status...${NC}"
  
  # Check if Kong container is running
  if docker ps | grep -q "$KONG_CONTAINER"; then
    echo -e "${GREEN}✅ Kong container is running${NC}"
  else
    echo -e "${RED}❌ Kong container is not running${NC}"
    return 1
  fi
  
  # Check if Kong is accessible
  if check_kong_health; then
    echo -e "${GREEN}✅ Kong Admin API is accessible${NC}"
  else
    echo -e "${RED}❌ Kong Admin API is not accessible${NC}"
    return 1
  fi
  
  # Check services
  echo -e "${BLUE}Checking Kong services...${NC}"
  curl -s $KONG_ADMIN_URL/services | jq -r '.data[] | "Service: \(.name), URL: \(.url)"'
  
  # Check routes
  echo -e "${BLUE}Checking Kong routes...${NC}"
  curl -s $KONG_ADMIN_URL/routes | jq -r '.data[] | "Route: \(.name), Service: \(.service.id), Hosts: \(.hosts)"'
  
  # Check plugins
  echo -e "${BLUE}Checking Kong plugins...${NC}"
  curl -s $KONG_ADMIN_URL/plugins | jq -r '.data[] | "Plugin: \(.name), Enabled: \(.enabled)"'
  
  echo -e "${GREEN}✅ Kong status check complete${NC}"
  return 0
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
  echo "  all            - Run all configuration steps (default)"
  echo "  help           - Display this help message"
  echo ""
  echo "Environment Variables:"
  echo "  KONG_ADMIN_URL        - Kong Admin API URL (default: http://localhost:8001)"
  echo "  BASE_DOMAIN           - Base domain for services (default: dive25.local)"
  echo "  KONG_CONTAINER        - Name of Kong container (default: dive25-kong)"
  echo "  FRONTEND_CONTAINER    - Name of frontend container (default: dive25-frontend)"
  echo "  API_CONTAINER         - Name of API container (default: dive25-api)"
  echo "  KEYCLOAK_CONTAINER    - Name of Keycloak container (default: dive25-keycloak)"
}

# Main function to run all configuration steps
run_all() {
  echo -e "${BLUE}Running all configuration steps...${NC}"
  
  # First, reset DNS to ensure proper service resolution
  reset_kong_dns || echo -e "${YELLOW}DNS reset had issues, continuing...${NC}"
  
  # Set up SSL certificates
  setup_ssl || echo -e "${YELLOW}SSL setup had issues, continuing...${NC}"
  
  # Configure port 8443 routes
  configure_port_8443 || echo -e "${YELLOW}Port 8443 configuration had issues, continuing...${NC}"
  
  # Configure OIDC authentication
  configure_oidc || echo -e "${YELLOW}OIDC configuration had issues, continuing...${NC}"
  
  # Check final status
  check_status || echo -e "${YELLOW}Status check had issues, continuing...${NC}"
  
  echo -e "${GREEN}✅ All Kong configuration steps completed${NC}"
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
    check_status
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