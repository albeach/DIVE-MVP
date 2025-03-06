#!/bin/bash
set -e

# Configuration Generator Script
# This script generates a consolidated .env file with all URLs consistently defined

# Default environment is development
ENV_PROFILE=${ENVIRONMENT:-development}

echo "Generating configuration for environment: $ENV_PROFILE"

# Load base configuration
if [ -f ".env.base" ]; then
  source .env.base
else
  echo "Error: .env.base not found"
  exit 1
fi

# Load environment-specific configuration
if [ -f ".env.$ENV_PROFILE" ]; then
  source .env.$ENV_PROFILE
else
  echo "Error: .env.$ENV_PROFILE not found"
  exit 1
fi

# Create a new consolidated .env file
ENV_FILE=".env"
echo "# Auto-generated configuration file for $ENV_PROFILE environment" > $ENV_FILE
echo "# Generated on $(date)" >> $ENV_FILE
echo "# DO NOT EDIT DIRECTLY - MODIFY .env.base and .env.$ENV_PROFILE INSTEAD" >> $ENV_FILE
echo "" >> $ENV_FILE

# Copy base configuration
echo "# ----- Base Configuration -----" >> $ENV_FILE
cat .env.base >> $ENV_FILE
echo "" >> $ENV_FILE

# Copy environment-specific configuration
echo "# ----- Environment-Specific Configuration ($ENV_PROFILE) -----" >> $ENV_FILE
cat .env.$ENV_PROFILE >> $ENV_FILE
echo "" >> $ENV_FILE

# Generate internal URLs for service-to-service communication
echo "# ----- Internal URLs (service-to-service) -----" >> $ENV_FILE
echo "# These URLs are used for communication between Docker services" >> $ENV_FILE
echo "INTERNAL_FRONTEND_URL=http://${FRONTEND_SERVICE}:${INTERNAL_FRONTEND_PORT}" >> $ENV_FILE
echo "INTERNAL_API_URL=http://${API_SERVICE}:${INTERNAL_API_PORT}" >> $ENV_FILE
echo "INTERNAL_KEYCLOAK_URL=http://${KEYCLOAK_SERVICE}:${INTERNAL_KEYCLOAK_PORT}" >> $ENV_FILE
echo "INTERNAL_KEYCLOAK_AUTH_URL=http://${KEYCLOAK_SERVICE}:${INTERNAL_KEYCLOAK_PORT}${KEYCLOAK_AUTH_PATH}" >> $ENV_FILE
echo "INTERNAL_KONG_ADMIN_URL=http://${KONG_SERVICE}:${INTERNAL_KONG_ADMIN_PORT}" >> $ENV_FILE
echo "INTERNAL_KONG_PROXY_URL=http://${KONG_SERVICE}:${INTERNAL_KONG_PROXY_PORT}" >> $ENV_FILE
echo "INTERNAL_MONGODB_URL=mongodb://${MONGODB_SERVICE}:${INTERNAL_MONGODB_PORT}" >> $ENV_FILE
echo "INTERNAL_POSTGRES_URL=postgres://${POSTGRES_SERVICE}:${INTERNAL_POSTGRES_PORT}" >> $ENV_FILE
echo "INTERNAL_OPA_URL=http://${OPA_SERVICE}:${INTERNAL_OPA_PORT}" >> $ENV_FILE
echo "INTERNAL_OPENLDAP_URL=ldap://${OPENLDAP_SERVICE}:${INTERNAL_OPENLDAP_PORT}" >> $ENV_FILE
echo "INTERNAL_GRAFANA_URL=http://${GRAFANA_SERVICE}:${INTERNAL_GRAFANA_PORT}" >> $ENV_FILE
echo "INTERNAL_PROMETHEUS_URL=http://${PROMETHEUS_SERVICE}:${INTERNAL_PROMETHEUS_PORT}" >> $ENV_FILE
echo "INTERNAL_PHPLDAPADMIN_URL=http://${PHPLDAPADMIN_SERVICE}:${INTERNAL_PHPLDAPADMIN_PORT}" >> $ENV_FILE
echo "INTERNAL_KONGA_URL=http://${KONGA_SERVICE}:${INTERNAL_KONGA_PORT}" >> $ENV_FILE
echo "INTERNAL_MONGODB_EXPORTER_URL=http://${MONGODB_EXPORTER_SERVICE}:${INTERNAL_MONGODB_EXPORTER_PORT}" >> $ENV_FILE
echo "INTERNAL_NODE_EXPORTER_URL=http://${NODE_EXPORTER_SERVICE}:${INTERNAL_NODE_EXPORTER_PORT}" >> $ENV_FILE
echo "INTERNAL_KONG_DATABASE_URL=postgres://${KONG_DATABASE_SERVICE}:${INTERNAL_POSTGRES_PORT}" >> $ENV_FILE
echo "" >> $ENV_FILE

# Format external URLs based on port configuration
format_external_url() {
  local domain=$1
  local port=$2
  
  if [ "$USE_HTTPS" = "true" ]; then
    # For HTTPS, only add port if it's not the standard 443
    if [ "$port" = "443" ]; then
      echo "https://${domain}.${BASE_DOMAIN}"
    else
      echo "https://${domain}.${BASE_DOMAIN}:${port}"
    fi
  else
    # For HTTP, only add port if it's not the standard 80
    if [ "$port" = "80" ]; then
      echo "http://${domain}.${BASE_DOMAIN}"
    else
      echo "http://${domain}.${BASE_DOMAIN}:${port}"
    fi
  fi
}

# Generate external URLs for browser-to-service communication
echo "# ----- External URLs (browser-to-service) -----" >> $ENV_FILE
echo "# These URLs are used for browser access to services" >> $ENV_FILE
echo "PUBLIC_FRONTEND_URL=$(format_external_url $FRONTEND_DOMAIN $FRONTEND_PORT)" >> $ENV_FILE
echo "PUBLIC_API_URL=$(format_external_url $API_DOMAIN $API_PORT)" >> $ENV_FILE
echo "PUBLIC_KEYCLOAK_URL=$(format_external_url $KEYCLOAK_DOMAIN $KEYCLOAK_PORT)" >> $ENV_FILE
echo "PUBLIC_KEYCLOAK_AUTH_URL=$(format_external_url $KEYCLOAK_DOMAIN $KEYCLOAK_PORT)${KEYCLOAK_AUTH_PATH}" >> $ENV_FILE
echo "PUBLIC_KONG_ADMIN_URL=$(format_external_url $KONG_DOMAIN $KONG_ADMIN_PORT)" >> $ENV_FILE
echo "PUBLIC_KONG_PROXY_URL=$(format_external_url $KONG_DOMAIN $KONG_PROXY_PORT)" >> $ENV_FILE
echo "PUBLIC_GRAFANA_URL=$(format_external_url $GRAFANA_DOMAIN $GRAFANA_PORT)" >> $ENV_FILE
echo "PUBLIC_MONGODB_EXPRESS_URL=$(format_external_url $MONGODB_EXPRESS_DOMAIN $MONGODB_EXPRESS_PORT)" >> $ENV_FILE
echo "PUBLIC_PHPLDAPADMIN_URL=$(format_external_url $PHPLDAPADMIN_DOMAIN $PHPLDAPADMIN_PORT)" >> $ENV_FILE
echo "PUBLIC_PROMETHEUS_URL=$(format_external_url $PROMETHEUS_DOMAIN $PROMETHEUS_PORT)" >> $ENV_FILE
echo "PUBLIC_OPA_URL=$(format_external_url $OPA_DOMAIN $OPA_PORT)" >> $ENV_FILE
echo "PUBLIC_KONGA_URL=$(format_external_url $KONG_DOMAIN $KONGA_PORT)" >> $ENV_FILE
echo "PUBLIC_MONGODB_EXPORTER_URL=$(format_external_url $MONGODB_EXPORTER_DOMAIN $MONGODB_EXPORTER_PORT)" >> $ENV_FILE
echo "PUBLIC_NODE_EXPORTER_URL=$(format_external_url $NODE_EXPORTER_DOMAIN $NODE_EXPORTER_PORT)" >> $ENV_FILE

# Generate auth-specific connection strings
echo "" >> $ENV_FILE
echo "# ----- Authentication Connection Strings -----" >> $ENV_FILE
echo "# These are specialized connection strings for authentication" >> $ENV_FILE
echo "MONGODB_AUTH_URL=mongodb://${MONGO_APP_USERNAME}:${MONGO_APP_PASSWORD}@${MONGODB_SERVICE}:${INTERNAL_MONGODB_PORT}/dive25" >> $ENV_FILE
echo "MONGODB_ADMIN_URL=mongodb://${MONGO_ROOT_USERNAME}:${MONGO_ROOT_PASSWORD}@${MONGODB_SERVICE}:${INTERNAL_MONGODB_PORT}/admin" >> $ENV_FILE
echo "POSTGRES_KEYCLOAK_URL=jdbc:postgresql://${POSTGRES_SERVICE}:${INTERNAL_POSTGRES_PORT}/keycloak" >> $ENV_FILE
echo "LDAP_AUTH_URL=ldap://${OPENLDAP_SERVICE}:${INTERNAL_OPENLDAP_PORT}/${LDAP_SEARCH_BASE}" >> $ENV_FILE

echo "Configuration generated successfully!"
echo "Generated .env file with consistent URLs for all services."
echo ""
echo "To apply this configuration:"
echo "1. Run 'docker-compose down' to stop all services"
echo "2. Run 'docker-compose up -d' to start all services with the new configuration" 