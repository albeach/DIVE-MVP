#!/bin/bash
#
# DIVE25 Hosts File Setup Script
# ==============================
#
# This script sets up /etc/hosts entries for DIVE25 local development and testing.
#
# Usage:
#   ./scripts/setup-hosts-updated.sh [environment]
#
# Arguments:
#   environment - The environment to set up hosts for (dev, staging, prod)
#                 Defaults to the value in ENVIRONMENT or staging if not set

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if running as root/sudo
if [ "$(id -u)" -ne 0 ]; then
   echo -e "${RED}This script must be run as root or with sudo${NC}" 
   exit 1
fi

# Set environment
ENV=${1:-${ENVIRONMENT:-staging}}
if [[ ! "$ENV" =~ ^(dev|staging|prod)$ ]]; then
  echo -e "${RED}Error: Invalid environment '$ENV'. Must be one of: dev, staging, prod${NC}"
  exit 1
fi

# Load configuration
CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/config/generated"
ENV_FILE="$CONFIG_DIR/.env.$ENV"

if [[ ! -f "$ENV_FILE" ]]; then
  echo -e "${RED}Error: Environment file $ENV_FILE not found${NC}"
  echo -e "${YELLOW}Run ./scripts/generate-config.sh $ENV first to generate the configuration${NC}"
  exit 1
fi

# Source the environment file
source "$ENV_FILE"

echo -e "${BLUE}Setting up hosts file entries for DIVE25 ${GREEN}$ENV${BLUE} environment...${NC}"

# Define the hosts to add based on the configuration
HOSTS=()

add_host() {
  local domain=$1
  local subdomain=$2
  
  if [[ -n "$subdomain" ]]; then
    HOSTS+=("$subdomain.$domain")
  else
    HOSTS+=("$domain")
  fi
}

# Add base domain
add_host "$BASE_DOMAIN"

# Add service domains
add_host "$BASE_DOMAIN" "$FRONTEND_DOMAIN"
add_host "$BASE_DOMAIN" "$API_DOMAIN"
add_host "$BASE_DOMAIN" "$KEYCLOAK_DOMAIN"
add_host "$BASE_DOMAIN" "$KONG_DOMAIN"
add_host "$BASE_DOMAIN" "$GRAFANA_DOMAIN"
add_host "$BASE_DOMAIN" "$MONGODB_EXPRESS_DOMAIN"
add_host "$BASE_DOMAIN" "$PHPLDAPADMIN_DOMAIN"
add_host "$BASE_DOMAIN" "$PROMETHEUS_DOMAIN"
add_host "$BASE_DOMAIN" "$OPA_DOMAIN"
add_host "$BASE_DOMAIN" "$KONGA_DOMAIN"
add_host "$BASE_DOMAIN" "$MONGODB_EXPORTER_DOMAIN"
add_host "$BASE_DOMAIN" "$NODE_EXPORTER_DOMAIN"

# Check if entries already exist
HOSTS_FILE="/etc/hosts"
HOSTS_BACKUP="${HOSTS_FILE}.bak.$(date +%Y%m%d%H%M%S)"

# Make a backup of the hosts file
cp $HOSTS_FILE $HOSTS_BACKUP
echo -e "${GREEN}Created backup of hosts file at $HOSTS_BACKUP${NC}"

# Add entries if they don't exist
for HOST in "${HOSTS[@]}"; do
    if grep -q "^127.0.0.1 $HOST" $HOSTS_FILE; then
        echo -e "${YELLOW}Host entry for $HOST already exists${NC}"
    else
        echo -e "${GREEN}Adding host entry for $HOST${NC}"
        echo "127.0.0.1 $HOST" >> $HOSTS_FILE
    fi
done

echo -e "${GREEN}Host entries setup complete.${NC}"
echo ""
echo -e "${BLUE}You can now access the following URLs:${NC}"

# Function to format URL based on protocol and port
format_url() {
  local protocol=$1
  local domain=$2
  local port=$3
  
  if [[ "$protocol" == "https" && "$port" == "443" ]]; then
    echo "${protocol}://${domain}"
  elif [[ "$protocol" == "http" && "$port" == "80" ]]; then
    echo "${protocol}://${domain}"
  else
    echo "${protocol}://${domain}:${port}"
  fi
}

# Display all URLs for the services
echo -e "- Frontend: $(format_url $PROTOCOL $FRONTEND_DOMAIN.$BASE_DOMAIN $FRONTEND_PORT)"
echo -e "- API: $(format_url $PROTOCOL $API_DOMAIN.$BASE_DOMAIN $API_PORT)"
echo -e "- Keycloak: $(format_url $PROTOCOL $KEYCLOAK_DOMAIN.$BASE_DOMAIN $KEYCLOAK_PORT)"
echo -e "- Kong: $(format_url $PROTOCOL $KONG_DOMAIN.$BASE_DOMAIN $KONG_PROXY_PORT)"
echo -e "- Grafana: $(format_url $PROTOCOL $GRAFANA_DOMAIN.$BASE_DOMAIN $GRAFANA_PORT)"
echo -e "- MongoDB Express: $(format_url $PROTOCOL $MONGODB_EXPRESS_DOMAIN.$BASE_DOMAIN $MONGODB_EXPRESS_PORT)"
echo -e "- phpLDAPadmin: $(format_url $PROTOCOL $PHPLDAPADMIN_DOMAIN.$BASE_DOMAIN $PHPLDAPADMIN_PORT)"
echo -e "- Prometheus: $(format_url $PROTOCOL $PROMETHEUS_DOMAIN.$BASE_DOMAIN $PROMETHEUS_PORT)"
echo -e "- OPA: $(format_url $PROTOCOL $OPA_DOMAIN.$BASE_DOMAIN $OPA_PORT)"
echo -e "- Konga: $(format_url $PROTOCOL $KONGA_DOMAIN.$BASE_DOMAIN $KONGA_PORT)"
echo ""
echo -e "${BLUE}To test the application, navigate to $(format_url $PROTOCOL $FRONTEND_DOMAIN.$BASE_DOMAIN $FRONTEND_PORT) in your browser.${NC}" 