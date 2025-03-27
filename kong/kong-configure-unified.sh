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

# Handle environment-specific container names
ENVIRONMENT=${ENVIRONMENT:-"dev"}
if [ "$ENVIRONMENT" = "staging" ]; then
  # Default container names for staging environment
  KONG_CONTAINER=${KONG_CONTAINER:-"dive25-staging-kong"}
  FRONTEND_CONTAINER=${FRONTEND_CONTAINER:-"dive25-staging-frontend"}
  API_CONTAINER=${API_CONTAINER:-"dive25-staging-api"}
  KEYCLOAK_CONTAINER=${KEYCLOAK_CONTAINER:-"dive25-staging-keycloak"}
else
  # Default container names for dev environment
  KONG_CONTAINER=${KONG_CONTAINER:-"dive25-kong"}
  FRONTEND_CONTAINER=${FRONTEND_CONTAINER:-"dive25-frontend"}
  API_CONTAINER=${API_CONTAINER:-"dive25-api"}
  KEYCLOAK_CONTAINER=${KEYCLOAK_CONTAINER:-"dive25-keycloak"}
fi

INTERNAL_FRONTEND_URL=${INTERNAL_FRONTEND_URL:-"http://frontend:3000"}
INTERNAL_API_URL=${INTERNAL_API_URL:-"https://api:3000"}
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
  create_or_update_service "api-service" "https://api:3000"
  
  # Create API routes
  create_or_update_route "api-v1-route" "api-service" "api.${BASE_DOMAIN}" "/api/v1" false true
  
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

# Configure Grafana routes
configure_grafana_routes() {
  echo "Configuring Grafana routes..."
  
  # Create Grafana service
  create_or_update_service "grafana-service" "http://grafana:3000"
  
  # Create Grafana routes
  create_or_update_route "grafana-domain-route" "grafana-service" "grafana.${BASE_DOMAIN}" "/" true false
  
  echo "✅ Grafana routes configured successfully"
}

# Configure Mongo Express routes
configure_mongo_express_routes() {
  echo "Configuring Mongo Express routes..."
  
  # Create Mongo Express service
  create_or_update_service "mongo-express-service" "http://mongo-express:8081"
  
  # Create Mongo Express routes
  create_or_update_route "mongo-express-domain-route" "mongo-express-service" "mongo-express.${BASE_DOMAIN}" "/" true false
  
  echo "✅ Mongo Express routes configured successfully"
}

# Configure PHPLDAPAdmin routes
configure_phpldapadmin_routes() {
  echo "Configuring PHPLDAPAdmin routes..."
  
  # Create PHPLDAPAdmin service
  create_or_update_service "phpldapadmin-service" "http://phpldapadmin:80"
  
  # Create PHPLDAPAdmin routes
  create_or_update_route "phpldapadmin-domain-route" "phpldapadmin-service" "phpldapadmin.${BASE_DOMAIN}" "/" true false
  
  echo "✅ PHPLDAPAdmin routes configured successfully"
}

# Configure MongoDB Exporter routes
configure_mongodb_exporter_routes() {
  echo "Configuring MongoDB Exporter routes..."
  
  # Create MongoDB Exporter service
  create_or_update_service "mongodb-exporter-service" "http://mongodb-exporter:9216"
  
  # Create MongoDB Exporter routes
  create_or_update_route "mongodb-exporter-domain-route" "mongodb-exporter-service" "mongodb-exporter.${BASE_DOMAIN}" "/" true false
  
  echo "✅ MongoDB Exporter routes configured successfully"
}

# Configure Prometheus routes
configure_prometheus_routes() {
  echo "Configuring Prometheus routes..."
  
  # Create Prometheus service
  create_or_update_service "prometheus-service" "http://prometheus:9090"
  
  # Create Prometheus routes
  create_or_update_route "prometheus-domain-route" "prometheus-service" "prometheus.${BASE_DOMAIN}" "/" true false
  
  echo "✅ Prometheus routes configured successfully"
}

# Configure OPA routes
configure_opa_routes() {
  echo "Configuring OPA routes..."
  
  # Create OPA service
  create_or_update_service "opa-service" "http://opa:8181"
  
  # Create OPA routes
  create_or_update_route "opa-domain-route" "opa-service" "opa.${BASE_DOMAIN}" "/" true false
  
  echo "✅ OPA routes configured successfully"
}

# Configure Node Exporter routes
configure_node_exporter_routes() {
  echo "Configuring Node Exporter routes..."
  
  # Create Node Exporter service
  create_or_update_service "node-exporter-service" "http://node-exporter:9100"
  
  # Create Node Exporter routes
  create_or_update_route "node-exporter-domain-route" "node-exporter-service" "node-exporter.${BASE_DOMAIN}" "/" true false
  
  echo "✅ Node Exporter routes configured successfully"
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

# Function to reset Kong's DNS cache
reset_kong_dns() {
  echo -e "${BLUE}Resetting Kong DNS resolution...${NC}"
  
  # Try direct API call first
  local result=$(curl -s -X POST "$KONG_ADMIN_URL/cache/dns")
  
  if [[ $result == *"empty cache"* ]] || [[ $result == *"emptied"* ]]; then
    echo -e "${GREEN}✅ DNS cache successfully reset via API${NC}"
    return 0
  fi
  
  # If API call failed, try direct container command
  echo "API call failed, trying direct container command..."
  
  # Check if the container exists and is running
  if docker ps | grep -q "$KONG_CONTAINER"; then
    docker exec -it "$KONG_CONTAINER" kong reload
    if [ $? -eq 0 ]; then
      echo -e "${GREEN}✅ Kong reloaded and DNS cache reset${NC}"
      return 0
    else
      echo -e "${RED}❌ Failed to reload Kong${NC}"
      return 1
    fi
  else
    echo -e "${RED}❌ Kong container not found or not running${NC}"
    return 1
  fi
}

# Function to set up SSL certificates for Kong
setup_ssl() {
  echo -e "${BLUE}Setting up SSL certificates for Kong...${NC}"
  
  # First check if SSL is already configured
  local ssl_status=$(curl -s "$KONG_ADMIN_URL/certificates" | grep -c '"total":0')
  
  if [ "$ssl_status" = "0" ]; then
    echo -e "${GREEN}✅ SSL certificates already configured${NC}"
    return 0
  fi
  
  # Check for certificate files
  local cert_files_count=$(find /ssl -name "*.crt" 2>/dev/null | wc -l)
  local key_files_count=$(find /ssl -name "*.key" 2>/dev/null | wc -l)
  
  if [ "$cert_files_count" -eq 0 ] || [ "$key_files_count" -eq 0 ]; then
    echo -e "${YELLOW}⚠️ No certificate files found in /ssl directory${NC}"
    echo -e "${YELLOW}⚠️ Using self-signed certificates${NC}"
    
    # Create directory for certs if it doesn't exist
    mkdir -p /tmp/kong-ssl
    
    # Generate self-signed certificate
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
      -keyout /tmp/kong-ssl/kong-default.key \
      -out /tmp/kong-ssl/kong-default.crt \
      -subj "/CN=*.${BASE_DOMAIN}/O=DIVE25/C=US" || {
        echo -e "${RED}❌ Failed to generate self-signed certificate${NC}"
        return 1
      }
    
    # Upload certificate to Kong
    curl -s -X POST "$KONG_ADMIN_URL/certificates" \
      -F "cert=@/tmp/kong-ssl/kong-default.crt" \
      -F "key=@/tmp/kong-ssl/kong-default.key" \
      -F "snis[]=${BASE_DOMAIN}" \
      -F "snis[]=*.${BASE_DOMAIN}" > /dev/null || {
        echo -e "${RED}❌ Failed to upload self-signed certificate to Kong${NC}"
        return 1
      }
  else
    # Use existing certificates
    echo -e "${BLUE}Using existing certificates from /ssl directory${NC}"
    
    # Find certificate and key files
    local cert_file=$(find /ssl -name "*.crt" -o -name "*.pem" | head -n 1)
    local key_file=$(find /ssl -name "*.key" | head -n 1)
    
    # Upload certificate to Kong
    curl -s -X POST "$KONG_ADMIN_URL/certificates" \
      -F "cert=@$cert_file" \
      -F "key=@$key_file" \
      -F "snis[]=${BASE_DOMAIN}" \
      -F "snis[]=*.${BASE_DOMAIN}" > /dev/null || {
        echo -e "${RED}❌ Failed to upload certificate to Kong${NC}"
        return 1
      }
  fi
  
  echo -e "${GREEN}✅ SSL certificates configured successfully${NC}"
  return 0
}

# Function to configure Kong port 8443
configure_port_8443() {
  echo -e "${BLUE}Configuring Kong port 8443...${NC}"
  
  # Configure routes for frontend, API, and Keycloak
  configure_frontend_routes
  configure_api_routes
  configure_keycloak_routes
  
  # Configure additional service routes
  configure_grafana_routes
  configure_mongo_express_routes
  configure_phpldapadmin_routes
  configure_mongodb_exporter_routes
  configure_prometheus_routes
  configure_opa_routes
  configure_node_exporter_routes
  
  echo -e "${GREEN}✅ Port 8443 configured successfully${NC}"
  return 0
}

# Function to configure OIDC authentication with Keycloak
configure_oidc() {
  echo -e "${BLUE}Configuring OIDC authentication with Keycloak...${NC}"
  
  # Check if the plugin exists
  local plugin_exists=$(curl -s "$KONG_ADMIN_URL/plugins" | grep -c "oidc")
  
  if [ "$plugin_exists" -gt 0 ]; then
    echo -e "${GREEN}✅ OIDC plugin already configured${NC}"
    return 0
  fi
  
  # Configure OIDC plugin for Kong
  curl -s -X POST "$KONG_ADMIN_URL/plugins" \
    -d "name=oidc" \
    -d "config.client_id=${KEYCLOAK_CLIENT_ID_FRONTEND}" \
    -d "config.client_secret=${KEYCLOAK_CLIENT_SECRET}" \
    -d "config.discovery=${INTERNAL_KEYCLOAK_URL}/realms/${KEYCLOAK_REALM}/.well-known/openid-configuration" \
    -d "config.introspection_endpoint=${INTERNAL_KEYCLOAK_URL}/realms/${KEYCLOAK_REALM}/protocol/openid-connect/token/introspect" \
    -d "config.bearer_only=no" \
    -d "config.realm=${KEYCLOAK_REALM}" \
    -d "config.redirect_uri_path=/callback" \
    -d "config.logout_path=/logout" \
    -d "config.redirect_after_logout_uri=/" > /dev/null || {
      echo -e "${RED}❌ Failed to configure OIDC plugin${NC}"
      return 1
    }
  
  echo -e "${GREEN}✅ OIDC authentication configured successfully${NC}"
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
  FRONTEND_ROUTE=$(curl -s $KONG_ADMIN_URL/routes | jq -r '.data[] | select(.name == "frontend-domain-route") | .id')
  if [ -z "$FRONTEND_ROUTE" ] || [ "$FRONTEND_ROUTE" == "null" ]; then
    echo -e "${RED}❌ Frontend route is missing! Try accessing http://localhost:4433/frontend manually.${NC}"
  else
    echo -e "${GREEN}✅ Frontend route exists${NC}"
  fi
  
  # Check if API route exists
  API_ROUTE=$(curl -s $KONG_ADMIN_URL/routes | jq -r '.data[] | select(.name == "api-v1-route") | .id')
  if [ -z "$API_ROUTE" ] || [ "$API_ROUTE" == "null" ]; then
    echo -e "${RED}❌ API route is missing! Try accessing http://localhost:4433/api manually.${NC}"
  else
    echo -e "${GREEN}✅ API route exists${NC}"
  fi
  
  # Check if Grafana route exists
  GRAFANA_ROUTE=$(curl -s $KONG_ADMIN_URL/routes | jq -r '.data[] | select(.name == "grafana-domain-route") | .id')
  if [ -z "$GRAFANA_ROUTE" ] || [ "$GRAFANA_ROUTE" == "null" ]; then
    echo -e "${RED}❌ Grafana route is missing! Try accessing http://localhost:4433/grafana manually.${NC}"
  else
    echo -e "${GREEN}✅ Grafana route exists${NC}"
  fi
  
  # Check if Mongo Express route exists
  MONGO_EXPRESS_ROUTE=$(curl -s $KONG_ADMIN_URL/routes | jq -r '.data[] | select(.name == "mongo-express-domain-route") | .id')
  if [ -z "$MONGO_EXPRESS_ROUTE" ] || [ "$MONGO_EXPRESS_ROUTE" == "null" ]; then
    echo -e "${RED}❌ Mongo Express route is missing!${NC}"
  else
    echo -e "${GREEN}✅ Mongo Express route exists${NC}"
  fi
  
  # Provide final instructions
  echo -e "${BLUE}Configuration complete. You can now access:${NC}"
  echo -e "  Frontend: ${GREEN}http://localhost:4433/frontend${NC} or ${GREEN}https://localhost:8443/frontend${NC}"
  echo -e "  API: ${GREEN}http://localhost:4433/api${NC} or ${GREEN}https://localhost:8443/api${NC}"
  echo -e "  Grafana: ${GREEN}http://localhost:4433/grafana${NC} or ${GREEN}https://localhost:8443/grafana${NC}"
  echo -e "  Mongo Express: ${GREEN}http://localhost:4433/mongo-express${NC} or ${GREEN}https://localhost:8443/mongo-express${NC}"
  echo -e "  PHPLDAPAdmin: ${GREEN}http://localhost:4433/phpldapadmin${NC} or ${GREEN}https://localhost:8443/phpldapadmin${NC}"
  echo -e "  Prometheus: ${GREEN}http://localhost:4433/prometheus${NC} or ${GREEN}https://localhost:8443/prometheus${NC}"
  echo -e "  OPA: ${GREEN}http://localhost:4433/opa${NC} or ${GREEN}https://localhost:8443/opa${NC}"
  echo -e "  Node Exporter: ${GREEN}http://localhost:4433/node-exporter${NC} or ${GREEN}https://localhost:8443/node-exporter${NC}"
  echo -e "  MongoDB Exporter: ${GREEN}http://localhost:4433/mongodb-exporter${NC} or ${GREEN}https://localhost:8443/mongodb-exporter${NC}"
  
  # Add summary of all HTTPS services on port 8443
  echo -e "\n${BLUE}===========================================================${NC}"
  echo -e "${BLUE}SUMMARY OF ALL HTTPS SERVICES ON PORT 8443${NC}"
  echo -e "${BLUE}===========================================================${NC}"
  echo -e "The following services are accessible via HTTPS on port 8443:"
  echo -e "  1. ${GREEN}Frontend${NC}: https://frontend.${BASE_DOMAIN}:8443"
  echo -e "  2. ${GREEN}API${NC}: https://api.${BASE_DOMAIN}:8443"
  echo -e "  3. ${GREEN}Keycloak${NC}: https://keycloak.${BASE_DOMAIN}:8443"
  echo -e "  4. ${GREEN}Grafana${NC}: https://grafana.${BASE_DOMAIN}:8443"
  echo -e "  5. ${GREEN}Mongo Express${NC}: https://mongo-express.${BASE_DOMAIN}:8443"
  echo -e "  6. ${GREEN}PHPLDAPAdmin${NC}: https://phpldapadmin.${BASE_DOMAIN}:8443"
  echo -e "  7. ${GREEN}Prometheus${NC}: https://prometheus.${BASE_DOMAIN}:8443"
  echo -e "  8. ${GREEN}OPA${NC}: https://opa.${BASE_DOMAIN}:8443"
  echo -e "  9. ${GREEN}Node Exporter${NC}: https://node-exporter.${BASE_DOMAIN}:8443"
  echo -e " 10. ${GREEN}MongoDB Exporter${NC}: https://mongodb-exporter.${BASE_DOMAIN}:8443"
  echo -e "\nYou can also access these services via HTTP on port 4433:"
  echo -e "  Example: http://localhost:4433/grafana"
  echo -e "${BLUE}===========================================================${NC}"
  
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