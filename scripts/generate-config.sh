#!/bin/bash
#
# DIVE25 Configuration Generator
# ==============================
#
# This script generates Docker Compose files, .env files, and other configuration
# based on the centralized configuration in the config directory.
#
# Usage:
#   ./scripts/generate-config.sh [environment]
#
# Arguments:
#   environment - The environment to generate configs for (dev, staging, prod)
#                 Defaults to the value in ENVIRONMENT or dev if not set
#
# Requirements:
#   - yq (https://github.com/mikefarah/yq/) for YAML processing
#   - envsubst for environment variable substitution

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check for required tools
command -v yq >/dev/null 2>&1 || { echo -e "${RED}Error: yq is required but not installed. Install it from https://github.com/mikefarah/yq/${NC}" >&2; exit 1; }

# Set environment
ENV=${1:-${ENVIRONMENT:-dev}}
if [[ ! "$ENV" =~ ^(dev|staging|prod)$ ]]; then
  echo -e "${RED}Error: Invalid environment '$ENV'. Must be one of: dev, staging, prod${NC}"
  exit 1
fi

echo -e "${BLUE}Generating configuration for ${GREEN}$ENV${BLUE} environment...${NC}"

# Define paths
CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/config"
BASE_CONFIG="$CONFIG_DIR/base.yml"
ENV_CONFIG="$CONFIG_DIR/$ENV.yml"
GENERATED_DIR="$CONFIG_DIR/generated"
DOCKER_COMPOSE_TEMPLATE="$CONFIG_DIR/templates/docker-compose.template.yml"
KONG_CONFIG_TEMPLATE="$CONFIG_DIR/templates/kong.template.yml"

# Ensure generated directory exists
mkdir -p "$GENERATED_DIR"

# Function to merge base and environment configs
generate_merged_config() {
  echo -e "${BLUE}Merging base and $ENV configurations...${NC}"
  
  # Check if files exist
  if [[ ! -f "$BASE_CONFIG" ]]; then
    echo -e "${RED}Error: Base config file $BASE_CONFIG not found${NC}"
    exit 1
  fi
  
  if [[ ! -f "$ENV_CONFIG" ]]; then
    echo -e "${RED}Error: Environment config file $ENV_CONFIG not found${NC}"
    exit 1
  fi
  
  # Merge configs with environment taking precedence
  yq eval-all 'select(fileIndex == 0) * select(fileIndex == 1)' "$BASE_CONFIG" "$ENV_CONFIG" > "$GENERATED_DIR/merged-config.$ENV.yml"
  
  echo -e "${GREEN}✓ Configuration merged${NC}"
}

# Function to generate .env file from merged config
generate_env_file() {
  echo -e "${BLUE}Generating .env file from merged configuration...${NC}"
  
  CONFIG_FILE="$GENERATED_DIR/merged-config.$ENV.yml"
  ENV_OUTPUT="$GENERATED_DIR/.env.$ENV"
  
  # Extract key information from config
  ENV_NAME=$(yq eval '.environment' "$CONFIG_FILE")
  BASE_DOMAIN=$(yq eval '.base_domain' "$CONFIG_FILE")
  USE_HTTPS=$(yq eval '.use_https' "$CONFIG_FILE")
  PROTOCOL=$(yq eval '.protocol' "$CONFIG_FILE")
  
  # Start generating .env file
  echo "# Auto-generated configuration file for $ENV_NAME environment" > "$ENV_OUTPUT"
  echo "# Generated on $(date)" >> "$ENV_OUTPUT"
  echo "# DO NOT EDIT DIRECTLY - MODIFY config/$ENV.yml INSTEAD" >> "$ENV_OUTPUT"
  echo "" >> "$ENV_OUTPUT"
  
  # Environment settings
  echo "# Environment Settings" >> "$ENV_OUTPUT"
  echo "ENVIRONMENT=$ENV_NAME" >> "$ENV_OUTPUT"
  echo "BASE_DOMAIN=$BASE_DOMAIN" >> "$ENV_OUTPUT"
  echo "USE_HTTPS=$USE_HTTPS" >> "$ENV_OUTPUT"
  echo "PROTOCOL=$PROTOCOL" >> "$ENV_OUTPUT"
  echo "" >> "$ENV_OUTPUT"
  
  # Database credentials
  echo "# Database Credentials" >> "$ENV_OUTPUT"
  echo "MONGO_ROOT_USERNAME=$(yq eval '.databases.mongodb.root_username' "$CONFIG_FILE")" >> "$ENV_OUTPUT"
  echo "MONGO_ROOT_PASSWORD=$(yq eval '.databases.mongodb.root_password' "$CONFIG_FILE")" >> "$ENV_OUTPUT"
  echo "MONGO_APP_USERNAME=$(yq eval '.databases.mongodb.app_username' "$CONFIG_FILE")" >> "$ENV_OUTPUT"
  echo "MONGO_APP_PASSWORD=$(yq eval '.databases.mongodb.app_password' "$CONFIG_FILE")" >> "$ENV_OUTPUT"
  echo "POSTGRES_PASSWORD=$(yq eval '.databases.postgres.password' "$CONFIG_FILE")" >> "$ENV_OUTPUT"
  echo "POSTGRES_DB=$(yq eval '.databases.postgres.database' "$CONFIG_FILE")" >> "$ENV_OUTPUT"
  echo "POSTGRES_USER=$(yq eval '.databases.postgres.username' "$CONFIG_FILE")" >> "$ENV_OUTPUT"
  echo "KONG_PG_PASSWORD=$(yq eval '.databases.kong_db.password' "$CONFIG_FILE")" >> "$ENV_OUTPUT"
  echo "KONG_PG_DATABASE=$(yq eval '.databases.kong_db.database' "$CONFIG_FILE")" >> "$ENV_OUTPUT"
  echo "KONG_PG_USER=$(yq eval '.databases.kong_db.username' "$CONFIG_FILE")" >> "$ENV_OUTPUT"
  echo "" >> "$ENV_OUTPUT"
  
  # Authentication settings
  echo "# Authentication Settings" >> "$ENV_OUTPUT"
  echo "KEYCLOAK_ADMIN=$(yq eval '.auth.keycloak.admin_username' "$CONFIG_FILE")" >> "$ENV_OUTPUT"
  echo "KEYCLOAK_ADMIN_PASSWORD=$(yq eval '.auth.keycloak.admin_password' "$CONFIG_FILE")" >> "$ENV_OUTPUT"
  echo "KEYCLOAK_REALM=$(yq eval '.auth.keycloak.realm' "$CONFIG_FILE")" >> "$ENV_OUTPUT"
  echo "KEYCLOAK_CLIENT_ID_FRONTEND=$(yq eval '.auth.keycloak.client_id_frontend' "$CONFIG_FILE")" >> "$ENV_OUTPUT"
  echo "KEYCLOAK_CLIENT_ID_API=$(yq eval '.auth.keycloak.client_id_api' "$CONFIG_FILE")" >> "$ENV_OUTPUT"
  echo "KEYCLOAK_CLIENT_SECRET=$(yq eval '.auth.keycloak.client_secret' "$CONFIG_FILE")" >> "$ENV_OUTPUT"
  echo "KEYCLOAK_CLIENT_ID=$(yq eval '.auth.keycloak.client_id_frontend' "$CONFIG_FILE")" >> "$ENV_OUTPUT"
  echo "KEYCLOAK_AUTH_PATH=$(yq eval '.auth.keycloak.auth_path' "$CONFIG_FILE")" >> "$ENV_OUTPUT"
  echo "JWT_SECRET=$(yq eval '.auth.jwt.secret' "$CONFIG_FILE")" >> "$ENV_OUTPUT"
  echo "SESSION_SECRET=$(yq eval '.auth.session.secret' "$CONFIG_FILE")" >> "$ENV_OUTPUT"
  echo "KONG_ADMIN_TOKEN=change-me-in-production" >> "$ENV_OUTPUT"
  echo "" >> "$ENV_OUTPUT"
  
  # LDAP Configuration
  echo "# LDAP Configuration" >> "$ENV_OUTPUT"
  echo "LDAP_ADMIN_PASSWORD=$(yq eval '.ldap.admin_password' "$CONFIG_FILE")" >> "$ENV_OUTPUT"
  echo "LDAP_CONFIG_PASSWORD=$(yq eval '.ldap.config_password' "$CONFIG_FILE")" >> "$ENV_OUTPUT"
  echo "LDAP_READONLY_PASSWORD=$(yq eval '.ldap.readonly_password' "$CONFIG_FILE")" >> "$ENV_OUTPUT"
  echo "LDAP_BIND_DN=$(yq eval '.ldap.bind_dn' "$CONFIG_FILE")" >> "$ENV_OUTPUT"
  echo "LDAP_SEARCH_BASE=$(yq eval '.ldap.search_base' "$CONFIG_FILE")" >> "$ENV_OUTPUT"
  echo "LDAP_DOMAIN=$(yq eval '.ldap.domain' "$CONFIG_FILE")" >> "$ENV_OUTPUT"
  echo "LDAP_ORGANISATION=$(yq eval '.ldap.organisation' "$CONFIG_FILE")" >> "$ENV_OUTPUT"
  echo "" >> "$ENV_OUTPUT"
  
  # Admin tool credentials
  echo "# Admin Tool Credentials" >> "$ENV_OUTPUT"
  echo "GRAFANA_ADMIN_USER=$(yq eval '.admin.grafana.username' "$CONFIG_FILE")" >> "$ENV_OUTPUT"
  echo "GRAFANA_ADMIN_PASSWORD=$(yq eval '.admin.grafana.password' "$CONFIG_FILE")" >> "$ENV_OUTPUT"
  echo "MONGO_EXPRESS_USERNAME=$(yq eval '.admin.mongodb_express.username' "$CONFIG_FILE")" >> "$ENV_OUTPUT"
  echo "MONGO_EXPRESS_PASSWORD=$(yq eval '.admin.mongodb_express.password' "$CONFIG_FILE")" >> "$ENV_OUTPUT"
  echo "" >> "$ENV_OUTPUT"
  
  # Internal Ports
  echo "# Service Internal Ports" >> "$ENV_OUTPUT"
  echo "# These are the ports used INSIDE containers" >> "$ENV_OUTPUT"
  echo "INTERNAL_FRONTEND_PORT=$(yq eval '.internal_ports.frontend' "$CONFIG_FILE")" >> "$ENV_OUTPUT"
  echo "INTERNAL_API_PORT=$(yq eval '.internal_ports.api' "$CONFIG_FILE")" >> "$ENV_OUTPUT"
  echo "INTERNAL_KEYCLOAK_PORT=$(yq eval '.internal_ports.keycloak' "$CONFIG_FILE")" >> "$ENV_OUTPUT"
  echo "INTERNAL_MONGODB_PORT=$(yq eval '.internal_ports.mongodb' "$CONFIG_FILE")" >> "$ENV_OUTPUT"
  echo "INTERNAL_POSTGRES_PORT=$(yq eval '.internal_ports.postgres' "$CONFIG_FILE")" >> "$ENV_OUTPUT"
  echo "INTERNAL_KONG_PROXY_PORT=$(yq eval '.internal_ports.kong_proxy' "$CONFIG_FILE")" >> "$ENV_OUTPUT"
  echo "INTERNAL_KONG_ADMIN_PORT=$(yq eval '.internal_ports.kong_admin' "$CONFIG_FILE")" >> "$ENV_OUTPUT"
  echo "INTERNAL_OPA_PORT=$(yq eval '.internal_ports.opa' "$CONFIG_FILE")" >> "$ENV_OUTPUT"
  echo "INTERNAL_GRAFANA_PORT=$(yq eval '.internal_ports.grafana' "$CONFIG_FILE")" >> "$ENV_OUTPUT"
  echo "INTERNAL_PROMETHEUS_PORT=$(yq eval '.internal_ports.prometheus' "$CONFIG_FILE")" >> "$ENV_OUTPUT"
  echo "INTERNAL_PHPLDAPADMIN_PORT=$(yq eval '.internal_ports.phpldapadmin' "$CONFIG_FILE")" >> "$ENV_OUTPUT"
  echo "INTERNAL_OPENLDAP_PORT=389" >> "$ENV_OUTPUT"
  echo "INTERNAL_OPENLDAP_TLS_PORT=636" >> "$ENV_OUTPUT"
  echo "INTERNAL_KONG_HTTPS_PORT=$(yq eval '.internal_ports.kong_proxy_https' "$CONFIG_FILE")" >> "$ENV_OUTPUT"
  echo "INTERNAL_KONG_ADMIN_HTTPS_PORT=$(yq eval '.internal_ports.kong_admin_https' "$CONFIG_FILE")" >> "$ENV_OUTPUT"
  echo "INTERNAL_KONGA_PORT=$(yq eval '.internal_ports.konga' "$CONFIG_FILE")" >> "$ENV_OUTPUT"
  echo "INTERNAL_MONGODB_EXPORTER_PORT=$(yq eval '.internal_ports.mongodb_exporter' "$CONFIG_FILE")" >> "$ENV_OUTPUT"
  echo "INTERNAL_NODE_EXPORTER_PORT=$(yq eval '.internal_ports.node_exporter' "$CONFIG_FILE")" >> "$ENV_OUTPUT"
  echo "" >> "$ENV_OUTPUT"
  
  # External Ports
  echo "# External Ports (for host access)" >> "$ENV_OUTPUT"
  echo "FRONTEND_PORT=$(yq eval '.external_ports.frontend' "$CONFIG_FILE")" >> "$ENV_OUTPUT"
  echo "API_PORT=$(yq eval '.external_ports.api' "$CONFIG_FILE")" >> "$ENV_OUTPUT"
  echo "KEYCLOAK_PORT=$(yq eval '.external_ports.keycloak' "$CONFIG_FILE")" >> "$ENV_OUTPUT"
  echo "KONG_PROXY_PORT=$(yq eval '.external_ports.kong_proxy' "$CONFIG_FILE")" >> "$ENV_OUTPUT"
  echo "KONG_ADMIN_PORT=$(yq eval '.external_ports.kong_admin' "$CONFIG_FILE")" >> "$ENV_OUTPUT"
  echo "GRAFANA_PORT=$(yq eval '.external_ports.grafana' "$CONFIG_FILE")" >> "$ENV_OUTPUT"
  echo "MONGODB_EXPRESS_PORT=$(yq eval '.external_ports.mongodb_express' "$CONFIG_FILE")" >> "$ENV_OUTPUT"
  echo "PHPLDAPADMIN_PORT=$(yq eval '.external_ports.phpldapadmin' "$CONFIG_FILE")" >> "$ENV_OUTPUT"
  echo "PROMETHEUS_PORT=$(yq eval '.external_ports.prometheus' "$CONFIG_FILE")" >> "$ENV_OUTPUT"
  echo "OPA_PORT=$(yq eval '.external_ports.opa' "$CONFIG_FILE")" >> "$ENV_OUTPUT"
  echo "KONGA_PORT=$(yq eval '.external_ports.konga' "$CONFIG_FILE")" >> "$ENV_OUTPUT"
  echo "MONGODB_EXPORTER_PORT=$(yq eval '.external_ports.mongodb_exporter' "$CONFIG_FILE")" >> "$ENV_OUTPUT"
  echo "NODE_EXPORTER_PORT=$(yq eval '.external_ports.node_exporter' "$CONFIG_FILE")" >> "$ENV_OUTPUT"
  echo "KONG_HTTPS_PORT=$(yq eval '.external_ports.kong_proxy_https' "$CONFIG_FILE")" >> "$ENV_OUTPUT"
  echo "KONG_ADMIN_HTTPS_PORT=$(yq eval '.external_ports.kong_admin_https' "$CONFIG_FILE")" >> "$ENV_OUTPUT"
  echo "" >> "$ENV_OUTPUT"
  
  # Service domain names
  echo "# Domain Names" >> "$ENV_OUTPUT"
  for service in frontend api keycloak kong grafana mongodb_express phpldapadmin prometheus opa konga mongodb_exporter node_exporter; do
    subdomain=$(yq eval ".domains.$service" "$CONFIG_FILE")
    service_upper=$(echo "$service" | tr '[:lower:]' '[:upper:]' | tr '_' '-')
    # Replace hyphens with underscores for variable names
    env_var_name=$(echo "${service_upper}_DOMAIN" | tr '-' '_')
    echo "$env_var_name=$subdomain" >> "$ENV_OUTPUT"
  done
  echo "" >> "$ENV_OUTPUT"
  
  # Generate CORS allowed origins
  echo "# CORS Configuration" >> "$ENV_OUTPUT"
  CORS_ORIGINS=$(yq eval '.cors.allowed_origins | join(",")' "$CONFIG_FILE")
  echo "CORS_ALLOWED_ORIGINS=$CORS_ORIGINS" >> "$ENV_OUTPUT"
  echo "" >> "$ENV_OUTPUT"
  
  # Generate security headers configuration
  echo "# Security Headers Configuration" >> "$ENV_OUTPUT"
  KEYCLOAK_HEADERS=$(yq eval '.security.headers.keycloak.add | join(",")' "$CONFIG_FILE")
  echo "KEYCLOAK_SECURITY_HEADERS=$KEYCLOAK_HEADERS" >> "$ENV_OUTPUT"
  GLOBAL_HEADERS=$(yq eval '.security.headers.global.add | join(",")' "$CONFIG_FILE")
  echo "GLOBAL_SECURITY_HEADERS=$GLOBAL_HEADERS" >> "$ENV_OUTPUT"
  echo "" >> "$ENV_OUTPUT"
  
  # SSL configuration
  echo "# SSL/TLS certificates paths" >> "$ENV_OUTPUT"
  echo "SSL_CERT_PATH=$(yq eval '.ssl.cert_path' "$CONFIG_FILE")" >> "$ENV_OUTPUT"
  echo "SSL_KEY_PATH=$(yq eval '.ssl.key_path' "$CONFIG_FILE")" >> "$ENV_OUTPUT"
  echo "" >> "$ENV_OUTPUT"
  
  # Service naming (for internal communication)
  echo "# Service Names (for internal communication)" >> "$ENV_OUTPUT"
  for service in $(yq eval '.services | keys | .[]' "$CONFIG_FILE"); do
    service_name=$(yq eval ".services.$service" "$CONFIG_FILE")
    service_upper=$(echo "$service" | tr '[:lower:]' '[:upper:]')
    echo "${service_upper}_SERVICE=$service_name" >> "$ENV_OUTPUT"
  done
  echo "" >> "$ENV_OUTPUT"
  
  # Generate internal URLs (service-to-service communication)
  echo "# ----- Internal URLs (service-to-service) -----" >> "$ENV_OUTPUT"
  echo "# These URLs are used for communication between Docker services" >> "$ENV_OUTPUT"
  
  generate_internal_url() {
    local service=$1
    local internal_port_key=$2
    local service_name=$(yq eval ".services.$service" "$CONFIG_FILE")
    local internal_port=$(yq eval ".internal_ports.$internal_port_key" "$CONFIG_FILE")
    local protocol="http"
    local service_upper=$(echo "$service" | tr '[:lower:]' '[:upper:]')
    
    if [[ "$service" == "mongodb" ]]; then
      echo "INTERNAL_${service_upper}_URL=mongodb://${service_name}:${internal_port}" >> "$ENV_OUTPUT"
    elif [[ "$service" == "postgres" ]]; then
      echo "INTERNAL_${service_upper}_URL=postgres://${service_name}:${internal_port}" >> "$ENV_OUTPUT"
    elif [[ "$service" == "openldap" ]]; then
      echo "INTERNAL_${service_upper}_URL=ldap://${service_name}:${internal_port}" >> "$ENV_OUTPUT"
    else
      echo "INTERNAL_${service_upper}_URL=${protocol}://${service_name}:${internal_port}" >> "$ENV_OUTPUT"
    fi
  }
  
  generate_internal_url "frontend" "frontend" 
  generate_internal_url "api" "api"
  generate_internal_url "keycloak" "keycloak"
  echo "INTERNAL_KEYCLOAK_AUTH_URL=http://$(yq eval '.services.keycloak' "$CONFIG_FILE"):$(yq eval '.internal_ports.keycloak' "$CONFIG_FILE")$(yq eval '.auth.keycloak.auth_path' "$CONFIG_FILE")" >> "$ENV_OUTPUT"
  generate_internal_url "kong_admin" "kong_admin"
  generate_internal_url "kong" "kong_proxy"
  generate_internal_url "mongodb" "mongodb"
  generate_internal_url "postgres" "postgres"
  generate_internal_url "opa" "opa"
  generate_internal_url "openldap" "phpldapadmin"
  generate_internal_url "grafana" "grafana"
  generate_internal_url "prometheus" "prometheus"
  generate_internal_url "phpldapadmin" "phpldapadmin"
  generate_internal_url "konga" "konga"
  generate_internal_url "mongodb_exporter" "mongodb_exporter"
  generate_internal_url "node_exporter" "node_exporter"
  generate_internal_url "kong_database" "postgres"
  echo "" >> "$ENV_OUTPUT"
  
  # Generate external URLs (browser-to-service communication)
  echo "# ----- External URLs (browser-to-service) -----" >> "$ENV_OUTPUT"
  echo "# These URLs are used for browser access to services" >> "$ENV_OUTPUT"
  
  generate_external_url() {
    local service=$1
    local domain_key=$2
    local port_key=$3
    
    local subdomain=$(yq eval ".domains.$domain_key" "$CONFIG_FILE")
    local port=$(yq eval ".external_ports.$port_key" "$CONFIG_FILE")
    local base_domain=$(yq eval '.base_domain' "$CONFIG_FILE")
    local protocol=$(yq eval '.protocol' "$CONFIG_FILE")
    local service_upper=$(echo "$service" | tr '[:lower:]' '[:upper:]')
    
    # For production & standard ports, don't include the port in the URL
    if [[ "$ENV" == "prod" && "$port" == "443" && "$protocol" == "https" ]]; then
      echo "PUBLIC_${service_upper}_URL=${protocol}://${subdomain}.${base_domain}" >> "$ENV_OUTPUT"
    elif [[ "$ENV" == "prod" && "$port" == "80" && "$protocol" == "http" ]]; then
      echo "PUBLIC_${service_upper}_URL=${protocol}://${subdomain}.${base_domain}" >> "$ENV_OUTPUT"
    else
      echo "PUBLIC_${service_upper}_URL=${protocol}://${subdomain}.${base_domain}:${port}" >> "$ENV_OUTPUT"
    fi
  }
  
  generate_external_url "FRONTEND" "frontend" "frontend"
  generate_external_url "API" "api" "api"
  generate_external_url "KEYCLOAK" "keycloak" "keycloak" 
  echo "PUBLIC_KEYCLOAK_AUTH_URL=$(grep PUBLIC_KEYCLOAK_URL "$ENV_OUTPUT" | cut -d '=' -f2-)$(yq eval '.auth.keycloak.auth_path' "$CONFIG_FILE")" >> "$ENV_OUTPUT"
  generate_external_url "KONG_ADMIN" "kong" "kong_admin"
  generate_external_url "KONG_PROXY" "kong" "kong_proxy"
  generate_external_url "GRAFANA" "grafana" "grafana"
  generate_external_url "MONGODB_EXPRESS" "mongodb_express" "mongodb_express"
  generate_external_url "PHPLDAPADMIN" "phpldapadmin" "phpldapadmin"
  generate_external_url "PROMETHEUS" "prometheus" "prometheus"
  generate_external_url "OPA" "opa" "opa"
  generate_external_url "KONGA" "konga" "konga"
  generate_external_url "MONGODB_EXPORTER" "mongodb_exporter" "mongodb_exporter"
  generate_external_url "NODE_EXPORTER" "node_exporter" "node_exporter"
  echo "" >> "$ENV_OUTPUT"
  
  # Authentication connection strings
  echo "# ----- Authentication Connection Strings -----" >> "$ENV_OUTPUT"
  echo "# These are specialized connection strings for authentication" >> "$ENV_OUTPUT"
  echo "MONGODB_AUTH_URL=mongodb://$(yq eval '.databases.mongodb.app_username' "$CONFIG_FILE"):$(yq eval '.databases.mongodb.app_password' "$CONFIG_FILE")@$(yq eval '.services.mongodb' "$CONFIG_FILE"):$(yq eval '.internal_ports.mongodb' "$CONFIG_FILE")/dive25" >> "$ENV_OUTPUT" 
  echo "MONGODB_ADMIN_URL=mongodb://$(yq eval '.databases.mongodb.root_username' "$CONFIG_FILE"):$(yq eval '.databases.mongodb.root_password' "$CONFIG_FILE")@$(yq eval '.services.mongodb' "$CONFIG_FILE"):$(yq eval '.internal_ports.mongodb' "$CONFIG_FILE")/admin" >> "$ENV_OUTPUT"
  echo "POSTGRES_KEYCLOAK_URL=jdbc:postgresql://$(yq eval '.services.postgres' "$CONFIG_FILE"):$(yq eval '.internal_ports.postgres' "$CONFIG_FILE")/$(yq eval '.databases.postgres.database' "$CONFIG_FILE")" >> "$ENV_OUTPUT"
  echo "LDAP_AUTH_URL=ldap://$(yq eval '.services.openldap' "$CONFIG_FILE"):389/$(yq eval '.ldap.search_base' "$CONFIG_FILE")" >> "$ENV_OUTPUT"
  
  # Add network configuration to the .env file
  echo "# Network Configuration" >> "$ENV_OUTPUT"
  echo "NETWORKS_PUBLIC_NAME=$(yq eval '.networks.public.name' "$CONFIG_FILE")" >> "$ENV_OUTPUT"
  echo "NETWORKS_PUBLIC_SUBNET=$(yq eval '.networks.public.subnet' "$CONFIG_FILE")" >> "$ENV_OUTPUT"
  echo "NETWORKS_SERVICE_NAME=$(yq eval '.networks.service.name' "$CONFIG_FILE")" >> "$ENV_OUTPUT"
  echo "NETWORKS_SERVICE_SUBNET=$(yq eval '.networks.service.subnet' "$CONFIG_FILE")" >> "$ENV_OUTPUT"
  echo "NETWORKS_DATA_NAME=$(yq eval '.networks.data.name' "$CONFIG_FILE")" >> "$ENV_OUTPUT"
  echo "NETWORKS_DATA_SUBNET=$(yq eval '.networks.data.subnet' "$CONFIG_FILE")" >> "$ENV_OUTPUT"
  echo "NETWORKS_ADMIN_NAME=$(yq eval '.networks.admin.name' "$CONFIG_FILE")" >> "$ENV_OUTPUT"
  echo "NETWORKS_ADMIN_SUBNET=$(yq eval '.networks.admin.subnet' "$CONFIG_FILE")" >> "$ENV_OUTPUT"
  echo "PROJECT_CONTAINER_PREFIX=$(yq eval '.project.container_prefix' "$CONFIG_FILE")" >> "$ENV_OUTPUT"
  echo "" >> "$ENV_OUTPUT"
  
  # Add logging configuration
  echo "# Logging Configuration" >> "$ENV_OUTPUT"
  echo "LOG_LEVEL=$(yq eval '.logging.level' "$CONFIG_FILE")" >> "$ENV_OUTPUT"
  echo "" >> "$ENV_OUTPUT"
  
  # Create a link to the environment file
  cp "$ENV_OUTPUT" "$GENERATED_DIR/.env"
  
  # If requested, also copy to project root
  if [[ "$COPY_TO_ROOT" == "true" ]]; then
    cp "$ENV_OUTPUT" "../.env"
    echo -e "${GREEN}✓ .env file copied to project root${NC}"
  fi
  
  echo -e "${GREEN}✓ .env file generated at $ENV_OUTPUT${NC}"
}

# Function to generate Docker Compose file
generate_docker_compose() {
  echo -e "${BLUE}Generating Docker Compose file...${NC}"
  
  # Check if template exists
  mkdir -p "$CONFIG_DIR/templates"
  if [[ ! -f "$DOCKER_COMPOSE_TEMPLATE" ]]; then
    echo -e "${YELLOW}Warning: Docker Compose template not found at $DOCKER_COMPOSE_TEMPLATE${NC}"
    echo -e "${YELLOW}Will need to create template manually or from existing docker-compose.yml${NC}"
    echo -e "${YELLOW}Skipping Docker Compose generation${NC}"
    return
  fi
  
  # Create output file
  DOCKER_COMPOSE_OUTPUT="$GENERATED_DIR/docker-compose.$ENV.yml"
  
  # Generate Docker Compose file using environment variables from .env file
  set -a # Export all variables
  source "$GENERATED_DIR/.env"
  set +a
  
  envsubst < "$DOCKER_COMPOSE_TEMPLATE" > "$DOCKER_COMPOSE_OUTPUT"
  
  echo -e "${GREEN}✓ Docker Compose file generated at $DOCKER_COMPOSE_OUTPUT${NC}"
}

# Function to generate Kong configuration
generate_kong_config() {
  echo -e "${BLUE}Generating Kong configuration...${NC}"
  
  # Check if template exists
  if [[ ! -f "$KONG_CONFIG_TEMPLATE" ]]; then
    echo -e "${YELLOW}Warning: Kong configuration template not found at $KONG_CONFIG_TEMPLATE${NC}"
    echo -e "${YELLOW}Will need to create template manually or from existing kong/kong.yml${NC}"
    echo -e "${YELLOW}Skipping Kong configuration generation${NC}"
    return
  fi
  
  # Create output file
  KONG_CONFIG_OUTPUT="$GENERATED_DIR/kong.$ENV.yml"
  
  # Generate Kong configuration file using environment variables from .env file
  set -a # Export all variables
  source "$GENERATED_DIR/.env"
  set +a
  
  envsubst < "$KONG_CONFIG_TEMPLATE" > "$KONG_CONFIG_OUTPUT"
  
  echo -e "${GREEN}✓ Kong configuration generated at $KONG_CONFIG_OUTPUT${NC}"
}

# Main execution
main() {
  # Create templates directory if it doesn't exist
  mkdir -p "$CONFIG_DIR/templates"
  
  # Generate merged configuration
  generate_merged_config
  
  # Generate .env file
  generate_env_file
  
  # Generate Docker Compose file
  generate_docker_compose
  
  # Generate Kong configuration
  generate_kong_config
  
  echo -e "${GREEN}✅ Configuration generation complete for $ENV environment${NC}"
  echo -e "${BLUE}Generated files:${NC}"
  echo -e "  - $GENERATED_DIR/merged-config.$ENV.yml"
  echo -e "  - $GENERATED_DIR/.env.$ENV"
  echo -e "  - $GENERATED_DIR/.env (symlink to current environment)"
  
  if [[ -f "$DOCKER_COMPOSE_OUTPUT" ]]; then
    echo -e "  - $DOCKER_COMPOSE_OUTPUT"
  fi
  
  if [[ -f "$KONG_CONFIG_OUTPUT" ]]; then
    echo -e "  - $KONG_CONFIG_OUTPUT"
  fi
  
  echo ""
  echo -e "${BLUE}To use this configuration:${NC}"
  echo -e "1. Copy the .env file to the project root:"
  echo -e "   cp $GENERATED_DIR/.env ."
  echo -e "2. Copy the Docker Compose file to the project root (if generated):"
  echo -e "   cp $GENERATED_DIR/docker-compose.$ENV.yml docker-compose.yml"
  echo -e "3. If using Kong, copy the Kong configuration:"
  echo -e "   cp $GENERATED_DIR/kong.$ENV.yml kong/kong.yml"
  echo -e "4. Restart your services:"
  echo -e "   docker-compose down && docker-compose up -d"
}

# Run the main function
main 