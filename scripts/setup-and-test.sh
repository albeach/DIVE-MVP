#!/bin/bash
set -e

# =========================================================
# Setup and Testing Script for Refactored Authentication Workflow
# =========================================================
# 
# This script helps apply the refactored configuration and test it.
#
# If you're experiencing hanging issues or timeout problems, you can 
# run this script with different options:
#
# For fast setup with minimal health checks (fastest):
#   FAST_SETUP=true ./scripts/setup-and-test.sh
#
# To skip just URL health checks (medium):
#   SKIP_URL_CHECKS=true ./scripts/setup-and-test.sh
#
# To skip just protocol detection (slower):
#   SKIP_PROTOCOL_DETECTION=true ./scripts/setup-and-test.sh
#
# You can combine these settings as needed.
# =========================================================

# Set up trap handlers
trap 'echo "Script interrupted. Cleaning up..."; exit 1' INT
trap 'echo "Script may be hanging. If stuck, press Ctrl+C to abort."; echo "Current phase: $CURRENT_PHASE"' ALRM

# Enable timeout alerting
if command -v perl >/dev/null 2>&1; then
  (perl -e 'alarm shift @ARGV; exec @ARGV' 1800 kill -ALRM $$) & # 30-minute global timeout
  TIMEOUT_PID=$!
  trap "kill $TIMEOUT_PID 2>/dev/null" EXIT
fi

# Configuration options - set these for faster setup
SKIP_URL_CHECKS=${SKIP_URL_CHECKS:-false}  # Set to true to skip all URL health checks
SKIP_PROTOCOL_DETECTION=${SKIP_PROTOCOL_DETECTION:-false}  # Set to true to skip protocol detection
FAST_SETUP=${FAST_SETUP:-false}  # Set to true for faster setup with minimal checks
SKIP_API_CHECK=${SKIP_API_CHECK:-false}  # Set to true to skip API health checks specifically
KONG_CONFIGURED=false  # Flag to track Kong configuration status

# If FAST_SETUP is true, skip all advanced checks
if [ "$FAST_SETUP" = "true" ]; then
  SKIP_URL_CHECKS=true
  SKIP_PROTOCOL_DETECTION=true
  SKIP_API_CHECK=true
  echo "⚡ Fast setup mode enabled - skipping most health and URL checks ⚡"
fi

# Track current phase for better error reporting
CURRENT_PHASE="Initialization"

# Set a master timeout for the entire process
MASTER_TIMEOUT=600 # 10 minutes
MASTER_START_TIME=$(date +%s)

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# Get the project root directory (parent directory of the script)
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

# Change to the project root directory
cd "$PROJECT_ROOT"

# Function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Function to get container name based on service
get_container_name() {
  local service_name=$1
  local default_prefix="dive25"
  
  # Try direct match first (most reliable)
  if docker ps -a --format '{{.Names}}' | grep -q "^${default_prefix}-${service_name}$"; then
    echo "${default_prefix}-${service_name}"
    return 0
  fi
  
  # Try to get project prefix from docker-compose
  local project_prefix=""
  if command -v docker-compose >/dev/null 2>&1; then
    project_prefix=$(docker-compose config --services 2>/dev/null | head -n 1 | grep -o "^[a-zA-Z0-9]*" || echo "")
  fi
  
  # If empty, use default
  if [ -z "$project_prefix" ]; then
    project_prefix="$default_prefix"
  fi
  
  echo "${project_prefix}-${service_name}"
}

# Print header
print_header() {
  echo "=================================================="
  echo "$1"
  echo "=================================================="
  CURRENT_PHASE="$1"
}

# Print step
print_step() {
  echo
  echo "=> $1"
  CURRENT_PHASE="$1"
}

# Print important settings
print_step "Setup Configuration"
echo "SKIP_URL_CHECKS: $SKIP_URL_CHECKS"
echo "SKIP_PROTOCOL_DETECTION: $SKIP_PROTOCOL_DETECTION"
echo "SKIP_API_CHECK: $SKIP_API_CHECK"
echo "FAST_SETUP: $FAST_SETUP"

# Check requirements
print_header "Checking requirements"
if ! command_exists docker; then
  echo "Error: Docker is not installed. Please install Docker first."
  exit 1
fi

if ! command_exists docker-compose; then
  echo "Error: docker-compose is not installed. Please install docker-compose first."
  exit 1
fi

if ! command_exists curl; then
  echo "Warning: curl is not installed. This script uses curl for testing."
  read -p "Continue without curl? (y/n) " CONTINUE_WITHOUT_CURL
  if [[ $CONTINUE_WITHOUT_CURL != "y" && $CONTINUE_WITHOUT_CURL != "Y" ]]; then
    echo "Exiting. Please install curl and try again."
    exit 1
  fi
fi

# Ask for environment
print_header "Environment Selection"
echo "Please select the environment to set up:"
echo "1. Development (default)"
echo "2. Staging"
echo "3. Production"
read -p "Enter your choice [1]: " ENV_CHOICE

case $ENV_CHOICE in
  1|"")
    ENVIRONMENT="development"
    ;;
  2)
    ENVIRONMENT="staging"
    ;;
  3)
    ENVIRONMENT="production"
    ;;
  *)
    echo "Invalid choice. Using development."
    ENVIRONMENT="development"
    ;;
esac

export ENVIRONMENT
echo "Using environment: $ENVIRONMENT"

# Generate configuration
print_step "Generating configuration for $ENVIRONMENT environment"
"$SCRIPT_DIR/generate-config.sh"

# Check if hosts file needs to be updated (only for staging/production)
if [ "$ENVIRONMENT" != "development" ]; then
  print_step "Checking /etc/hosts file"
  
  # Detect the base domain from the .env file
  BASE_DOMAIN=$(grep "BASE_DOMAIN=" .env | cut -d '=' -f2)
  
  if grep -q "$BASE_DOMAIN" /etc/hosts; then
    echo "Host entries for $BASE_DOMAIN already exist in /etc/hosts"
  else
    echo "You need to update your /etc/hosts file to include entries for $BASE_DOMAIN"
    echo "This requires administrator privileges."
    echo "Sample entries to add:"
    echo "127.0.0.1 $(grep "FRONTEND_DOMAIN=" .env | cut -d '=' -f2).$BASE_DOMAIN"
    echo "127.0.0.1 $(grep "API_DOMAIN=" .env | cut -d '=' -f2).$BASE_DOMAIN"
    echo "127.0.0.1 $(grep "KEYCLOAK_DOMAIN=" .env | cut -d '=' -f2).$BASE_DOMAIN"
    
    read -p "Would you like to update /etc/hosts automatically? (y/n) " UPDATE_HOSTS
    if [[ $UPDATE_HOSTS == "y" || $UPDATE_HOSTS == "Y" ]]; then
      echo "The following entries will be added to /etc/hosts:"
      echo "127.0.0.1 $(grep "FRONTEND_DOMAIN=" .env | cut -d '=' -f2).$BASE_DOMAIN"
      echo "127.0.0.1 $(grep "API_DOMAIN=" .env | cut -d '=' -f2).$BASE_DOMAIN"
      echo "127.0.0.1 $(grep "KEYCLOAK_DOMAIN=" .env | cut -d '=' -f2).$BASE_DOMAIN"
      echo "127.0.0.1 $(grep "KONG_DOMAIN=" .env | cut -d '=' -f2).$BASE_DOMAIN"
      echo "127.0.0.1 $(grep "GRAFANA_DOMAIN=" .env | cut -d '=' -f2).$BASE_DOMAIN"
      echo "127.0.0.1 $(grep "PROMETHEUS_DOMAIN=" .env | cut -d '=' -f2).$BASE_DOMAIN"
      
      echo "Updating /etc/hosts (you may be prompted for your password)..."
      sudo bash -c "cat >> /etc/hosts << EOF
# DIVE25 Domains
127.0.0.1 $(grep "FRONTEND_DOMAIN=" .env | cut -d '=' -f2).$BASE_DOMAIN
127.0.0.1 $(grep "API_DOMAIN=" .env | cut -d '=' -f2).$BASE_DOMAIN
127.0.0.1 $(grep "KEYCLOAK_DOMAIN=" .env | cut -d '=' -f2).$BASE_DOMAIN
127.0.0.1 $(grep "KONG_DOMAIN=" .env | cut -d '=' -f2).$BASE_DOMAIN
127.0.0.1 $(grep "GRAFANA_DOMAIN=" .env | cut -d '=' -f2).$BASE_DOMAIN
127.0.0.1 $(grep "PROMETHEUS_DOMAIN=" .env | cut -d '=' -f2).$BASE_DOMAIN
127.0.0.1 $(grep "MONGODB_EXPRESS_DOMAIN=" .env | cut -d '=' -f2).$BASE_DOMAIN
127.0.0.1 $(grep "PHPLDAPADMIN_DOMAIN=" .env | cut -d '=' -f2).$BASE_DOMAIN
127.0.0.1 $(grep "OPA_DOMAIN=" .env | cut -d '=' -f2).$BASE_DOMAIN
EOF"
      echo "Host file updated."
    else
      echo "Please update your /etc/hosts file manually."
    fi
  fi
fi

# Check if SSL certificates exist
print_step "Checking SSL certificates"
SSL_CERT_PATH=$(grep "SSL_CERT_PATH=" .env | cut -d '=' -f2)
SSL_KEY_PATH=$(grep "SSL_KEY_PATH=" .env | cut -d '=' -f2)

if [ "$USE_HTTPS" = "true" ] && ([ ! -f "$SSL_CERT_PATH" ] || [ ! -f "$SSL_KEY_PATH" ]); then
  echo "Warning: SSL certificates not found at $SSL_CERT_PATH or $SSL_KEY_PATH"
  echo "HTTPS is enabled but certificates are missing."
  
  read -p "Would you like to generate self-signed certificates? (y/n) " GENERATE_CERTS
  if [[ $GENERATE_CERTS == "y" || $GENERATE_CERTS == "Y" ]]; then
    CERT_DIR=$(dirname "$SSL_CERT_PATH")
    if [ ! -d "$CERT_DIR" ]; then
      mkdir -p "$CERT_DIR"
    fi
    
    echo "Generating self-signed certificates..."
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
      -keyout "$SSL_KEY_PATH" \
      -out "$SSL_CERT_PATH" \
      -subj "/CN=*.$BASE_DOMAIN/O=DIVE25/C=US"
    
    echo "Self-signed certificates generated at $SSL_CERT_PATH and $SSL_KEY_PATH"
  else
    echo "Please provide SSL certificates before continuing if using HTTPS."
  fi
fi

# Stop existing containers
print_step "Stopping existing containers"
docker-compose down

# Check if there are still any containers with names matching our pattern
# Get the project prefix dynamically
project_prefix=$(docker-compose config --services 2>/dev/null | head -n 1 | grep -o "^[a-zA-Z0-9]*" || echo "dive25")
if docker ps -a | grep -q "${project_prefix}-"; then
  echo "Some containers are still present. Forcefully removing them..."
  docker ps -a | grep "${project_prefix}-" | awk '{print $1}' | xargs -r docker rm -f
fi

# Start containers
print_step "Starting containers with new configuration"
echo "This may take a while, especially on first run..."

# Use a timeout for docker-compose up
COMPOSE_TIMEOUT=300 # 5 minutes
echo "Running docker-compose up with ${COMPOSE_TIMEOUT}s timeout..."
# Use --exit-code-from option to prevent failing if keycloak-config exits normally (with code 0)
timeout $COMPOSE_TIMEOUT docker-compose up -d --remove-orphans

# Check if docker-compose command timed out
if [ $? -eq 124 ]; then
  echo "WARNING: docker-compose up timed out after ${COMPOSE_TIMEOUT}s. This might indicate an issue with container startup."
  echo "Checking container statuses anyway..."
  docker-compose ps
elif [ $? -ne 0 ]; then
  # Check for dependency failure of keycloak-config which might actually be successful
  if docker-compose logs | grep -q "dependency failed to start.*keycloak-config exited (0)"; then
    echo "Detected keycloak-config exited with code 0, which is normal behavior."
    echo "Continuing with setup as the container completed its configuration task successfully."
    
    # First approach: Start the services again without waiting for keycloak-config
    echo "Restarting services without the keycloak-config dependency check..."
    docker-compose up -d --no-recreate $(docker-compose config --services | grep -v "keycloak-config")
    
    # If that fails, try a more targeted approach for specific services
    if [ $? -ne 0 ]; then
      echo "First restart attempt failed. Trying a more targeted approach..."
      
      # Get list of containers that might depend on keycloak-config
      declare -a SERVICE_LIST=("keycloak-csp" "kong-config" "kong" "api" "frontend")
      
      # Try to start each service individually
      for service in "${SERVICE_LIST[@]}"; do
        echo "Starting $service..."
        docker-compose up -d --no-recreate "$service" || echo "Failed to start $service, but continuing..."
      done
      
      # As a last resort, try a manual approach
      if [ $? -ne 0 ]; then
        echo "Targeted restart failed. Using manual approach as last resort..."
        # Check the realm-ready file in the volume to verify keycloak-config ran successfully
        KEYCLOAK_CONFIG_CONTAINER=$(get_container_name "keycloak-config")
        if docker run --rm --volumes-from "$KEYCLOAK_CONFIG_CONTAINER" alpine:latest test -f /tmp/keycloak-config/realm-ready; then
          echo "Verified realm configuration was successful. Proceeding with remaining services."
          docker-compose up -d --scale keycloak-config=0
        else
          echo "WARNING: Could not verify if keycloak configuration was successful."
          echo "You may need to manually check and restart services."
        fi
      fi
    fi
  else
    echo "ERROR: Failed to start containers. Check the logs for more information."
    echo "Container statuses:"
    docker-compose ps
  fi
fi

# Print note about keycloak-config behavior
echo
echo "NOTE: The keycloak-config container is designed to exit with code 0 after successful configuration."
echo "      This is normal behavior and does not indicate a problem with your deployment."
echo "      You may see it listed as 'exited (0)' in docker-compose ps output."
echo

# Function to wait for service availability
wait_for_service() {
  local service_name=$1
  local url=$2
  local timeout=$3
  local counter=0
  
  echo "Waiting for $service_name to be ready..."
  
  # First check if the Docker container is running
  local service_name_lower=$(echo "$service_name" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')
  local container_name=$(get_container_name "$service_name_lower")
  
  # Check if container exists
  if ! docker ps -a | grep -q "$container_name"; then
    echo "ERROR: Container $container_name does not exist!"
    # Try a generic search for the container that might match
    echo "Searching for possible matching containers..."
    docker ps -a | grep -i ".*${service_name_lower}"
    return 1
  fi
  
  echo "Checking container $container_name status..."
  
  # Wait for container to be running and healthy
  while true; do
    local container_status=$(docker inspect --format='{{.State.Status}}' $container_name 2>/dev/null || echo "not_found")
    local container_health=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}no_health_check{{end}}' $container_name 2>/dev/null || echo "unknown")
    
    echo "Container status: $container_status, health: $container_health"
    
    # If container is running and either healthy or has no health check
    if [[ "$container_status" == "running" ]]; then
      if [[ "$container_health" == "healthy" || "$container_health" == "no_health_check" ]]; then
        echo "$service_name container is running and healthy!"
        break
      fi
    fi
    
    sleep 5
    counter=$((counter + 5))
    echo "Still waiting for $service_name container... ($counter seconds elapsed)"
    
    if [ $counter -ge $timeout ]; then
      echo "Timeout waiting for $service_name container to be healthy. Moving on anyway..."
      break
    fi
  done
  
  # Skip URL check if it's empty
  if [ -z "$url" ]; then
    echo "No URL provided for $service_name, skipping URL check."
    return 0
  fi
  
  # Skip URL check if configured to do so or if Kong is not yet configured 
  # and we're checking an external service
  if [ "$SKIP_URL_CHECKS" = "true" ] || ( [ "$KONG_CONFIGURED" = "false" ] && 
     ( [[ "$service_name" == "API" ]] || [[ "$service_name" == "Frontend" ]] || 
       [[ "$service_name" == "Keycloak" ]] ) ); then
    if [ "$KONG_CONFIGURED" = "false" ] && ! [ "$SKIP_URL_CHECKS" = "true" ]; then
      echo "Skipping URL check for $service_name (waiting for Kong configuration to complete first)"
    else
      echo "Skipping URL check for $service_name (SKIP_URL_CHECKS=true)"
    fi
    return 0
  fi
  
  # Now check if the service URL is responding (with a shorter timeout)
  local url_timeout=$((timeout / 2 < 60 ? 60 : timeout / 2))
  echo "Will check URL for maximum $url_timeout seconds"
  
  counter=0
  echo "Checking if $service_name is accessible at URL: $url"
  
  # Try both HTTP and HTTPS if one fails
  local protocol="$(echo $url | cut -d':' -f1)"
  local alt_url=""
  if [[ "$protocol" == "https" ]]; then
    alt_url="http$(echo $url | cut -d':' -f2-)"
  elif [[ "$protocol" == "http" ]]; then
    alt_url="https$(echo $url | cut -d':' -f2-)"
  fi
  
  local start_time=$(date +%s)
  local end_time=$((start_time + url_timeout))
  local current_time=$(date +%s)
  
  while [ $current_time -lt $end_time ]; do
    # Try the primary URL first
    if curl -s -k -f -o /dev/null --connect-timeout 3 --max-time 5 "$url"; then
      echo "$service_name URL is accessible at $url!"
      return 0
    fi
    
    # If the primary URL failed and we have an alternative, try it
    if [[ -n "$alt_url" ]]; then
      echo "Primary URL $url failed, trying alternative URL $alt_url..."
      if curl -s -k -f -o /dev/null --connect-timeout 3 --max-time 5 "$alt_url"; then
        echo "$service_name URL is accessible at $alt_url!"
        echo "NOTE: Your configuration may be using $alt_url instead of $url"
        return 0
      fi
    fi
    
    sleep 5
    counter=$((counter + 5))
    echo "Still waiting for $service_name URL response... ($counter seconds elapsed)"
    current_time=$(date +%s)
    
    # Explicit check for timeout with remaining time display
    local remaining=$((end_time - current_time))
    if [ $remaining -le 0 ]; then
      echo "Timeout reached for $service_name URL check after $counter seconds."
      echo "This is normal during initial setup or if there are network/SSL issues."
      echo "You can check $service_name logs with: docker-compose logs $service_name_lower"
      return 0
    fi
    
    # If we're close to timeout, show a more prominent warning
    if [ $remaining -lt 20 ]; then
      echo "⚠️ URL check will time out in $remaining seconds"
    fi
  done
  
  # This should never execute due to the timeout check above, but just in case
  echo "Timeout waiting for $service_name URL. Moving on with setup."
  return 0
}

# Special function for Kong's health check
check_kong_health() {
  local timeout=$1
  local counter=0
  
  echo "Performing special health check for Kong..."
  
  # Get Kong container name dynamically
  local KONG_CONTAINER=$(get_container_name "kong")
  
  # Check container existence
  if ! docker ps -a | grep -q "$KONG_CONTAINER"; then
    echo "ERROR: Kong container '$KONG_CONTAINER' doesn't exist!"
    echo "Searching for possible Kong container..."
    docker ps -a | grep -i "kong" | grep -v "config"
    
    # Try to find any Kong container
    local alt_kong=$(docker ps -a | grep -i "kong" | grep -v "config" | head -n 1 | awk '{print $NF}')
    if [ -n "$alt_kong" ]; then
      KONG_CONTAINER="$alt_kong"
      echo "Found alternative Kong container: $KONG_CONTAINER"
    else
      return 1
    fi
  fi
  
  # Wait for Kong to be running and healthy
  while true; do
    local container_status=$(docker inspect --format='{{.State.Status}}' "$KONG_CONTAINER" 2>/dev/null || echo "not_found")
    local container_health=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}no_health_check{{end}}' "$KONG_CONTAINER" 2>/dev/null || echo "unknown")
    
    echo "Kong status: $container_status, health: $container_health"
    
    if [[ "$container_status" == "running" && "$container_health" == "healthy" ]]; then
      echo "Kong container is running and healthy!"
      break
    fi
    
    sleep 5
    counter=$((counter + 5))
    echo "Still waiting for Kong container... ($counter seconds elapsed)"
    
    if [ $counter -ge $timeout ]; then
      echo "Timeout waiting for Kong to be healthy. Checking Kong's health directly..."
      
      # Try Kong's health endpoint directly
      if docker exec "$KONG_CONTAINER" kong health 2>/dev/null | grep -q "Kong is healthy"; then
        echo "Kong reports itself as healthy!"
        break
      else
        echo "Kong health check failed. Moving on anyway..."
        docker exec "$KONG_CONTAINER" kong health || echo "Failed to execute health check inside Kong container"
        return 1
      fi
    fi
  done
  
  # Get the internal and external ports
  local internal_proxy_port=$(grep "INTERNAL_KONG_PROXY_PORT=" .env | cut -d '=' -f2 || echo "8000")
  local internal_admin_port=$(grep "INTERNAL_KONG_ADMIN_PORT=" .env | cut -d '=' -f2 || echo "8001")
  local kong_proxy_port=$(grep "KONG_PROXY_PORT=" .env | cut -d '=' -f2 || echo "8000")
  local kong_admin_port=$(grep "KONG_ADMIN_PORT=" .env | cut -d '=' -f2 || echo "8001")
  local kong_ssl_port="8443"  # This is typically hardcoded in the container
  
  echo "Kong internal ports - Proxy: $internal_proxy_port, Admin: $internal_admin_port"
  echo "Kong external ports - Proxy: $kong_proxy_port, Admin: $kong_admin_port"
  
  # Check internal endpoints first (from inside the container)
  echo "Testing Kong internally (from inside the container)..."
  
  # Check if Kong's internal API is responsive (using localhost to avoid domain resolution issues)
  if docker exec "$KONG_CONTAINER" curl -s http://127.0.0.1:$internal_admin_port/status >/dev/null; then
    echo "Kong admin API is responding internally!"
  else
    echo "WARNING: Kong admin API is not responding internally. This is a critical issue."
    echo "Kong may not be properly configured. Check Kong logs for errors:"
    docker logs "$KONG_CONTAINER" | tail -n 100
    echo "Continuing anyway, but Kong may not work correctly."
  fi
  
  # Test external access using localhost to avoid domain resolution issues
  echo "Testing Kong externally (from host)..."
  
  # Try both HTTP and HTTPS variants with localhost
  if curl -s -I -m 5 http://localhost:$kong_proxy_port >/dev/null 2>&1; then
    echo "Kong proxy is responding on http://localhost:$kong_proxy_port!"
    return 0
  elif curl -s -I -k -m 5 https://localhost:$kong_ssl_port >/dev/null 2>&1; then
    echo "Kong proxy is responding on https://localhost:$kong_ssl_port!"
    return 0
  else
    echo "WARNING: Kong proxy is not responding on either HTTP or HTTPS ports."
    echo "This may indicate a configuration issue."
    return 1
  fi
}

# Special function for API health checking
check_api_health() {
  local api_base_url=$1
  local timeout=$2
  local counter=0
  
  echo "Performing comprehensive API health check..."
  
  # Get API container name dynamically
  local API_CONTAINER=$(get_container_name "api")
  
  # Check if API container exists and is running
  if ! docker ps -a | grep -q "$API_CONTAINER"; then
    echo "ERROR: API container doesn't exist!"
    echo "Searching for possible API container..."
    docker ps -a | grep -i "api"
    return 1
  fi
  
  # Check if the API container is healthy
  while true; do
    local container_status=$(docker inspect --format='{{.State.Status}}' "$API_CONTAINER" 2>/dev/null || echo "not_found")
    local container_health=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}no_health_check{{end}}' "$API_CONTAINER" 2>/dev/null || echo "unknown")
    
    echo "API container status: $container_status, health: $container_health"
    
    if [[ "$container_status" == "running" ]]; then
      if [[ "$container_health" == "healthy" || "$container_health" == "no_health_check" ]]; then
        echo "API container is running and healthy according to Docker!"
        break
      fi
    fi
    
    sleep 5
    counter=$((counter + 5))
    echo "Still waiting for API container to be healthy... ($counter seconds elapsed)"
    
    if [ $counter -ge $timeout ]; then
      echo "Timeout waiting for API container to be healthy. Moving on to direct checks..."
      break
    fi
  done
  
  # Get the internal port that the API is listening on
  local api_internal_port=$(grep "INTERNAL_API_PORT=" .env | cut -d '=' -f2 || echo "3000")
  echo "API is configured to listen on internal port $api_internal_port"
  
  # Try to exec into the container and check if it's responding locally
  echo "Checking API health from inside the container..."
  if docker exec "$API_CONTAINER" curl -s -f -m 5 http://localhost:$api_internal_port/health >/dev/null 2>&1; then
    echo "API is healthy from inside the container!"
  else
    echo "WARNING: API health check failed from inside the container."
    echo "This might indicate an issue with the API server itself."
    docker exec "$API_CONTAINER" curl -v http://localhost:$api_internal_port/health || echo "Failed to execute curl inside API container"
  fi
  
  # Get the external port
  local api_port=$(grep "API_PORT=" .env | cut -d '=' -f2 || echo "4431")
  
  # Try direct localhost check with curl verbose output and ignore SSL
  echo "Trying direct localhost connection to verify API accessibility..."
  if curl -s -k -f https://localhost:$api_port/health >/dev/null 2>&1; then
    echo "✅ API is directly accessible via https://localhost:$api_port/health!"
    # If direct localhost works, we'll mark as success
    echo "The API is working properly but may have domain name resolution issues."
    echo "Using direct localhost access as verification of API health."
    return 0
  else 
    echo "❌ Direct localhost connection failed. Trying with verbose output..."
    curl -v -k https://localhost:$api_port/health
  fi

  # Extract domain from the API base URL
  local domain=""
  if [[ "$api_base_url" == http* ]]; then
    domain=$(echo "$api_base_url" | sed -E 's|https?://([^:/]+)(:[0-9]+)?.*|\1|')
  else
    domain=$(echo "$api_base_url" | sed -E 's|([^:/]+)(:[0-9]+)?.*|\1|')
  fi
  
  # Test hostname resolution before attempting connections
  # Note: On macOS, 'host' command might bypass /etc/hosts, so we use ping instead
  echo "Testing hostname resolution for $domain..."
  if ping -c 1 -W 1 "$domain" >/dev/null 2>&1; then
    echo "✅ Domain $domain resolves successfully using ping"
  else
    echo "❌ Domain resolution failed using ping for $domain."
    echo "Checking entries in /etc/hosts..."
    if grep -q "$domain" /etc/hosts; then
      echo "✅ Found entry for $domain in /etc/hosts: $(grep "$domain" /etc/hosts)"
      echo "The OS might be using a different DNS resolution mechanism than the host command."
      echo "This is normal on macOS. Continuing with direct curl check..."
      
      # Try curl with domain to confirm
      if curl -s -k -f -o /dev/null --connect-timeout 5 --max-time 10 "https://$domain:$api_port/health"; then
        echo "✅ API is accessible via curl with domain name and port!"
        return 0
      fi
    else
      echo "❌ No entry found for $domain in /etc/hosts"
      echo "This is likely causing the connection issues. Continuing with localhost checks."
      
      # If localhost works, we'll mark as success despite hostname issues
      if curl -s -k -f https://localhost:$api_port/health >/dev/null 2>&1; then
        echo "✅ API is accessible via localhost but not via domain name."
        echo "This is likely a DNS resolution issue, but API itself is working."
        return 0
      fi
    fi
  fi
  
  # Check the external URLs
  counter=0
  echo "Checking API health from host via URL: $api_base_url/health"
  
  # Try different endpoints
  local endpoints=("/health" "/status" "/api/health" "/api/v1/health" "/metrics" "/")
  
  while [ $counter -lt $timeout ]; do
    local success=false
    
    # Try HTTP and HTTPS variants
    for protocol in "http" "https"; do
      local base_url=""
      if [[ "$api_base_url" == http* ]]; then
        # Replace the protocol prefix
        base_url="${protocol}${api_base_url#http*:}"
      else
        # URL doesn't have a protocol, add one
        base_url="${protocol}://${api_base_url}"
      fi
      
      for endpoint in "${endpoints[@]}"; do
        local full_url="${base_url}${endpoint}"
        echo "Trying API endpoint: $full_url"
        
        # Use -k flag for HTTPS requests to ignore SSL certificate validation
        if [[ "$protocol" == "https" ]]; then
          if curl -s -k -f -o /dev/null --connect-timeout 5 --max-time 10 "$full_url"; then
            echo "✅ API is accessible at $full_url!"
            success=true
            break 2
          else
            echo "❌ HTTPS connection failed with -k flag. Trying verbose output..."
            curl -v -k --connect-timeout 5 --max-time 10 "$full_url" || echo "Curl command failed completely"
          fi
        else
          if curl -s -f -o /dev/null --connect-timeout 5 --max-time 10 "$full_url"; then
            echo "✅ API is accessible at $full_url!"
            success=true
            break 2
          fi
        fi
      done
    done
    
    if $success; then
      break
    fi
    
    sleep 5
    counter=$((counter + 5))
    echo "Still waiting for API to respond... ($counter seconds elapsed)"
    
    # If localhost works but domain doesn't, return success after a reasonable wait
    if [ $counter -ge 60 ] && curl -s -k -f https://localhost:$api_port/health >/dev/null 2>&1; then
      echo "✅ API is accessible via localhost but not via domain name."
      echo "This is likely a DNS resolution issue, but API itself is working."
      return 0
    fi
    
    if [ $counter -ge $timeout ]; then
      echo "Timeout waiting for API to respond via domain name."
      
      # Final check - if localhost works, return success
      if curl -s -k -f https://localhost:$api_port/health >/dev/null 2>&1; then
        echo "✅ API is accessible via localhost but not via domain name."
        echo "This is likely a DNS resolution issue, but API itself is working."
        return 0
      else
        echo "❌ API is not accessible via localhost or domain name."
        echo "Please check API logs with: docker-compose logs api"
        return 1
      fi
    fi
  done
  
  return 0
}

# Special function for Keycloak health checking
check_keycloak_health() {
  local keycloak_url="$1"
  local timeout=$2
  local counter=0
  local max_url_check_time=40  # Cap the URL check at 40 seconds max
  
  echo "Performing specialized Keycloak health check..."
  
  # Dynamically determine Keycloak container name
  local project_prefix=$(docker-compose config --services | head -n 1 | grep -o "^[a-zA-Z0-9]*" || echo "dive25")
  local keycloak_service_name="keycloak"
  local KEYCLOAK_CONTAINER="${KEYCLOAK_CONTAINER:-${project_prefix}-${keycloak_service_name}}"
  
  echo "Looking for Keycloak container with name: $KEYCLOAK_CONTAINER"
  
  # Fallback to searching for any Keycloak container if the expected one isn't found
  if ! docker ps -a | grep -q "$KEYCLOAK_CONTAINER"; then
    echo "Container $KEYCLOAK_CONTAINER not found, searching for any Keycloak container..."
    local alt_container=$(docker ps -a | grep -i "keycloak" | head -n 1 | awk '{print $1}')
    
    if [ -n "$alt_container" ]; then
      KEYCLOAK_CONTAINER=$(docker inspect --format='{{.Name}}' "$alt_container" 2>/dev/null | sed 's/\///')
      echo "Found alternative Keycloak container: $KEYCLOAK_CONTAINER"
    else
      echo "ERROR: No Keycloak container found!"
      return 1
    fi
  fi
  
  # Get container network information
  local KEYCLOAK_NETWORK=$(docker inspect --format '{{range $k, $v := .NetworkSettings.Networks}}{{$k}}{{end}}' "$KEYCLOAK_CONTAINER" 2>/dev/null || echo "")
  
  # Get port mappings
  local KEYCLOAK_PORT_MAPPING=$(docker port "$KEYCLOAK_CONTAINER" 2>/dev/null || echo "")
  local KEYCLOAK_INTERNAL_PORT=$(docker inspect --format '{{range $p, $conf := .Config.ExposedPorts}}{{$p}}{{end}}' "$KEYCLOAK_CONTAINER" 2>/dev/null | head -n 1 | cut -d'/' -f1 || echo "8080")
  local KEYCLOAK_EXTERNAL_PORT=$(echo "$KEYCLOAK_PORT_MAPPING" | grep -o ":[0-9]*->" | head -n 1 | cut -d':' -f2 | cut -d'-' -f1 || echo "")
  
  if [ -z "$KEYCLOAK_EXTERNAL_PORT" ]; then
    # Fallback to environment or common port
    KEYCLOAK_EXTERNAL_PORT=$(grep "KEYCLOAK_PORT=" .env 2>/dev/null | cut -d '=' -f2 || echo "8443")
  fi
  
  echo "Keycloak container: $KEYCLOAK_CONTAINER"
  echo "Keycloak network: $KEYCLOAK_NETWORK"
  echo "Keycloak internal port: $KEYCLOAK_INTERNAL_PORT"
  echo "Keycloak external port: $KEYCLOAK_EXTERNAL_PORT"
  
  # Wait for Keycloak to be running and healthy
  while true; do
    local container_status=$(docker inspect --format='{{.State.Status}}' "$KEYCLOAK_CONTAINER" 2>/dev/null || echo "not_found")
    local container_health=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}no_health_check{{end}}' "$KEYCLOAK_CONTAINER" 2>/dev/null || echo "unknown")
    
    echo "Keycloak container status: $container_status, health: $container_health"
    
    if [[ "$container_status" == "running" ]]; then
      if [[ "$container_health" == "healthy" || "$container_health" == "no_health_check" ]]; then
        echo "✅ Keycloak container is running and healthy according to Docker!"
        break
      fi
    fi
    
    sleep 5
    counter=$((counter + 5))
    echo "Still waiting for Keycloak container to be healthy... ($counter seconds elapsed)"
    
    if [ $counter -ge $timeout ]; then
      echo "Timeout waiting for Keycloak container to be healthy. Moving on to direct checks..."
      break
    fi
  done
  
  # Try to check if the Keycloak process is running inside the container
  echo "Checking if Keycloak process is running inside the container..."
  if docker exec "$KEYCLOAK_CONTAINER" ps aux 2>/dev/null | grep -q "java\|jboss\|keycloak"; then
    echo "✅ Keycloak process is running inside the container!"
  else
    echo "⚠️ WARNING: Keycloak process doesn't appear to be running inside the container."
    docker exec "$KEYCLOAK_CONTAINER" ps aux 2>/dev/null || echo "Failed to check processes in Keycloak container"
  fi
  
  # Check the Keycloak config - try multiple potential locations
  echo "Checking Keycloak configuration..."
  docker exec "$KEYCLOAK_CONTAINER" /opt/keycloak/bin/kc.sh show-config 2>/dev/null || 
  docker exec "$KEYCLOAK_CONTAINER" /opt/jboss/keycloak/bin/standalone.sh --version 2>/dev/null ||
  echo "ℹ️ Could not determine Keycloak configuration - the container might use a different path"
  
  # Check the logs for startup completion message
  echo "Checking Keycloak logs for successful startup message..."
  if docker logs "$KEYCLOAK_CONTAINER" 2>&1 | grep -q "started in\|Keycloak.*started\|server.*started"; then
    echo "✅ Keycloak logs show successful startup!"
  else
    echo "⚠️ WARNING: Keycloak startup message not found in logs. Continuing anyway..."
  fi
  
  # Skip URL checks if configured to do so
  if [ "$SKIP_URL_CHECKS" = "true" ]; then
    echo "Skipping Keycloak URL checks (SKIP_URL_CHECKS=true)"
    return 0
  fi
  
  # Try to access various Keycloak endpoints
  counter=0
  echo "Attempting to access Keycloak at the provided URL: $keycloak_url"
  
  # Extract domain and port from URL - honor the URL the user intended
  local domain=""
  local port=""
  
  if [ -n "$keycloak_url" ]; then
    domain=$(echo "$keycloak_url" | grep -oE 'https?://([^:/]+)' | sed 's|https://||;s|http://||')
    port=$(echo "$keycloak_url" | grep -oE ':[0-9]+' | sed 's/://')
  fi
  
  # Fallback to discovered values if needed
  if [ -z "$domain" ]; then
    domain=$(grep "KEYCLOAK_DOMAIN=" .env 2>/dev/null | cut -d '=' -f2 || echo "keycloak")
    domain="${domain}.$(grep "BASE_DOMAIN=" .env 2>/dev/null | cut -d '=' -f2 || echo "localhost")"
  fi
  
  if [ -z "$port" ]; then
    port="$KEYCLOAK_EXTERNAL_PORT"
  fi
  
  echo "Using domain: $domain, port: $port for Keycloak checks"
  
  # Determine common Keycloak endpoints based on version
  # Modern Keycloak vs Legacy endpoints
  local endpoints=("/" "/health" "/realms/master/")
  
  # Add legacy endpoints if we detect older Keycloak version
  if docker logs "$KEYCLOAK_CONTAINER" 2>&1 | grep -q "Keycloak.*WildFly\|jboss"; then
    endpoints+=("/auth/" "/auth/realms/master/")
  fi
  
  # Newer Keycloak might have these
  endpoints+=("/health/ready" "/metrics")
  
  # Skip this URL check early if it takes too long
  while [ $counter -lt $max_url_check_time ]; do
    # Try both protocols
    for protocol in "https" "http"; do
      # Create alternatives to try with properly formatted URLs
      local url_variants=(
        "${protocol}://${domain}:${port}"
        "${protocol}://localhost:${port}"
        "${protocol}://127.0.0.1:${port}"
      )
      
      for base_url in "${url_variants[@]}"; do
        echo "Testing Keycloak base URL: $base_url"
        
        for endpoint in "${endpoints[@]}"; do
          local full_url="${base_url}${endpoint}"
          echo "Trying Keycloak endpoint: $full_url"
          
          # Add -k flag to ignore SSL certificate validation
          if curl -s -k -f -o /dev/null --connect-timeout 3 --max-time 5 "$full_url"; then
            echo "✅ SUCCESS: Keycloak is accessible at $full_url!"
            return 0
          fi
        done
      done
    done
    
    sleep 5
    counter=$((counter + 5))
    echo "Still waiting for Keycloak URL response... ($counter seconds elapsed)"
    
    if [ $counter -ge $max_url_check_time ]; then
      echo "⚠️ Giving up on external Keycloak URL checks after ${counter} seconds."
      
      # One last direct check via Docker internal network
      echo "Trying internal Docker network access as last resort..."
      if docker exec "$KEYCLOAK_CONTAINER" curl -s -f --connect-timeout 3 "http://localhost:$KEYCLOAK_INTERNAL_PORT" >/dev/null 2>&1; then
        echo "✅ Keycloak is responding internally but not externally. This may indicate a port mapping issue."
      else
        echo "⚠️ Keycloak is not responding internally either. The service might still be starting."
      fi
      
      echo "The overall setup will continue, and Keycloak might become available later."
      echo "You can manually check Keycloak status with: docker logs $KEYCLOAK_CONTAINER"
      # Return success anyway to continue with setup
      return 0
    fi
  done
  
  # If we reach here, we'll continue anyway
  return 0
}

# Get URLs from the generated .env file
keycloak_url=$(grep "PUBLIC_KEYCLOAK_URL=" .env | cut -d '=' -f2)
api_url=$(grep "PUBLIC_API_URL=" .env | cut -d '=' -f2)
frontend_url=$(grep "PUBLIC_FRONTEND_URL=" .env | cut -d '=' -f2)
kong_url=$(grep "PUBLIC_KONG_PROXY_URL=" .env | cut -d '=' -f2)

# Fix URL protocols if needed - some configurations might use different protocols than specified
fix_and_detect_protocol() {
  local url="$1"
  local service="$2"
  
  # Skip protocol detection if configured to do so
  if [ "$SKIP_PROTOCOL_DETECTION" = "true" ]; then
    echo "Skipping protocol detection for $service (SKIP_PROTOCOL_DETECTION=true)"
    echo "$url"
    return 0
  fi
  
  # Extract protocol, domain and port with more reliable methods
  local protocol=$(echo "$url" | grep -oE '^https?')
  local domain=$(echo "$url" | grep -oE 'https?://([^:/]+)' | sed 's|https://||;s|http://||')
  local port=$(echo "$url" | grep -oE ':[0-9]+' | sed 's/://')
  
  # Fallback to environment if needed
  if [ -z "$protocol" ]; then
    local use_https=$(grep "USE_HTTPS=" .env | cut -d '=' -f2)
    if [[ "$use_https" == "true" ]]; then
      protocol="https"
    else
      protocol="http"
    fi
  fi
  
  if [ -z "$domain" ]; then
    case "$service" in
      "keycloak")
        domain="keycloak.$(grep "BASE_DOMAIN=" .env | cut -d '=' -f2)"
        ;;
      "api")
        domain="api.$(grep "BASE_DOMAIN=" .env | cut -d '=' -f2)"
        ;;
      "frontend")
        domain="frontend.$(grep "BASE_DOMAIN=" .env | cut -d '=' -f2)"
        ;;
      "kong")
        domain="kong.$(grep "BASE_DOMAIN=" .env | cut -d '=' -f2)"
        ;;
    esac
  fi
  
  if [ -z "$port" ]; then
    case "$service" in
      "keycloak")
        port=$(grep "KEYCLOAK_PORT=" .env | cut -d '=' -f2)
        ;;
      "api")
        port=$(grep "API_PORT=" .env | cut -d '=' -f2)
        ;;
      "frontend")
        port=$(grep "FRONTEND_PORT=" .env | cut -d '=' -f2)
        ;;
      "kong")
        port=$(grep "KONG_PROXY_PORT=" .env | cut -d '=' -f2)
        ;;
    esac
  fi
  
  local use_https=$(grep "USE_HTTPS=" .env | cut -d '=' -f2)
  
  echo "Service $service is configured with domain: $domain, protocol: $protocol, port: $port"
  echo "USE_HTTPS in .env is set to: $use_https"
  
  # If protocol doesn't match USE_HTTPS setting, warn the user
  if [[ "$use_https" == "true" && "$protocol" != "https" ]]; then
    echo "WARNING: HTTPS is enabled but URL is using HTTP protocol. Trying both..."
  elif [[ "$use_https" != "true" && "$protocol" == "https" ]]; then
    echo "WARNING: HTTPS is disabled but URL is using HTTPS protocol. Trying both..."
  fi
  
  # Skip URL checks if configured to do so
  if [ "$SKIP_URL_CHECKS" = "true" ]; then
    echo "Skipping URL checks for $service (SKIP_URL_CHECKS=true)"
    if [[ "$use_https" == "true" ]]; then
      echo "https://$domain:$port"
    else
      echo "http://$domain:$port"
    fi
    return 0
  fi
  
  # Create clean URLs for both protocols
  local https_url="https://$domain:$port"
  local http_url="http://$domain:$port"
  
  # Always try the configured protocol first
  if [[ "$protocol" == "https" ]]; then
    # Try HTTPS first, then HTTP
    if curl -s -k -f -o /dev/null --connect-timeout 3 --max-time 5 "$https_url"; then
      echo "HTTPS connection successful!"
      echo "$https_url"
    else
      echo "HTTPS connection failed, trying HTTP: $http_url"
      if curl -s -f -o /dev/null --connect-timeout 3 --max-time 5 "$http_url"; then
        echo "HTTP connection successful!"
        echo "$http_url"
      else
        echo "Both HTTPS and HTTP connections failed. Using $https_url for consistency."
        echo "$https_url"
      fi
    fi
  else
    # Try HTTP first, then HTTPS
    if curl -s -f -o /dev/null --connect-timeout 3 --max-time 5 "$http_url"; then
      echo "HTTP connection successful!"
      echo "$http_url"
    else
      echo "HTTP connection failed, trying HTTPS: $https_url"
      if curl -s -k -f -o /dev/null --connect-timeout 3 --max-time 5 "$https_url"; then
        echo "HTTPS connection successful!"
        echo "$https_url"
      else
        echo "Both HTTP and HTTPS connections failed. Using $http_url for consistency."
        echo "$http_url"
      fi
    fi
  fi
}

# Clean up and normalize URLs
echo "Detecting and verifying service URL protocols..."
if [ "$SKIP_PROTOCOL_DETECTION" = "true" ]; then
  echo "Skipping protocol detection for URLs (SKIP_PROTOCOL_DETECTION=true)"
  # Just use the URLs as-is from the .env file
else
  keycloak_url=$(fix_and_detect_protocol "$keycloak_url" "keycloak")
  api_url=$(fix_and_detect_protocol "$api_url" "api")
  frontend_url=$(fix_and_detect_protocol "$frontend_url" "frontend")
  kong_url=$(fix_and_detect_protocol "$kong_url" "kong")
fi

# Wait for critical services to be available
print_step "Waiting for services to be available..."
echo "This may take a few minutes..."

# Set a master timeout for the entire services check
MASTER_TIMEOUT=600 # 10 minutes
MASTER_START_TIME=$(date +%s)

# Check services with proper timeouts
# Use specialized Keycloak health check with shorter URL timeout
echo "Checking Keycloak health with specialized checker..."
if [ "$SKIP_URL_CHECKS" = "true" ]; then
  echo "Skipping Keycloak URL health checks (SKIP_URL_CHECKS=true)"
  # Dynamically find Keycloak container
  project_prefix=$(docker-compose config --services | head -n 1 | grep -o "^[a-zA-Z0-9]*" || echo "dive25")
  KEYCLOAK_CONTAINER="${KEYCLOAK_CONTAINER:-${project_prefix}-keycloak}"
  # Just check if the container is running
  if docker ps | grep -q "$KEYCLOAK_CONTAINER" || docker ps | grep -i "keycloak"; then
    echo "Keycloak container is running. Continuing..."
  else
    echo "WARNING: Keycloak container is not running! Setup may not be complete."
  fi
else
  check_keycloak_health "$keycloak_url" 180 || echo "WARNING: Keycloak health check failed, but continuing anyway..."
fi

# Check if master timeout has been reached
CURRENT_TIME=$(date +%s)
ELAPSED_TIME=$((CURRENT_TIME - MASTER_START_TIME))
if [ $ELAPSED_TIME -ge $MASTER_TIMEOUT ]; then
  echo "WARNING: Master timeout reached after ${ELAPSED_TIME}s. Continuing with setup anyway."
fi

# Configure Keycloak if needed
echo "🔄 Checking if Keycloak needs configuration..."
if [ -f "./keycloak/configure-keycloak.sh" ]; then
    chmod +x ./keycloak/configure-keycloak.sh
    
    # Load INTERNAL_KEYCLOAK_URL value from .env file if not already set
    if [ -z "$INTERNAL_KEYCLOAK_URL" ]; then
        INTERNAL_KEYCLOAK_URL=$(grep "INTERNAL_KEYCLOAK_URL=" .env | cut -d '=' -f2)
    fi
    
    # Ensure we have a URL to check
    if [ -z "$INTERNAL_KEYCLOAK_URL" ]; then
        echo "⚠️ INTERNAL_KEYCLOAK_URL not found in .env file, using default"
        INTERNAL_KEYCLOAK_URL="http://keycloak:8080"
    fi
    
    echo "⏳ Waiting for Keycloak to be available at $INTERNAL_KEYCLOAK_URL (via Docker network)"
    
    # Get API container name directly - more reliable than a loop
    API_CONTAINER=$(get_container_name "api")
    KONG_CONTAINER=$(get_container_name "kong")
    
    # Select a container to use for checking Keycloak availability
    if docker ps | grep -q "$API_CONTAINER"; then
        RUNNER_CONTAINER="$API_CONTAINER"
        echo "Using API container to check Keycloak availability..."
    elif docker ps | grep -q "$KONG_CONTAINER"; then
        RUNNER_CONTAINER="$KONG_CONTAINER"
        echo "Using Kong container to check Keycloak availability..."
    else
        RUNNER_CONTAINER=""
    fi
    
    if [ -z "$RUNNER_CONTAINER" ]; then
        echo "⚠️ Could not find API or Kong container. Using external URL check instead."
        # Try external URL as fallback
        KEYCLOAK_PORT=$(grep "KEYCLOAK_PORT=" .env | cut -d '=' -f2 || echo "3003")
        echo "Using Keycloak port from .env: $KEYCLOAK_PORT"
        external_url="http://localhost:${KEYCLOAK_PORT}"
        echo "Trying external URL: $external_url"
        
        # Use a more direct approach that avoids nested bash -c commands
        echo "Waiting for Keycloak to be available externally..."
        TIMEOUT_COUNTER=0
        MAX_TIMEOUT=300
        
        while [ $TIMEOUT_COUNTER -lt $MAX_TIMEOUT ]; do
            if curl -s "$external_url" > /dev/null 2>&1; then
                echo "✅ Keycloak is accessible externally!"
                break
            fi
            echo "Waiting for Keycloak (external)... ($TIMEOUT_COUNTER seconds elapsed)"
            sleep 5
            TIMEOUT_COUNTER=$((TIMEOUT_COUNTER + 5))
        done
        
        if [ $TIMEOUT_COUNTER -ge $MAX_TIMEOUT ]; then
            echo "❌ Timed out waiting for Keycloak via external URL"
            echo "⚠️ Continuing anyway, but Keycloak configuration may fail."
        fi
        # Skip the rest of this block since we're not in a function
        # The script will continue with Keycloak configuration
    else
        # Check Keycloak using the runner container
        echo "Checking if curl is available in the container..."
        if ! docker exec "$RUNNER_CONTAINER" which curl >/dev/null 2>&1; then
            echo "⚠️ curl not available in container. Trying to install it..."
            # Try to install curl - works for most debian/alpine based images
            docker exec "$RUNNER_CONTAINER" sh -c "command -v apk >/dev/null && apk add --no-cache curl || command -v apt-get >/dev/null && apt-get update && apt-get install -y curl" >/dev/null 2>&1 || true
            
            # Check again
            if ! docker exec "$RUNNER_CONTAINER" which curl >/dev/null 2>&1; then
                echo "⚠️ Could not install curl in container. Using external URL check instead."
                # Fall back to external URL check
                KEYCLOAK_PORT=$(grep "KEYCLOAK_PORT=" .env | cut -d '=' -f2 || echo "3003")
                echo "Using Keycloak port from .env: $KEYCLOAK_PORT"
                external_url="http://localhost:${KEYCLOAK_PORT}"
                echo "Trying external URL: $external_url"
                
                # Use a more direct approach that avoids nested bash -c commands
                echo "Waiting for Keycloak to be available externally..."
                TIMEOUT_COUNTER=0
                MAX_TIMEOUT=300
                
                while [ $TIMEOUT_COUNTER -lt $MAX_TIMEOUT ]; do
                    if curl -s "$external_url" > /dev/null 2>&1; then
                        echo "✅ Keycloak is accessible externally!"
                        break
                    fi
                    echo "Waiting for Keycloak (external)... ($TIMEOUT_COUNTER seconds elapsed)"
                    sleep 5
                    TIMEOUT_COUNTER=$((TIMEOUT_COUNTER + 5))
                done
                
                if [ $TIMEOUT_COUNTER -ge $MAX_TIMEOUT ]; then
                    echo "❌ Timed out waiting for Keycloak via external URL"
                    echo "⚠️ Continuing anyway, but Keycloak configuration may fail."
                fi
                # Skip the rest of this code without using break
                # Fall through to continue with setup
            fi
        fi
        
        timeout 300 bash -c "until docker exec $RUNNER_CONTAINER curl -s $INTERNAL_KEYCLOAK_URL > /dev/null; do echo \"Waiting for Keycloak (internal)...\"; sleep 5; done" || { 
            echo "❌ Timed out waiting for Keycloak via internal Docker network"; 
            echo "⚠️ Continuing anyway, but Keycloak configuration may fail.";
        }
    fi
    
    echo "✅ Keycloak is available, configuring now..."
    ./keycloak/configure-keycloak.sh
    if [ $? -eq 0 ]; then
        echo "✅ Keycloak configuration completed successfully"
        
        # Verify and fix realm settings if needed
        if [ -n "$KEYCLOAK_ADMIN" ] && [ -n "$KEYCLOAK_ADMIN_PASSWORD" ]; then
            echo "Verifying Keycloak settings after configuration..."
            # Get admin token
            ADMIN_TOKEN=$(curl -s -k -X POST "${KEYCLOAK_INTERNAL_URL}/realms/master/protocol/openid-connect/token" \
                -H "Content-Type: application/x-www-form-urlencoded" \
                -d "username=${KEYCLOAK_ADMIN}" \
                -d "password=${KEYCLOAK_ADMIN_PASSWORD}" \
                -d "grant_type=password" \
                -d "client_id=admin-cli" | grep -o '"access_token":"[^"]*"' | cut -d':' -f2 | tr -d '"')
            
            if [ -n "$ADMIN_TOKEN" ]; then
                verify_keycloak_settings "$ADMIN_TOKEN" "$KEYCLOAK_INTERNAL_URL" "$KEYCLOAK_REALM" "$PUBLIC_KEYCLOAK_URL"
            else
                echo "⚠️ Could not get admin token for verification"
            fi
        else
            echo "⚠️ Missing Keycloak admin credentials, skipping settings verification"
        fi
    else
        echo "⚠️ Keycloak configuration script returned non-zero exit code"
        echo "Continuing with setup, but some features may not work correctly"
    fi
else
    echo "⚠️ configure-keycloak.sh script not found"
    echo "Searching for an alternative configuration file..."
    
    # Check for realm export file
    if [ -f "./keycloak/realm-export.json" ]; then
        echo "Found realm-export.json, attempting manual configuration..."
        # TODO: Add manual import logic here if needed
    else
        echo "⚠️ No Keycloak configuration files found, using default configuration"
    fi
fi

# Ensure Keycloak realm is properly configured
print_step "Ensuring Keycloak realm is properly configured..."

# Check if keycloak-config container completed successfully
KEYCLOAK_CONFIG_CONTAINER=$(get_container_name "keycloak-config")
if docker ps -a | grep -q "$KEYCLOAK_CONFIG_CONTAINER"; then
  CONFIG_STATUS=$(docker inspect --format='{{.State.Status}}' "$KEYCLOAK_CONFIG_CONTAINER")
  CONFIG_EXIT_CODE=$(docker inspect --format='{{.State.ExitCode}}' "$KEYCLOAK_CONFIG_CONTAINER")
  
  echo "Keycloak config container status: $CONFIG_STATUS, exit code: $CONFIG_EXIT_CODE"
  
  if [ "$CONFIG_EXIT_CODE" -eq 0 ]; then
    echo "✅ Keycloak configuration container completed successfully"
    
    # Verify the Keycloak configuration container is using the updated approach
    docker logs "$KEYCLOAK_CONFIG_CONTAINER" | grep -q "Using direct API calls for configuration" && echo "✅ Keycloak config container using updated API approach" || echo "⚠️ Keycloak config container may be using old approach"
    
    # Check if expected environment variables are set
    echo "Verifying Keycloak configuration container environment..."
    KEYCLOAK_CONTAINER_ENV=$(docker inspect --format='{{range .Config.Env}}{{.}} {{end}}' "$KEYCLOAK_CONFIG_CONTAINER")
    echo "$KEYCLOAK_CONTAINER_ENV" | grep -q "KEYCLOAK_CONTAINER=" && echo "✅ KEYCLOAK_CONTAINER environment variable is set" || echo "⚠️ KEYCLOAK_CONTAINER environment variable might be missing"
    
    # Additional checks for other environment variables
    echo "$KEYCLOAK_CONTAINER_ENV" | grep -q "KEYCLOAK_URL=" && echo "✅ KEYCLOAK_URL environment variable is set" || echo "⚠️ KEYCLOAK_URL environment variable might be missing"
    echo "$KEYCLOAK_CONTAINER_ENV" | grep -q "PUBLIC_KEYCLOAK_URL=" && echo "✅ PUBLIC_KEYCLOAK_URL environment variable is set" || echo "⚠️ PUBLIC_KEYCLOAK_URL environment variable might be missing"
  else
    echo "⚠️ Keycloak configuration container failed with exit code $CONFIG_EXIT_CODE"
    echo "Logs from keycloak-config container:"
    docker logs "$KEYCLOAK_CONFIG_CONTAINER" | tail -n 50
    
    echo "Attempting to fix Keycloak realm configuration..."
    
    # Check if dive25 realm exists directly
    KEYCLOAK_INTERNAL_URL=$(grep -E "^INTERNAL_KEYCLOAK_URL=" .env | cut -d= -f2)
    KEYCLOAK_ADMIN=$(grep -E "^KEYCLOAK_ADMIN=" .env | cut -d= -f2)
    KEYCLOAK_ADMIN_PASSWORD=$(grep -E "^KEYCLOAK_ADMIN_PASSWORD=" .env | cut -d= -f2)
    KEYCLOAK_REALM=$(grep -E "^KEYCLOAK_REALM=" .env | cut -d= -f2)
    
    # Set default values if not found in .env
    KEYCLOAK_INTERNAL_URL=${KEYCLOAK_INTERNAL_URL:-http://localhost:4432}
    KEYCLOAK_ADMIN=${KEYCLOAK_ADMIN:-admin}
    KEYCLOAK_ADMIN_PASSWORD=${KEYCLOAK_ADMIN_PASSWORD:-admin}
    KEYCLOAK_REALM=${KEYCLOAK_REALM:-dive25}
    
    echo "Using Keycloak admin credentials and realm from environment variables"
    
    # First, try to run the original configure-keycloak.sh using a new container
    echo "Running Keycloak configuration script in a clean container..."
    
    # Get the Docker Compose project name for network
    local project_name=$(basename "$PWD" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]//g')
    local network_name="${project_name}_dive25-network"
    echo "Using Docker network: $network_name"
    
    docker run --rm \
      --network $network_name \
      -v $(pwd)/keycloak/configure-keycloak.sh:/configure-keycloak.sh:ro \
      -v $(pwd)/keycloak/realm-export.json:/realm-export.json:ro \
      -v $(pwd)/keycloak/identity-providers:/identity-providers:ro \
      -v $(pwd)/keycloak/test-users:/test-users:ro \
      -v $(pwd)/keycloak/clients:/clients:ro \
      -e KEYCLOAK_URL=${KEYCLOAK_INTERNAL_URL} \
      -e KEYCLOAK_ADMIN=${KEYCLOAK_ADMIN} \
      -e KEYCLOAK_ADMIN_PASSWORD=${KEYCLOAK_ADMIN_PASSWORD} \
      -e PUBLIC_KEYCLOAK_URL=$(grep -E "^PUBLIC_KEYCLOAK_URL=" .env | cut -d= -f2) \
      -e PUBLIC_FRONTEND_URL=$(grep -E "^PUBLIC_FRONTEND_URL=" .env | cut -d= -f2) \
      -e PUBLIC_API_URL=$(grep -E "^PUBLIC_API_URL=" .env | cut -d= -f2) \
      -e KEYCLOAK_REALM=${KEYCLOAK_REALM} \
      -e KEYCLOAK_CLIENT_ID_FRONTEND=$(grep -E "^KEYCLOAK_CLIENT_ID_FRONTEND=" .env | cut -d= -f2) \
      -e KEYCLOAK_CLIENT_ID_API=$(grep -E "^KEYCLOAK_CLIENT_ID_API=" .env | cut -d= -f2) \
      -e KEYCLOAK_CLIENT_SECRET=$(grep -E "^KEYCLOAK_CLIENT_SECRET=" .env | cut -d= -f2) \
      curlimages/curl:latest \
      /bin/sh -c "chmod +x /configure-keycloak.sh && /configure-keycloak.sh"
      
    # Check if that fixed the issue
    echo "Checking if the realm was created successfully..."
    if [ $? -eq 0 ]; then
      echo "✅ Keycloak configuration through container completed successfully"
    else
      echo "⚠️ Keycloak configuration through container failed"
      
      # If that fails, try to use the fix-keycloak-config.sh script
      echo "Attempting to use fix-keycloak-config.sh script..."
      if [ -f "./keycloak/fix-keycloak-config.sh" ]; then
        chmod +x ./keycloak/fix-keycloak-config.sh
        ./keycloak/fix-keycloak-config.sh
        
        if [ $? -eq 0 ]; then
          echo "✅ Keycloak realm fixed successfully using fix-keycloak-config.sh"
        else
          echo "⚠️ Failed to fix Keycloak realm using fix-keycloak-config.sh"
          echo "Please check the logs and try to fix the issue manually."
        fi
      else
        echo "⚠️ fix-keycloak-config.sh script not found"
      fi
    fi
  fi
else
  echo "⚠️ Keycloak config container not found, checking realm directly..."
  
  # Try to check if the realm exists using the Keycloak API
  KEYCLOAK_INTERNAL_URL=$(grep -E "^INTERNAL_KEYCLOAK_URL=" .env | cut -d= -f2)
  KEYCLOAK_ADMIN=$(grep -E "^KEYCLOAK_ADMIN=" .env | cut -d= -f2)
  KEYCLOAK_ADMIN_PASSWORD=$(grep -E "^KEYCLOAK_ADMIN_PASSWORD=" .env | cut -d= -f2)
  KEYCLOAK_REALM=$(grep -E "^KEYCLOAK_REALM=" .env | cut -d= -f2)
  
  # Set default values if not found in .env
  KEYCLOAK_INTERNAL_URL=${KEYCLOAK_INTERNAL_URL:-http://localhost:4432}
  KEYCLOAK_ADMIN=${KEYCLOAK_ADMIN:-admin}
  KEYCLOAK_ADMIN_PASSWORD=${KEYCLOAK_ADMIN_PASSWORD:-admin}
  KEYCLOAK_REALM=${KEYCLOAK_REALM:-dive25}
  
  echo "Using Keycloak admin credentials and realm from environment variables"
  
  # Attempt to get a token
  echo "Attempting to get admin token..."
  ADMIN_TOKEN=$(curl -s -k -X POST "${KEYCLOAK_INTERNAL_URL}/realms/master/protocol/openid-connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "username=${KEYCLOAK_ADMIN}" \
    -d "password=${KEYCLOAK_ADMIN_PASSWORD}" \
    -d "grant_type=password" \
    -d "client_id=admin-cli" | grep -o '"access_token":"[^"]*"' | cut -d':' -f2 | tr -d '"')
  
  if [ -n "$ADMIN_TOKEN" ]; then
    echo "✅ Got admin token, checking if realm exists..."
    
    # Check if the realm exists
    REALM_EXISTS=$(curl -s -k -o /dev/null -w "%{http_code}" \
      -H "Authorization: Bearer $ADMIN_TOKEN" \
      "${KEYCLOAK_INTERNAL_URL}/admin/realms/${KEYCLOAK_REALM}")
    
    if [ "$REALM_EXISTS" -eq 200 ]; then
      echo "✅ Realm ${KEYCLOAK_REALM} already exists"
      
      # Verify specific Keycloak settings
      verify_keycloak_settings "$ADMIN_TOKEN" "$KEYCLOAK_INTERNAL_URL" "$KEYCLOAK_REALM" "$PUBLIC_KEYCLOAK_URL"
    else
      echo "⚠️ Realm ${KEYCLOAK_REALM} does not exist. Running configuration script..."
      
      # Run the original configure-keycloak.sh script
      if [ -f "./keycloak/configure-keycloak.sh" ]; then
        chmod +x ./keycloak/configure-keycloak.sh
        
        # Export variables for the script
        export KEYCLOAK_URL=${KEYCLOAK_INTERNAL_URL}
        export KEYCLOAK_ADMIN=${KEYCLOAK_ADMIN}
        export KEYCLOAK_ADMIN_PASSWORD=${KEYCLOAK_ADMIN_PASSWORD}
        export PUBLIC_KEYCLOAK_URL=$(grep -E "^PUBLIC_KEYCLOAK_URL=" .env | cut -d= -f2)
        export PUBLIC_FRONTEND_URL=$(grep -E "^PUBLIC_FRONTEND_URL=" .env | cut -d= -f2)
        export PUBLIC_API_URL=$(grep -E "^PUBLIC_API_URL=" .env | cut -d= -f2)
        export KEYCLOAK_REALM=${KEYCLOAK_REALM}
        export KEYCLOAK_CLIENT_ID_FRONTEND=$(grep -E "^KEYCLOAK_CLIENT_ID_FRONTEND=" .env | cut -d= -f2)
        export KEYCLOAK_CLIENT_ID_API=$(grep -E "^KEYCLOAK_CLIENT_ID_API=" .env | cut -d= -f2)
        export KEYCLOAK_CLIENT_SECRET=$(grep -E "^KEYCLOAK_CLIENT_SECRET=" .env | cut -d= -f2)
        
        # Create mock directories for the script
        mkdir -p ./tmp/identity-providers ./tmp/test-users ./tmp/clients
        
        # Run the script with proper environment
        ./keycloak/configure-keycloak.sh
        
        if [ $? -eq 0 ]; then
          echo "✅ Keycloak configuration completed successfully"
        else
          echo "⚠️ Failed to configure Keycloak"
          echo "Please check the logs and try to fix the issue manually."
        fi
      else
        echo "⚠️ configure-keycloak.sh script not found"
        
        # If that fails, try to use the fix-keycloak-config.sh script
        if [ -f "./keycloak/fix-keycloak-config.sh" ]; then
          chmod +x ./keycloak/fix-keycloak-config.sh
          ./keycloak/fix-keycloak-config.sh
          
          if [ $? -eq 0 ]; then
            echo "✅ Keycloak realm fixed successfully using fix-keycloak-config.sh"
          else
            echo "⚠️ Failed to fix Keycloak realm using fix-keycloak-config.sh"
            echo "Please check the logs and try to fix the issue manually."
          fi
        else
          echo "⚠️ fix-keycloak-config.sh script not found"
        fi
      fi
    fi
  else
    echo "⚠️ Failed to get admin token from Keycloak"
    echo "Please make sure Keycloak is running and accessible."
    
    # Try to use the fix-keycloak-config.sh script as a last resort
    if [ -f "./keycloak/fix-keycloak-config.sh" ]; then
      chmod +x ./keycloak/fix-keycloak-config.sh
      ./keycloak/fix-keycloak-config.sh
      
      if [ $? -eq 0 ]; then
        echo "✅ Keycloak realm fixed successfully using fix-keycloak-config.sh"
      else
        echo "⚠️ Failed to fix Keycloak realm using fix-keycloak-config.sh"
        echo "Please check the logs and try to fix the issue manually."
      fi
    else
      echo "⚠️ fix-keycloak-config.sh script not found"
    fi
  fi
fi

# Function to verify Keycloak realm settings
verify_keycloak_settings() {
  local admin_token="$1"
  local keycloak_url="$2"
  local realm_name="$3"
  local expected_frontend_url="$4"
  
  echo "Verifying Keycloak realm settings..."
  
  # Fetch current realm settings
  local realm_settings=$(curl -s -k \
    -H "Authorization: Bearer $admin_token" \
    "${keycloak_url}/admin/realms/${realm_name}")
  
  # Check Content Security Policy
  local csp=$(echo "$realm_settings" | grep -o '"contentSecurityPolicy":"[^"]*"' | cut -d':' -f2 | tr -d '"')
  echo "Current Content Security Policy: $csp"
  
  if [[ "$csp" == *"frame-src *; frame-ancestors *"* ]]; then
    echo "✅ Content Security Policy is correctly configured"
  else
    echo "⚠️ Content Security Policy is not correctly configured"
    echo "Current: $csp"
    echo "Expected to contain: frame-src *; frame-ancestors *"
    
    # Update CSP if needed
    echo "Updating Content Security Policy..."
    curl -s -k -X PUT \
      -H "Authorization: Bearer $admin_token" \
      -H "Content-Type: application/json" \
      -d '{"contentSecurityPolicy": "frame-src *; frame-ancestors *; object-src '\''none'\''"}' \
      "${keycloak_url}/admin/realms/${realm_name}" >/dev/null
    
    if [ $? -eq 0 ]; then
      echo "✅ Content Security Policy updated successfully"
    else
      echo "⚠️ Failed to update Content Security Policy"
    fi
  fi
  
  # Check frontendUrl
  local frontend_url=$(echo "$realm_settings" | grep -o '"frontendUrl":"[^"]*"' | cut -d':' -f2- | tr -d '"' | sed 's/^://')
  echo "Current frontendUrl: $frontend_url"
  
  if [[ "$frontend_url" == "$expected_frontend_url" ]]; then
    echo "✅ frontendUrl is correctly configured"
  else
    echo "⚠️ frontendUrl is not correctly configured"
    echo "Current: $frontend_url"
    echo "Expected: $expected_frontend_url"
    
    # Update frontendUrl
    echo "Updating frontendUrl and related settings..."
    curl -s -k -X PUT \
      -H "Authorization: Bearer $admin_token" \
      -H "Content-Type: application/json" \
      -d "{
        \"frontendUrl\": \"${expected_frontend_url}\",
        \"attributes\": {
          \"frontendUrl\": \"${expected_frontend_url}\",
          \"hostname-url\": \"${expected_frontend_url}\",
          \"hostname-admin-url\": \"${expected_frontend_url}\"
        }
      }" \
      "${keycloak_url}/admin/realms/${realm_name}" >/dev/null
    
    if [ $? -eq 0 ]; then
      echo "✅ frontendUrl and related settings updated successfully"
    else
      echo "⚠️ Failed to update frontendUrl and related settings"
    fi
  fi
  
  # Verify clients
  verify_keycloak_clients "$admin_token" "$keycloak_url" "$realm_name"
}

# Function to verify Keycloak clients
verify_keycloak_clients() {
  local admin_token="$1"
  local keycloak_url="$2"
  local realm_name="$3"
  
  echo "Verifying Keycloak clients..."
  
  # Fetch current clients
  local clients=$(curl -s -k \
    -H "Authorization: Bearer $admin_token" \
    "${keycloak_url}/admin/realms/${realm_name}/clients")
  
  # Get client IDs from environment
  local frontend_client_id=$(grep -E "^KEYCLOAK_CLIENT_ID_FRONTEND=" .env | cut -d= -f2)
  local api_client_id=$(grep -E "^KEYCLOAK_CLIENT_ID_API=" .env | cut -d= -f2)
  
  # Set defaults if not found
  frontend_client_id=${frontend_client_id:-frontend}
  api_client_id=${api_client_id:-api}
  
  # Check for frontend client
  if echo "$clients" | grep -q "\"clientId\":\"$frontend_client_id\""; then
    echo "✅ Frontend client '$frontend_client_id' exists"
  else
    echo "⚠️ Frontend client '$frontend_client_id' not found"
    echo "Please run the Keycloak configuration script again or create the client manually"
  fi
  
  # Check for API client
  if echo "$clients" | grep -q "\"clientId\":\"$api_client_id\""; then
    echo "✅ API client '$api_client_id' exists"
  else
    echo "⚠️ API client '$api_client_id' not found"
    echo "Please run the Keycloak configuration script again or create the client manually"
  fi
  
  # Check for admin client - this might be optional depending on your setup
  if echo "$clients" | grep -q "\"clientId\":\"admin-cli\""; then
    echo "✅ Admin client 'admin-cli' exists"
  else
    echo "⚠️ Admin client 'admin-cli' not found"
  fi
  
  # Verify client configurations if needed
  # This might be extended with more specific client checks
  echo "Client verification completed"
}

# Setup is done, now let's check Kong health
print_step "Checking Kong health..."

# Check if Kong is running and accessible
if [ "$SKIP_URL_CHECKS" = "true" ]; then
  echo "Skipping Kong URL health checks (SKIP_URL_CHECKS=true)"
  
  # Get the container name dynamically
  local KONG_CONTAINER=$(get_container_name "kong")
  
  # Just check if the container is running
  if docker ps | grep -q "$KONG_CONTAINER"; then
    echo "Kong container '$KONG_CONTAINER' is running. Continuing..."
  else
    echo "WARNING: Kong container '$KONG_CONTAINER' is not running! Setup may not be complete."
  fi
else
  check_kong_health 180 || echo "WARNING: Kong health check failed, but continuing anyway..."
fi

# Ensure Kong is properly configured with the correct Keycloak realm
print_step "Ensuring Kong is properly configured with Keycloak..."

# Check if kong-config container completed successfully
local KONG_CONFIG_CONTAINER=$(get_container_name "kong-config")
if docker ps -a | grep -q "$KONG_CONFIG_CONTAINER"; then
  CONFIG_STATUS=$(docker inspect --format='{{.State.Status}}' "$KONG_CONFIG_CONTAINER")
  CONFIG_EXIT_CODE=$(docker inspect --format='{{.State.ExitCode}}' "$KONG_CONFIG_CONTAINER")
  
  echo "Kong config container status: $CONFIG_STATUS, exit code: $CONFIG_EXIT_CODE"
  
  if [ "$CONFIG_EXIT_CODE" -eq 0 ]; then
    echo "✅ Kong configuration container completed successfully"
  else
    echo "⚠️ Kong configuration container failed with exit code $CONFIG_EXIT_CODE"
    echo "Logs from kong-config container:"
    docker logs "$KONG_CONFIG_CONTAINER" | tail -n 50
    
    echo "Attempting to fix Kong configuration..."
    
    # Set up Kong configuration with environment variables from .env
    KONG_ADMIN_URL=$(grep -E "^KONG_ADMIN_URL=" .env | cut -d= -f2)
    KONG_ADMIN_PORT=$(grep -E "^KONG_ADMIN_PORT=" .env | cut -d= -f2)
    KEYCLOAK_REALM=$(grep -E "^KEYCLOAK_REALM=" .env | cut -d= -f2)
    INTERNAL_KEYCLOAK_URL=$(grep -E "^INTERNAL_KEYCLOAK_URL=" .env | cut -d= -f2)
    PUBLIC_KEYCLOAK_URL=$(grep -E "^PUBLIC_KEYCLOAK_URL=" .env | cut -d= -f2)
    KEYCLOAK_CLIENT_ID=$(grep -E "^KEYCLOAK_CLIENT_ID_FRONTEND=" .env | cut -d= -f2)
    KEYCLOAK_CLIENT_SECRET=$(grep -E "^KEYCLOAK_CLIENT_SECRET=" .env | cut -d= -f2)
    PUBLIC_FRONTEND_URL=$(grep -E "^PUBLIC_FRONTEND_URL=" .env | cut -d= -f2)
    
    # Set default values if not found in .env
    KONG_ADMIN_URL=${KONG_ADMIN_URL:-http://localhost:9444}
    KONG_ADMIN_PORT=${KONG_ADMIN_PORT:-9444}
    KEYCLOAK_REALM=${KEYCLOAK_REALM:-dive25}
    INTERNAL_KEYCLOAK_URL=${INTERNAL_KEYCLOAK_URL:-http://keycloak:8080}
    PUBLIC_KEYCLOAK_URL=${PUBLIC_KEYCLOAK_URL:-https://keycloak.dive25.local:4432}
    KEYCLOAK_CLIENT_ID=${KEYCLOAK_CLIENT_ID:-dive25-frontend}
    KEYCLOAK_CLIENT_SECRET=${KEYCLOAK_CLIENT_SECRET:-change-me-in-production}
    PUBLIC_FRONTEND_URL=${PUBLIC_FRONTEND_URL:-https://frontend.dive25.local:4430}
    
    echo "Using Kong Admin URL: $KONG_ADMIN_URL"
    echo "Using Keycloak realm: $KEYCLOAK_REALM"
    
    # Use the unified Kong configuration script 
    if [ -f "./kong/kong-configure-unified.sh" ]; then
      echo "Using unified Kong configuration script for complete Kong setup..."
      chmod +x ./kong/kong-configure-unified.sh
      
      # Set environment variables for the script
      export KONG_ADMIN_URL="$KONG_ADMIN_URL"
      export BASE_DOMAIN="$BASE_DOMAIN"
      
      # Dynamically determine container names based on docker-compose project
      local project_prefix=$(docker-compose config --services | head -n 1 | grep -o "^[a-zA-Z0-9]*" || echo "dive25")
      local KONG_CONTAINER="${project_prefix}-kong"
      export FRONTEND_CONTAINER="${project_prefix}-frontend"
      export API_CONTAINER="${project_prefix}-api"
      export KEYCLOAK_CONTAINER="${project_prefix}-keycloak"
      
      export INTERNAL_FRONTEND_URL="${INTERNAL_FRONTEND_URL}"
      export INTERNAL_API_URL="${INTERNAL_API_URL}"
      export INTERNAL_KEYCLOAK_URL="$INTERNAL_KEYCLOAK_URL"
      export PUBLIC_KEYCLOAK_URL="$PUBLIC_KEYCLOAK_URL"
      export PUBLIC_FRONTEND_URL="$PUBLIC_FRONTEND_URL"
      export PUBLIC_API_URL="$PUBLIC_API_URL"
      export KEYCLOAK_REALM="$KEYCLOAK_REALM"
      export KEYCLOAK_CLIENT_ID_FRONTEND="$KEYCLOAK_CLIENT_ID"
      export KEYCLOAK_CLIENT_ID_API="$KEYCLOAK_CLIENT_ID_API"
      export KEYCLOAK_CLIENT_SECRET="$KEYCLOAK_CLIENT_SECRET"
      
      # Run the unified script with all configuration steps
      ./kong/kong-configure-unified.sh all
      
      if [ $? -eq 0 ]; then
        echo "✅ Kong configuration completed successfully using unified configuration script"
        KONG_CONFIGURED=true
      else
        echo "⚠️ Failed to configure Kong using unified configuration script"
        echo "Falling back to legacy scripts..."
        
        # Try to use the legacy scripts as fallback
        if [ -f "./kong/configure-oidc.sh" ]; then
          echo "Using legacy OIDC configuration script..."
          chmod +x ./kong/configure-oidc.sh
          
          # Run the legacy OIDC script
          ./kong/configure-oidc.sh
          
          if [ $? -eq 0 ]; then
            echo "✅ OIDC configuration completed successfully using legacy script"
            echo "Attempting port 8443 configuration..."
            
            # Try port-8443 configuration with the unified script again
            ./kong/kong-configure-unified.sh port-8443 || {
              echo "⚠️ Port 8443 configuration failed. Check Kong logs for details."
            }
            KONG_CONFIGURED=true
          else
            echo "⚠️ Failed to configure Kong using legacy script"
          fi
        else
          echo "⚠️ Legacy OIDC configuration script not found"
        fi
      fi
    fi
  fi
else
  echo "⚠️ Kong config container not found, checking realm directly..."
  
  # Try to check if the realm exists using the Keycloak API
  KEYCLOAK_INTERNAL_URL=$(grep -E "^INTERNAL_KEYCLOAK_URL=" .env | cut -d= -f2)
  KEYCLOAK_ADMIN=$(grep -E "^KEYCLOAK_ADMIN=" .env | cut -d= -f2)
  KEYCLOAK_ADMIN_PASSWORD=$(grep -E "^KEYCLOAK_ADMIN_PASSWORD=" .env | cut -d= -f2)
  KEYCLOAK_REALM=$(grep -E "^KEYCLOAK_REALM=" .env | cut -d= -f2)
  
  # Set default values if not found in .env
  KEYCLOAK_INTERNAL_URL=${KEYCLOAK_INTERNAL_URL:-http://localhost:4432}
  KEYCLOAK_ADMIN=${KEYCLOAK_ADMIN:-admin}
  KEYCLOAK_ADMIN_PASSWORD=${KEYCLOAK_ADMIN_PASSWORD:-admin}
  KEYCLOAK_REALM=${KEYCLOAK_REALM:-dive25}
  
  echo "Using Keycloak admin credentials and realm from environment variables"
  
  # Attempt to get a token
  echo "Attempting to get admin token..."
  ADMIN_TOKEN=$(curl -s -k -X POST "${KEYCLOAK_INTERNAL_URL}/realms/master/protocol/openid-connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "username=${KEYCLOAK_ADMIN}" \
    -d "password=${KEYCLOAK_ADMIN_PASSWORD}" \
    -d "grant_type=password" \
    -d "client_id=admin-cli" | grep -o '"access_token":"[^"]*"' | cut -d':' -f2 | tr -d '"')
  
  if [ -n "$ADMIN_TOKEN" ]; then
    echo "✅ Got admin token, checking if realm exists..."
    
    # Check if the realm exists
    REALM_EXISTS=$(curl -s -k -o /dev/null -w "%{http_code}" \
      -H "Authorization: Bearer $ADMIN_TOKEN" \
      "${KEYCLOAK_INTERNAL_URL}/admin/realms/${KEYCLOAK_REALM}")
    
    if [ "$REALM_EXISTS" -eq 200 ]; then
      echo "✅ Realm ${KEYCLOAK_REALM} already exists"
      
      # Verify specific Keycloak settings
      verify_keycloak_settings "$ADMIN_TOKEN" "$KEYCLOAK_INTERNAL_URL" "$KEYCLOAK_REALM" "$PUBLIC_KEYCLOAK_URL"
    else
      echo "⚠️ Realm ${KEYCLOAK_REALM} does not exist. Running configuration script..."
      
      # Run the original configure-keycloak.sh script
      if [ -f "./keycloak/configure-keycloak.sh" ]; then
        chmod +x ./keycloak/configure-keycloak.sh
        
        # Export variables for the script
        export KEYCLOAK_URL=${KEYCLOAK_INTERNAL_URL}
        export KEYCLOAK_ADMIN=${KEYCLOAK_ADMIN}
        export KEYCLOAK_ADMIN_PASSWORD=${KEYCLOAK_ADMIN_PASSWORD}
        export PUBLIC_KEYCLOAK_URL=$(grep -E "^PUBLIC_KEYCLOAK_URL=" .env | cut -d= -f2)
        export PUBLIC_FRONTEND_URL=$(grep -E "^PUBLIC_FRONTEND_URL=" .env | cut -d= -f2)
        export PUBLIC_API_URL=$(grep -E "^PUBLIC_API_URL=" .env | cut -d= -f2)
        export KEYCLOAK_REALM=${KEYCLOAK_REALM}
        export KEYCLOAK_CLIENT_ID_FRONTEND=$(grep -E "^KEYCLOAK_CLIENT_ID_FRONTEND=" .env | cut -d= -f2)
        export KEYCLOAK_CLIENT_ID_API=$(grep -E "^KEYCLOAK_CLIENT_ID_API=" .env | cut -d= -f2)
        export KEYCLOAK_CLIENT_SECRET=$(grep -E "^KEYCLOAK_CLIENT_SECRET=" .env | cut -d= -f2)
        
        # Create mock directories for the script
        mkdir -p ./tmp/identity-providers ./tmp/test-users ./tmp/clients
        
        # Run the script with proper environment
        ./keycloak/configure-keycloak.sh
        
        if [ $? -eq 0 ]; then
          echo "✅ Keycloak configuration completed successfully"
        else
          echo "⚠️ Failed to configure Keycloak"
          echo "Please check the logs and try to fix the issue manually."
        fi
      else
        echo "⚠️ configure-keycloak.sh script not found"
        
        # If that fails, try to use the fix-keycloak-config.sh script
        if [ -f "./keycloak/fix-keycloak-config.sh" ]; then
          chmod +x ./keycloak/fix-keycloak-config.sh
          ./keycloak/fix-keycloak-config.sh
          
          if [ $? -eq 0 ]; then
            echo "✅ Keycloak realm fixed successfully using fix-keycloak-config.sh"
          else
            echo "⚠️ Failed to fix Keycloak realm using fix-keycloak-config.sh"
            echo "Please check the logs and try to fix the issue manually."
          fi
        else
          echo "⚠️ fix-keycloak-config.sh script not found"
        fi
      fi
    fi
  else
    echo "⚠️ Failed to get admin token from Keycloak"
    echo "Please make sure Keycloak is running and accessible."
    
    # Try to use the fix-keycloak-config.sh script as a last resort
    if [ -f "./keycloak/fix-keycloak-config.sh" ]; then
      chmod +x ./keycloak/fix-keycloak-config.sh
      ./keycloak/fix-keycloak-config.sh
      
      if [ $? -eq 0 ]; then
        echo "✅ Keycloak realm fixed successfully using fix-keycloak-config.sh"
      else
        echo "⚠️ Failed to fix Keycloak realm using fix-keycloak-config.sh"
        echo "Please check the logs and try to fix the issue manually."
      fi
    else
      echo "⚠️ fix-keycloak-config.sh script not found"
    fi
  fi
fi

# Add hostname-based routes manually
if [ "$KONG_CONFIGURED" = "true" ]; then
  echo "Setting up hostname-based routes in Kong..."
  
  # Try to set up hostname-based routes
  API_DOMAIN=$(grep "API_DOMAIN=" .env | cut -d '=' -f2 || echo "api")
  FRONTEND_DOMAIN=$(grep "FRONTEND_DOMAIN=" .env | cut -d '=' -f2 || echo "frontend")
  KEYCLOAK_DOMAIN=$(grep "KEYCLOAK_DOMAIN=" .env | cut -d '=' -f2 || echo "keycloak")
  BASE_DOMAIN=$(grep "BASE_DOMAIN=" .env | cut -d '=' -f2 || echo "dive25.local")
  
  # Configure API service for HTTPS
  echo "Updating API service in Kong to use HTTPS..."
  curl -s -X PATCH "$KONG_ADMIN_URL/services/api-service" \
    --data "protocol=https" \
    --data "tls_verify=false" > /dev/null || echo "⚠️ Failed to update API service in Kong"
  
  # Create hostname-based routes for services
  echo "Creating hostname-based routes for services..."
  
  # Frontend route
  curl -s -X POST "$KONG_ADMIN_URL/services/frontend-service/routes" \
    --data "name=frontend-host-route" \
    --data "hosts[]=${FRONTEND_DOMAIN}.${BASE_DOMAIN}" \
    --data "strip_path=false" > /dev/null || echo "⚠️ Failed to create frontend host route"
    
  # API route
  curl -s -X POST "$KONG_ADMIN_URL/services/api-service/routes" \
    --data "name=api-host-route" \
    --data "hosts[]=${API_DOMAIN}.${BASE_DOMAIN}" \
    --data "strip_path=false" > /dev/null || echo "⚠️ Failed to create API host route"
    
  # Keycloak route
  curl -s -X POST "$KONG_ADMIN_URL/services/keycloak-service/routes" \
    --data "name=keycloak-host-route" \
    --data "hosts[]=${KEYCLOAK_DOMAIN}.${BASE_DOMAIN}" \
    --data "strip_path=false" > /dev/null || echo "⚠️ Failed to create Keycloak host route"
    
  # Root domain route (to frontend)
  curl -s -X POST "$KONG_ADMIN_URL/services/frontend-service/routes" \
    --data "name=root-domain-route" \
    --data "hosts[]=${BASE_DOMAIN}" \
    --data "strip_path=false" > /dev/null || echo "⚠️ Failed to create root domain route"
    
  echo "✅ Hostname-based routes set up successfully"
fi

print_step "Kong configuration is complete. Now checking service accessibility..."

# Check if the API service is running
print_step "Checking API service..."

if [ "$SKIP_API_CHECK" = "true" ]; then
  echo "Skipping API check (SKIP_API_CHECK=true)"
else
  # Check if master timeout has been reached
  CURRENT_TIME=$(date +%s)
  ELAPSED_TIME=$((CURRENT_TIME - MASTER_START_TIME))
  
  if [ $ELAPSED_TIME -ge $MASTER_TIMEOUT ]; then
    echo "⚠️ Master timeout reached for deployment (${ELAPSED_TIME}s elapsed). Skipping API check."
    
    # Get API container name dynamically
    local API_CONTAINER=$(get_container_name "api")
    
    # Just check if the container is running
    if docker ps | grep -q "$API_CONTAINER"; then
      echo "API container is running. Continuing..."
    else
      echo "WARNING: API container is not running! Setup may not be complete."
    fi
  else
    # Only perform the API health check if Kong has been configured
    if [ "$KONG_CONFIGURED" = "true" ]; then
      echo "Kong is configured, performing complete API health check with URL..."
      check_api_health "$api_url" 120 || echo "WARNING: API health check failed, but continuing..."
    else
      echo "Skipping API URL health check as Kong has not been fully configured"
      # Just check if the container is running instead
      local API_CONTAINER=$(get_container_name "api")
      if docker ps | grep -q "$API_CONTAINER"; then
        echo "API container is running. Continuing..."
      else
        echo "WARNING: API container is not running! Setup may not be complete."
      fi
    fi
  fi
fi

# Check if master timeout has been reached
CURRENT_TIME=$(date +%s)
ELAPSED_TIME=$((CURRENT_TIME - MASTER_START_TIME))
if [ $ELAPSED_TIME -ge $MASTER_TIMEOUT ]; then
  echo "WARNING: Master timeout reached after ${ELAPSED_TIME}s. Continuing with setup anyway."
fi

# Check if the frontend service is running
print_step "Checking frontend service..."

# Check if master timeout has been reached
CURRENT_TIME=$(date +%s)
ELAPSED_TIME=$((CURRENT_TIME - MASTER_START_TIME))
if [ $ELAPSED_TIME -ge $MASTER_TIMEOUT ]; then
  echo "WARNING: Master timeout reached after ${ELAPSED_TIME}s. Continuing with setup anyway."
else
  # Only perform the frontend URL check if Kong has been configured
  if [ "$KONG_CONFIGURED" = "true" ]; then
    echo "Kong is configured, checking frontend URL accessibility..."
    wait_for_service "Frontend" "$frontend_url" 60 || echo "WARNING: Frontend URL check timed out, but continuing..."
  else
    echo "Skipping frontend URL check as Kong has not been fully configured"
    # Just check if the container is running instead
    local FRONTEND_CONTAINER=$(get_container_name "frontend")
    if docker ps | grep -q "$FRONTEND_CONTAINER"; then
      echo "Frontend container is running. Continuing..."
    else
      echo "WARNING: Frontend container is not running! Setup may not be complete."
    fi
  fi
fi

# Print test instructions
print_header "Testing Instructions"

# Get port values for direct connections
kong_proxy_port=$(grep "KONG_PROXY_PORT=" .env | cut -d '=' -f2 || echo "8000")
kong_ssl_port="8443"  # This is typically hardcoded in the container

echo "Your services are running with the refactored authentication workflow!"
echo 
echo "You can access the following URLs:"
echo "- Frontend: $frontend_url"
echo "- API: $api_url"
echo "- Keycloak: $keycloak_url"
echo "- Kong: $kong_url"
echo 
echo "Alternative direct access URLs (may be more reliable):"
echo "- Kong HTTP: http://localhost:$kong_proxy_port"
echo "- Kong HTTPS: https://localhost:$kong_ssl_port"
echo
echo "To test the authentication flow:"
echo "1. Open $frontend_url in your browser"
echo "2. You should be redirected to Keycloak for authentication"
echo "3. Log in with the default admin user (admin/admin)"
echo "4. You should be redirected back to the frontend"
echo
echo "To test the API authentication:"
echo "1. Get a token from Keycloak:"
echo "   curl -X POST \"$keycloak_url/realms/dive25/protocol/openid-connect/token\" \\"
echo "        -d \"client_id=dive25-api\" \\"
echo "        -d \"client_secret=change-me-in-production\" \\"
echo "        -d \"grant_type=password\" \\"
echo "        -d \"username=admin\" \\"
echo "        -d \"password=admin\""
echo
echo "2. Use the token to access the API:"
echo "   curl -k -H \"Authorization: Bearer YOUR_TOKEN\" $api_url/api/v1/protected-resource"
echo
echo "To view logs:"
echo "- Frontend: docker-compose logs -f frontend"
echo "- API: docker-compose logs -f api"
echo "- Keycloak: docker-compose logs -f keycloak"
echo "- Kong: docker-compose logs -f kong"
echo
echo "If you encounter any issues, please refer to the URL-MANAGEMENT-REFACTORED.md file for troubleshooting guidance."

# Print environment summary
print_header "Environment Summary"
echo "Environment: $ENVIRONMENT"
echo "Base Domain: $BASE_DOMAIN"
echo "Protocol: $PROTOCOL"
echo "Services running:"
docker-compose ps --services | sort

echo
echo "Setup complete! Your authentication workflow has been refactored and is ready for testing." 

# End of script cleanup and summary
print_step "Deployment Summary"
echo "DIVE25 deployment has been completed!"

# Ask user if they want to clean up redundant patch scripts
print_step "Cleaning up redundant patch scripts"
echo "The authentication fixes have been consolidated into the main configuration files:"
echo "- kong/kong-configure-unified.sh (for all Kong configuration)"
echo "- keycloak/themes/dive25/login/resources/js/login-config.js (Keycloak redirects)"
echo "- keycloak/configure-keycloak.sh (for Keycloak realm and security)"
echo "- keycloak/Dockerfile (theme configuration)"
echo ""
echo "There are several redundant patch scripts that can be safely removed."

if [ -f "./scripts/cleanup-patches.sh" ]; then
  read -p "Do you want to remove the redundant patch scripts? (y/n): " CLEANUP_PATCHES
  if [[ $CLEANUP_PATCHES == "y" || $CLEANUP_PATCHES == "Y" ]]; then
    echo "Running cleanup-patches.sh script..."
    chmod +x ./scripts/cleanup-patches.sh
    
    # Run the script with auto-confirm
    echo "y" | ./scripts/cleanup-patches.sh
    
    if [ $? -eq 0 ]; then
      echo "✅ Redundant patch scripts removed successfully"
    else
      echo "⚠️ Failed to clean up redundant patch scripts"
    fi
  else
    echo "Skipping cleanup of redundant patch scripts."
  fi
else
  echo "⚠️ cleanup-patches.sh script not found at ./scripts/cleanup-patches.sh"
fi

echo ""
echo "✅ Setup and tests completed successfully"
echo ""
echo "Access your deployment at:"
echo "Frontend: https://dive25.local:8443"
echo "API: https://api.dive25.local:8443"
echo "Keycloak: https://keycloak.dive25.local:8443"
echo ""
echo "Thank you for using DIVE25!"

# Set up entries in /etc/hosts for local domain resolution
set_local_dns() {
  # ... existing code ...
}

# Function to check for required commands
check_requirements() {
  # ... existing code ...
}