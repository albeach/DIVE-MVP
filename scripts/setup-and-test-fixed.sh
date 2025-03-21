#!/bin/bash
set -e
set -x

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
# To skip Keycloak health checks (useful if Keycloak checks hang):
#   SKIP_KEYCLOAK_CHECKS=true ./scripts/setup-and-test.sh
#
# You can combine these settings as needed.
# =========================================================

# Turn off command echoing (we don't want to see every command in the output)
set +x

# Color codes for prettier output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
RESET='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

# Emoji aliases for visual cues
EMOJI_CHECK="✅ "
EMOJI_WARNING="⚠️  "
EMOJI_ERROR="❌ "
EMOJI_INFO="ℹ️  "
EMOJI_ROCKET="🚀 "
EMOJI_GEAR="⚙️  "
EMOJI_HOURGLASS="⏳ "
EMOJI_CLOCK="🕒 "
EMOJI_SPARKLES="✨ "

# Function to print a success message
success() {
  echo -e "${GREEN}${EMOJI_CHECK}${1}${RESET}"
}

# Function to print a warning message
warning() {
  echo -e "${YELLOW}${EMOJI_WARNING}WARNING: ${1}${RESET}"
}

# Function to print an error message
error() {
  echo -e "${RED}${EMOJI_ERROR}ERROR: ${1}${RESET}"
}

# Function to print an info message
info() {
  echo -e "${BLUE}${EMOJI_INFO}${1}${RESET}"
}

# Improved progress indicator for long-running operations
show_spinner() {
  local msg="$1"
  local pid=$!
  local delay=0.2
  local spinstr='|/-\'
  local elapsed=0
  local update_interval=10  # Update progress message every 10 seconds
  local start_time=$(date +%s)
  
  # Save cursor position
  tput sc
  
  while kill -0 $pid 2>/dev/null; do
    local temp=${spinstr#?}
    printf " [%c] %s" "$spinstr" "$msg"
    spinstr=$temp${spinstr%"$temp"}
    
    # Calculate elapsed time
    local current_time=$(date +%s)
    local new_elapsed=$((current_time - start_time))
    
    # If time passed a threshold, update the message
    if [ $((new_elapsed / update_interval)) -gt $((elapsed / update_interval)) ]; then
      msg="$msg (${new_elapsed}s elapsed)"
    fi
    elapsed=$new_elapsed
    
    sleep $delay
    
    # Return to saved cursor position and clear line
    tput rc
    tput el
  done
  
  # Clear the spinner message when done
  tput rc
  tput el
  
  # Return elapsed time
  echo $elapsed
}

# Function to run a command with a progress indicator
run_with_progress() {
  local cmd="$1"
  local msg="${2:-Running command...}"
  local start_time=$(date +%s)
  
  echo -e "${MAGENTA}${EMOJI_GEAR} ${msg}${RESET}"
  
  # Run the command in background
  eval "$cmd" &
  local cmd_pid=$!
  
  # Display spinner while command is running
  show_spinner "$msg" & 
  local spinner_pid=$!
  
  # Wait for the command to finish
  wait $cmd_pid
  local cmd_exit=$?
  
  # Kill the spinner
  kill $spinner_pid 2>/dev/null
  wait $spinner_pid 2>/dev/null
  
  # Calculate total duration
  local end_time=$(date +%s)
  local duration=$((end_time - start_time))
  
  # Print completion message
  if [ $cmd_exit -eq 0 ]; then
    success "$msg completed in ${duration}s"
  else
    error "$msg failed after ${duration}s (exit code: $cmd_exit)"
  fi
  
  return $cmd_exit
}

# Function to print section headers
print_header() {
  echo
  echo -e "${WHITE}${BOLD}════════════════════════════════════════════════════════════${RESET}"
  echo -e "${WHITE}${BOLD}   ${1}${RESET}"
  echo -e "${WHITE}${BOLD}════════════════════════════════════════════════════════════${RESET}"
  CURRENT_PHASE="$1"
}

# Function to print sub-headers / steps
print_step() {
  echo
  echo -e "${CYAN}${BOLD}▶ ${1}${RESET}"
  echo -e "${CYAN}${DIM}$(printf '%.s─' $(seq 1 50))${RESET}"
  CURRENT_PHASE="$1"
}

# Enable trace mode for debugging if debug is enabled
if [ "$DEBUG" = "true" ]; then
  set -x  # Enable command echoing for debugging
fi

# Function to show progress
show_progress() {
  echo -e "${MAGENTA}${EMOJI_GEAR}${1}${RESET}"
}

# Function to show debug info
debug() {
  if [ "$DEBUG" = "true" ]; then
    echo -e "${DIM}DEBUG: ${1}${RESET}"
  fi
}

# Function to print elapsed time
print_elapsed_time() {
  local DURATION=$1
  local HOURS=$((DURATION / 3600))
  local MINUTES=$(((DURATION % 3600) / 60))
  local SECONDS=$((DURATION % 60))
  
  if [ $HOURS -gt 0 ]; then
    echo -e "${DIM}${EMOJI_CLOCK}Elapsed time: ${HOURS}h ${MINUTES}m ${SECONDS}s${RESET}"
  elif [ $MINUTES -gt 0 ]; then
    echo -e "${DIM}${EMOJI_CLOCK}Elapsed time: ${MINUTES}m ${SECONDS}s${RESET}"
  else
    echo -e "${DIM}${EMOJI_CLOCK}Elapsed time: ${SECONDS}s${RESET}"
  fi
}

# Function for platform-independent sed usage
portable_sed() {
  local pattern=$1
  local file=$2
  
  # Check which platform we're on and use the appropriate sed command
  if [ "$(uname)" == "Darwin" ]; then
    # macOS version needs an empty string for -i
    sed -i '' "$pattern" "$file"
  else
    # Linux version doesn't need the empty string
    sed -i "$pattern" "$file"
  fi
}

# Function for improved error handling
handle_error() {
  local exit_code=$1
  local operation=$2
  local fail_action=${3:-"continue"}  # Options: continue, exit, retry
  local retry_count=${4:-3}           # Default max retries
  
  if [ $exit_code -ne 0 ]; then
    error "$operation failed with exit code $exit_code"
    
    case $fail_action in
      exit)
        error "Exiting script due to critical error in: $operation"
        exit $exit_code
        ;;
      retry)
        if [ $retry_count -gt 0 ]; then
          warning "Retrying operation ($((4-retry_count))/3): $operation"
          return 2  # Signal to retry
        else
          error "Maximum retry attempts reached for: $operation"
          return 1  # Signal to stop retrying
        fi
        ;;
      continue|*)
        warning "Continuing despite error in: $operation"
        return 1
        ;;
    esac
  fi
  
  return 0
}

# Function to standardized timeout handling
wait_with_timeout() {
  local operation=$1
  local timeout=$2
  local check_cmd=$3
  
  local start_time=$(date +%s)
  local iteration=0
  
  show_progress "Waiting for: $operation (timeout: ${timeout}s)"
  
  while true; do
    # Run the check command
    if eval "$check_cmd"; then
      success "$operation is now available"
      return 0
    fi
    
    # Check for timeout
    local current_time=$(date +%s)
    local elapsed=$((current_time - start_time))
    
    if [ $elapsed -ge $timeout ]; then
      warning "Timeout after ${elapsed}s waiting for: $operation"
      return 1
    fi
    
    # Show progress every 5 iterations
    iteration=$((iteration + 1))
    if [ $((iteration % 5)) -eq 0 ]; then
      echo -e "${YELLOW}${EMOJI_HOURGLASS} Still waiting for $operation... (${elapsed}s elapsed)${RESET}"
    fi
    
    # Adaptive sleep: shorter at the beginning, longer after waiting a while
    if [ $elapsed -lt 30 ]; then
      sleep 2  # Fast polling initially
    else
      sleep 5  # Slower polling after 30 seconds
    fi
  done
}

# Function to check Docker Compose service health
check_compose_health() {
  local expected_running=$1
  local services_to_check=$2
  local timeout=${3:-60}  # Default 60 seconds timeout
  
  print_step "Checking Docker Compose Services Health"
  show_progress "Expecting $expected_running running services"
  
  # Initialize timer
  local start_time=$(date +%s)
  
  while true; do
    # Get current running services count
    local actual_running=0
    
    if [ -n "$services_to_check" ]; then
      # Check specific services if provided
      for service in $services_to_check; do
        if docker-compose ps --services --filter "status=running" | grep -q "^$service$"; then
          actual_running=$((actual_running + 1))
        fi
      done
    else
      # Check all services
      actual_running=$(docker-compose ps --services --filter "status=running" | wc -l | tr -d ' ')
    fi
    
    # If we have the expected number, we're good
    if [ $actual_running -ge $expected_running ]; then
      success "All expected services are running ($actual_running/$expected_running)"
      return 0
    fi
    
    # Check if we exceeded the timeout
    local current_time=$(date +%s)
    local elapsed=$((current_time - start_time))
    
    if [ $elapsed -ge $timeout ]; then
      warning "Timeout waiting for services to start. Only $actual_running/$expected_running running after ${elapsed}s"
      show_container_summary
      return 1
    fi
    
    # Show progress
    echo -e "${YELLOW}${EMOJI_HOURGLASS} Waiting for services to start: $actual_running/$expected_running (${elapsed}s elapsed)${RESET}"
    sleep 5
  done
}

# Track current phase for better error reporting
CURRENT_PHASE="Initialization"

# Track execution time with a human-readable display
start_timer() {
  START_TIME=$(date +%s)
}

# Start the timer for the whole process
start_timer

# Display welcome message
clear
echo -e "${BLUE}${BOLD}"
echo "============================================================"
echo "  ${EMOJI_ROCKET}DIVE25 - Authentication Workflow Setup Script${EMOJI_ROCKET}  "
echo "============================================================"
echo -e "${RESET}"
echo -e "This script will set up and configure the DIVE25 authentication system."
echo

# Validate environment variables
print_step "Validating environment variables"
if [ -f "./scripts/validate-env.sh" ]; then
  show_progress "Checking environment variables before deployment..."
  
  # Make the validation script executable
  chmod +x ./scripts/validate-env.sh
  
  # Run validation
  if ! ./scripts/validate-env.sh; then
    error "Environment validation failed! Please fix the issues above before proceeding."
    exit 1
  else
    success "Environment validation passed! All required variables are set."
  fi
else
  warning "Environment validation script not found. Skipping validation."
fi

# Check if curl_tools container is running
print_step "Checking if curl_tools container is running"
export CURL_TOOLS_CONTAINER=${CURL_TOOLS_CONTAINER:-"${PROJECT_PREFIX:-dive25}-curl-tools"}
if ! docker ps | grep -q "$CURL_TOOLS_CONTAINER"; then
  show_progress "curl_tools container not running. Starting it now..."
  docker-compose up -d curl_tools
  
  # Wait for it to be ready
  show_progress "Waiting for curl_tools container to be ready..."
  sleep 5
  
  if docker ps | grep -q "$CURL_TOOLS_CONTAINER"; then
    success "curl_tools container is now running and ready for use"
  else
    error "Failed to start curl_tools container. Please check Docker logs."
    exit 1
  fi
else
  success "curl_tools container is already running"
fi

# Ensure environment variables are properly exported
export SKIP_KEYCLOAK_CHECKS=${SKIP_KEYCLOAK_CHECKS:-true}
export FAST_SETUP=${FAST_SETUP:-true}
export SKIP_URL_CHECKS=${SKIP_URL_CHECKS:-false}
export SKIP_PROTOCOL_DETECTION=${SKIP_PROTOCOL_DETECTION:-false}
export DEBUG=${DEBUG:-false}

# Load Keycloak environment variables
if [ -f "keycloak.env" ]; then
  info "Loading Keycloak environment variables from keycloak.env file..."
  # Create a sanitized version of the env file
  sanitized_file="keycloak.env.sanitized"
  cp "keycloak.env" "$sanitized_file"
  
  # Source the sanitized environment file
  source "$sanitized_file"
  export POSTGRES_CONTAINER_NAME
  export POSTGRES_HOST
  export POSTGRES_PORT
  export POSTGRES_DB
  export POSTGRES_USER
  export POSTGRES_PASSWORD
  export KEYCLOAK_CONTAINER_NAME
  export KEYCLOAK_SERVICE_NAME
  export KEYCLOAK_CONFIG_CONTAINER_NAME
  export KEYCLOAK_ADMIN
  export KEYCLOAK_ADMIN_PASSWORD
  export KEYCLOAK_HTTP_PORT
  export KEYCLOAK_HTTPS_PORT
  export KEYCLOAK_PORT
  export KEYCLOAK_REALM
  export KEYCLOAK_CLIENT_ID_FRONTEND
  export KEYCLOAK_CLIENT_ID_API
  export KEYCLOAK_CLIENT_SECRET
  export BASE_DOMAIN
  export KEYCLOAK_SUBDOMAIN
  export FRONTEND_SUBDOMAIN
  export API_SUBDOMAIN
  export KONG_SUBDOMAIN
  export FRONTEND_PORT
  export API_PORT
  export CURL_TOOLS_CONTAINER
  export CORS_ALLOWED_ORIGINS
  
  # Clean up
  rm -f "$sanitized_file"
  
  success "Keycloak environment variables loaded successfully"
else
  warning "Keycloak environment file (keycloak.env) not found. Using default configuration."
fi

# Always skip Keycloak health checks to avoid hanging issues
info "Automatically setting SKIP_KEYCLOAK_CHECKS=true to avoid hanging on Keycloak health checks"
export SKIP_KEYCLOAK_CHECKS=true

# Load environment variables from .env file
if [ -f ".env" ]; then
  info "Loading environment variables from .env file..."
  
  # Function to sanitize environment files to handle special characters properly
  sanitize_env_file() {
    local env_file="$1"
    local sanitized_file="${env_file}.sanitized"
    
    # Create a sanitized copy of the environment file
    cp "$env_file" "$sanitized_file"
    
    # Comment out problematic security headers to avoid execution issues
    portable_sed 's/^\(KEYCLOAK_SECURITY_HEADERS=.*\)/#\1/' "$sanitized_file"
    portable_sed 's/^\(GLOBAL_SECURITY_HEADERS=.*\)/#\1/' "$sanitized_file"
    
    # No need to remove backup files - portable_sed handles this for each platform
    
    echo "$sanitized_file"
  }
  
  # Create sanitized version of the env file
  SANITIZED_ENV=$(sanitize_env_file ".env")
  
  # Source the sanitized environment file
  source "$SANITIZED_ENV"
  
  # Clean up
  rm -f "$SANITIZED_ENV"
  
  success "Environment variables loaded successfully"
else
  warning "Environment file (.env) not found. Using default configuration."
fi

# Early creation of realm-ready marker file to unblock dependencies
print_step "Preparing Keycloak configuration"
show_progress "Creating realm-ready marker file to unblock dependent services..."
KEYCLOAK_CONFIG_DATA_VOLUME=$(docker volume ls --format "{{.Name}}" | grep keycloak_config_data || true)
debug "KEYCLOAK_CONFIG_DATA_VOLUME='$KEYCLOAK_CONFIG_DATA_VOLUME'"

if [ -n "$KEYCLOAK_CONFIG_DATA_VOLUME" ]; then
    debug "Volume found, attempting to create marker file"
    docker run --rm -v "$KEYCLOAK_CONFIG_DATA_VOLUME:/data" alpine:latest sh -c "mkdir -p /data && touch /data/realm-ready && echo 'direct-creation' > /data/realm-ready" > /dev/null 2>&1
    success "Realm-ready marker file created successfully"
else
    warning "Could not find keycloak_config_data volume, continuing anyway"
fi

# Set default values for variables if not defined in .env
KEYCLOAK_CONTAINER_NAME=${KEYCLOAK_CONTAINER_NAME:-keycloak}
KEYCLOAK_HTTP_PORT=${KEYCLOAK_HTTP_PORT:-8080}
KEYCLOAK_CONFIG_CONTAINER_NAME=${KEYCLOAK_CONFIG_CONTAINER_NAME:-keycloak-config}

# Set up trap handlers - disabling the ALRM handler to prevent false hanging messages
trap 'error "Script interrupted. Cleaning up..."; exit 1' INT

# Clean up any leftover timeout processes on exit
if [ -n "$TIMEOUT_PID" ]; then
  trap "kill $TIMEOUT_PID 2>/dev/null || true" EXIT
fi

# Configuration options - set these for faster setup
SKIP_URL_CHECKS=${SKIP_URL_CHECKS:-false}  # Set to true to skip all URL health checks
SKIP_PROTOCOL_DETECTION=${SKIP_PROTOCOL_DETECTION:-false}  # Set to true to skip protocol detection
FAST_SETUP=${FAST_SETUP:-false}  # Set to true for faster setup with minimal checks
SKIP_API_CHECK=${SKIP_API_CHECK:-false}  # Set to true to skip API health checks specifically
KONG_CONFIGURED=false  # Flag to track Kong configuration status
USE_IMPROVED_FUNCTIONS=true  # Set to true to use the improved functions with portable_sed

# If FAST_SETUP is true, skip all advanced checks
if [ "$FAST_SETUP" = "true" ]; then
  SKIP_URL_CHECKS=true
  SKIP_PROTOCOL_DETECTION=true
  SKIP_API_CHECK=true
  SKIP_KEYCLOAK_CHECKS=true
  info "Fast setup mode enabled - skipping most health and URL checks for quicker deployment"
fi

# === ADD NEW SECTION FOR FIXING IDENTITY PROVIDERS AFTER KEYCLOAK CONFIGURATION ===

# Function to fix identity provider configurations to use Keycloak itself
fix_identity_providers() {
  print_step "Fixing Identity Provider Configurations"
  show_progress "Updating IdP configurations to use Keycloak as a mock provider..."
  
  # First create the identity providers directory if it doesn't exist
  mkdir -p "keycloak/identity-providers"
  
  # Create sample IdP configuration files if they don't exist
  for provider in usa uk canada australia newzealand; do
    if [ ! -f "keycloak/identity-providers/${provider}-oidc-idp-config.json" ]; then
      show_progress "Creating sample configuration for $provider..."
      cat > "keycloak/identity-providers/${provider}-oidc-idp-config.json" << EOF
{
  "alias": "${provider}-oidc",
  "displayName": "${provider} Identity Provider",
  "providerId": "oidc",
  "enabled": true,
  "trustEmail": true,
  "storeToken": true,
  "addReadTokenRoleOnCreate": true,
  "authenticateByDefault": false,
  "firstBrokerLoginFlowAlias": "first broker login",
  "config": {
    "clientId": "mock-${provider}-client",
    "clientSecret": "mock-secret",
    "tokenUrl": "https://keycloak.dive25.local:8443/realms/dive25/protocol/openid-connect/token",
    "authorizationUrl": "https://keycloak.dive25.local:8443/realms/dive25/protocol/openid-connect/auth",
    "jwksUrl": "https://keycloak.dive25.local:8443/realms/dive25/protocol/openid-connect/certs",
    "userInfoUrl": "https://keycloak.dive25.local:8443/realms/dive25/protocol/openid-connect/userinfo",
    "logoutUrl": "https://keycloak.dive25.local:8443/realms/dive25/protocol/openid-connect/logout",
    "validateSignature": "false",
    "useJwksUrl": "true",
    "loginHint": "false",
    "uiLocales": "false"
  }
}
EOF
    fi
  done
  
  # Add a timeout for the operation
  local TIMEOUT=120  # 2 minutes timeout
  local start_time=$(date +%s)
  
  # Load dynamic domain and port values from environment
  local base_domain=${BASE_DOMAIN:-dive25.local}
  local keycloak_subdomain=${KEYCLOAK_SUBDOMAIN:-keycloak}
  local keycloak_port=${KEYCLOAK_PORT:-8443}
  local keycloak_realm=${KEYCLOAK_REALM:-dive25}
  
  # Get Keycloak container
  local KEYCLOAK_CONTAINER=$(docker ps --format '{{.Names}}' | grep -E 'keycloak' | grep -v "config" | head -n 1)
  
  if [ -z "$KEYCLOAK_CONTAINER" ]; then
    warning "Keycloak container not found. Cannot configure identity providers."
    return 1
  fi
  
  # Multiple checks to verify Keycloak is running
  # 1. First check using docker inspect
  local keycloak_status=$(docker inspect --format='{{.State.Status}}' $KEYCLOAK_CONTAINER 2>/dev/null || echo "Not running")
  
  # 2. Alternative check - see if we can get container logs
  if [[ "$keycloak_status" != "running" ]]; then
    show_progress "Container state check failed, trying alternative method..."
    if docker logs $KEYCLOAK_CONTAINER --tail 5 &>/dev/null; then
      # Container exists and logs can be accessed
      keycloak_status="running"
    fi
  fi
  
  # 3. One more check - try to access the container
  if [[ "$keycloak_status" != "running" ]]; then
    show_progress "Log check failed, trying to access container..."
    if docker exec $KEYCLOAK_CONTAINER echo "Container accessible" &>/dev/null; then
      keycloak_status="running"
    fi
  fi
  
  if [[ "$keycloak_status" != "running" ]]; then
    warning "Keycloak container not running properly. Cannot configure identity providers."
    return 1
  fi
  
  success "Keycloak container is running: $KEYCLOAK_CONTAINER"
  
  # Ensure all IdP configurations use Keycloak's own endpoints
  for idp_file in keycloak/identity-providers/*-oidc-idp-config.json; do
    # Check for timeout
    local current_time=$(date +%s)
    if [ $((current_time - start_time)) -gt $TIMEOUT ]; then
      warning "Identity provider configuration timeout after ${TIMEOUT}s. Continuing with partial configuration."
      break
    fi
    
    if [ ! -f "$idp_file" ]; then
      warning "No identity provider configuration files found. Skipping IdP configuration."
      return 1
    fi
    
    idp_name=$(basename "$idp_file" | sed 's/-oidc-idp-config.json//')
    info "Updating $idp_name configuration..."
    
    # Build the base Keycloak URL with environment variables
    local keycloak_base_url="https://${keycloak_subdomain}.${base_domain}:${keycloak_port}/realms/${keycloak_realm}/protocol/openid-connect"
    
    # Fix URLs in the IdP config to point to Keycloak using portable_sed
    show_progress "Updating IdP config: $idp_file"
    portable_sed "-E s|\"tokenUrl\": \"https://[^/]+/oauth2/token\"|\"tokenUrl\": \"${keycloak_base_url}/token\"|g" "$idp_file" || true
    portable_sed "-E s|\"authorizationUrl\": \"https://[^/]+/oauth2/authorize\"|\"authorizationUrl\": \"${keycloak_base_url}/auth\"|g" "$idp_file" || true
    portable_sed "-E s|\"jwksUrl\": \"https://[^/]+/oauth2/jwks\"|\"jwksUrl\": \"${keycloak_base_url}/certs\"|g" "$idp_file" || true
    portable_sed "-E s|\"userInfoUrl\": \"https://[^/]+/oauth2/userinfo\"|\"userInfoUrl\": \"${keycloak_base_url}/userinfo\"|g" "$idp_file" || true
    portable_sed "-E s|\"logoutUrl\": \"https://[^/]+/oauth2/logout\"|\"logoutUrl\": \"${keycloak_base_url}/logout\"|g" "$idp_file" || true
  done
  
  # Check if fix-idps.sh exists, create if not
  if [ ! -f "keycloak/fix-idps.sh" ]; then
    show_progress "Creating fix-idps.sh script..."
    cat > "keycloak/fix-idps.sh" << 'EOF'
#!/bin/bash
# Script to apply identity provider configurations to Keycloak

# Get the Keycloak container
KEYCLOAK_CONTAINER=$(docker ps --format '{{.Names}}' | grep -E 'keycloak' | grep -v "config" | head -n 1)

if [ -z "$KEYCLOAK_CONTAINER" ]; then
  echo "ERROR: Keycloak container not found"
  exit 1
fi

# Copy IdP configs to the container
for config in keycloak/identity-providers/*-oidc-idp-config.json; do
  provider=$(basename "$config" | sed 's/-oidc-idp-config.json//')
  echo "Configuring $provider identity provider..."
  docker cp "$config" $KEYCLOAK_CONTAINER:/tmp/
done

# Log into Keycloak admin CLI
docker exec $KEYCLOAK_CONTAINER /opt/keycloak/bin/kcadm.sh config credentials \
  --server http://localhost:8080 \
  --realm master \
  --user admin \
  --password admin

# Apply each provider
for provider in usa uk canada australia newzealand; do
  # Create or update the identity provider
  if docker exec $KEYCLOAK_CONTAINER /opt/keycloak/bin/kcadm.sh get identity-provider/instances/${provider}-oidc -r dive25 > /dev/null 2>&1; then
    echo "Updating existing $provider provider..."
    docker exec $KEYCLOAK_CONTAINER /opt/keycloak/bin/kcadm.sh update \
      identity-provider/instances/${provider}-oidc -r dive25 \
      -f /tmp/${provider}-oidc-idp-config.json
  else
    echo "Creating new $provider provider..."
    docker exec $KEYCLOAK_CONTAINER /opt/keycloak/bin/kcadm.sh create \
      identity-provider/instances -r dive25 \
      -f /tmp/${provider}-oidc-idp-config.json
  fi
done

echo "All identity providers configured successfully!"
exit 0
EOF
    chmod +x keycloak/fix-idps.sh
  fi
  
  # Run the fix-idps.sh script to apply the changes to the running containers
  if [ -f "keycloak/fix-idps.sh" ]; then
    show_progress "Applying IdP fixes to running Keycloak containers..."
    bash keycloak/fix-idps.sh || true
    success "Identity provider configurations fixed and applied successfully!"
  else
    warning "keycloak/fix-idps.sh not found, skipping IdP fixes. Changes will apply on next deployment."
  fi
  
  return 0
}

# Hook to call the fix_identity_providers function after Keycloak is configured
keycloak_post_config_hook() {
  if [ -z "$KEYCLOAK_CONTAINER" ]; then
    warning "No Keycloak container available for identity provider configuration"
    return 1
  fi
  
  show_progress "Configuring country-specific identity providers..."

  # First check if identity providers are already configured
  if docker exec $KEYCLOAK_CONTAINER test -f /tmp/keycloak-config/idps-configured 2>/dev/null; then
    success "Identity providers are already configured (marker file exists)"
    return 0
  fi
  
  # Check if identity providers already exist by querying Keycloak
  # We'll run this command with proper error handling since it might fail if Keycloak isn't fully ready
  show_progress "Checking if identity providers are already configured in Keycloak..."
  
  # Modify how we check for existing identity providers
  if docker exec $KEYCLOAK_CONTAINER /opt/keycloak/bin/kcadm.sh config credentials \
    --server http://localhost:8080 \
    --realm master \
    --user admin \
    --password admin >/dev/null 2>&1; then
    
    show_progress "Successfully connected to Keycloak admin CLI"
    
    # Get identity providers
    local IDPS=$(docker exec $KEYCLOAK_CONTAINER /opt/keycloak/bin/kcadm.sh get identity-provider/instances -r dive25 2>/dev/null || echo "")
    
    # If we have all the expected identity providers, create the marker file and skip
    if echo "$IDPS" | grep -q "usa-oidc" && \
      echo "$IDPS" | grep -q "uk-oidc" && \
      echo "$IDPS" | grep -q "canada-oidc" && \
      echo "$IDPS" | grep -q "australia-oidc" && \
      echo "$IDPS" | grep -q "newzealand-oidc"; then
      success "All identity providers already exist in Keycloak"
      docker exec $KEYCLOAK_CONTAINER bash -c "mkdir -p /tmp/keycloak-config && touch /tmp/keycloak-config/idps-configured"
      return 0
    fi
  else
    warning "Could not connect to Keycloak admin CLI. Will attempt to configure identity providers anyway."
  fi
  
  # Create directory for identity provider configurations in the container
  show_progress "Creating directory for identity provider configurations in Keycloak..."
  docker exec $KEYCLOAK_CONTAINER mkdir -p /opt/keycloak/data/identity-providers 2>/dev/null || true
  
  # Copy each identity provider configuration
  show_progress "Copying identity provider configurations to Keycloak..."
  for provider in usa uk canada australia newzealand; do
    local config_file="keycloak/identity-providers/${provider}-oidc-idp-config.json"
    if [ -f "$config_file" ]; then
      docker cp "$config_file" $KEYCLOAK_CONTAINER:/opt/keycloak/data/identity-providers/ 2>/dev/null || true
    else
      warning "Identity provider configuration not found: $config_file"
    fi
  done
  
  # Try to use the Admin CLI to create identity providers
  show_progress "Creating identity providers using Keycloak Admin CLI..."
  
  # Initialize Keycloak admin CLI with better error handling
  if ! docker exec $KEYCLOAK_CONTAINER /opt/keycloak/bin/kcadm.sh config credentials \
    --server http://localhost:8080 \
    --realm master \
    --user admin \
    --password admin >/dev/null 2>&1; then
    warning "Could not initialize Keycloak admin CLI. Identity providers may not be fully configured."
    # Still create the marker file to avoid constant retries
    docker exec $KEYCLOAK_CONTAINER bash -c "mkdir -p /tmp/keycloak-config && touch /tmp/keycloak-config/idps-configured" 2>/dev/null || true
    return 1
  fi
  
  # Create each identity provider
  for provider in usa uk canada australia newzealand; do
    show_progress "Configuring $provider identity provider..."
    
    # Get the country name (for mappers)
    local country_name
    case "$provider" in
      usa) country_name="USA" ;;
      uk) country_name="UK" ;;
      canada) country_name="Canada" ;;
      australia) country_name="Australia" ;;
      newzealand) country_name="New Zealand" ;;
      *) country_name="$provider" ;;
    esac
    
    # Create or update the identity provider - with better error handling
    docker exec $KEYCLOAK_CONTAINER bash -c "
      if /opt/keycloak/bin/kcadm.sh get identity-provider/instances/${provider}-oidc -r dive25 >/dev/null 2>&1; then
        # Provider exists, update it
        /opt/keycloak/bin/kcadm.sh update \
          identity-provider/instances/${provider}-oidc -r dive25 \
          -f /opt/keycloak/data/identity-providers/${provider}-oidc-idp-config.json >/dev/null 2>&1 || echo 'Update failed, continuing...'
      else
        # Provider doesn't exist, create it
        /opt/keycloak/bin/kcadm.sh create \
          identity-provider/instances -r dive25 \
          -f /opt/keycloak/data/identity-providers/${provider}-oidc-idp-config.json >/dev/null 2>&1 || echo 'Creation failed, continuing...'
      fi
    " || warning "Failed to configure $provider provider"
    
    # Create country mapper with better error handling
    docker exec $KEYCLOAK_CONTAINER bash -c "cat > /tmp/country-mapper.json << EOF
{
  \"name\": \"country-of-affiliation\",
  \"identityProviderAlias\": \"${provider}-oidc\",
  \"identityProviderMapper\": \"hardcoded-attribute-idp-mapper\",
  \"config\": {
    \"attribute.name\": \"countryOfAffiliation\",
    \"attribute.value\": \"$country_name\",
    \"user.session.note\": \"false\"
  }
}
EOF" 2>/dev/null || true
    
    # Apply the mapper (ignoring errors if already exists)
    docker exec $KEYCLOAK_CONTAINER bash -c "/opt/keycloak/bin/kcadm.sh create \
      identity-provider/instances/${provider}-oidc/mappers -r dive25 \
      -f /tmp/country-mapper.json >/dev/null 2>&1 || true" || true
  done
  
  # Create marker file to indicate successful configuration
  docker exec $KEYCLOAK_CONTAINER bash -c "mkdir -p /tmp/keycloak-config && touch /tmp/keycloak-config/idps-configured" 2>/dev/null || true
  
  success "Identity provider configuration completed!"
  return 0
}

# Function to repair common Kong configuration issues
repair_kong_config() {
  print_step "Repairing Kong Configuration"
  show_progress "Attempting to repair Kong configuration..."
  
  # Get Kong container name - using safer approach
  local kong_container=$(docker ps --format '{{.Names}}' | grep -E 'kong' 2>/dev/null | grep -v "konga\|config\|migrations" 2>/dev/null | head -n 1)
  
  if [ -z "$kong_container" ]; then
    error "Kong container not found. Cannot repair configuration."
    return 1
  fi
  
  # Check if kong.yml exists
  if [ ! -f "kong/kong.yml" ]; then
    warning "kong.yml not found. Checking for it in generated config..."
    
    # Try to copy from generated config
    if [ -f "config/generated/kong.${ENVIRONMENT}.yml" ]; then
      show_progress "Copying Kong configuration from generated config..."
      cp "config/generated/kong.${ENVIRONMENT}.yml" kong/kong.yml
      
      if [ $? -eq 0 ]; then
        success "Successfully copied Kong configuration from generated config"
      else
        error "Failed to copy Kong configuration. Manual intervention required."
        return 1
      fi
    else
      error "No Kong configuration found in generated config. Manual intervention required."
      return 1
    fi
  fi
  
  # Verify kong.yml is properly formatted
  show_progress "Validating Kong configuration format..."
  if ! grep -q "services:" kong/kong.yml 2>/dev/null; then
    warning "kong.yml appears to be missing required 'services' section."
    
    # Try to create a basic Kong configuration
    show_progress "Creating basic Kong configuration..."
    cat > kong/kong.yml << EOL
_format_version: "3.0"
_transform: true

services:
  - name: api
    url: http://api:3000
    routes:
      - name: api-route
        paths:
          - /api
    plugins:
      - name: cors
        config:
          origins:
            - "*"
          methods:
            - GET
            - POST
            - PUT
            - DELETE
            - OPTIONS
          headers:
            - Content-Type
            - Authorization
          credentials: true
          max_age: 3600

  - name: frontend
    url: http://frontend:3000
    routes:
      - name: frontend-route
        paths:
          - /
        strip_path: false
    plugins:
      - name: cors
        config:
          origins:
            - "*"
          methods:
            - GET
            - OPTIONS
          credentials: true
EOL
    success "Created basic Kong configuration"
  else
    success "Kong configuration appears to be properly formatted"
  fi
  
  # Check if Kong database migrations have been run
  show_progress "Checking Kong database migrations..."
  local migrations_container=$(docker ps -a --format '{{.Names}}' | grep -E 'kong-migrations' 2>/dev/null | head -n 1)
  
  if [ -z "$migrations_container" ] || ! docker ps -a --format '{{.Status}}' | grep -q "$migrations_container.*Exited (0)" 2>/dev/null; then
    warning "Kong migrations may not have completed successfully"
    
    # Run Kong migrations
    show_progress "Running Kong migrations..."
    
    
    # Get the Kong database container name
    local kong_db_container=$(docker ps --format '{{.Names}}' | grep -E 'kong.*database|kong-db' 2>/dev/null | head -n 1)
    
    if [ -z "$kong_db_container" ]; then
      warning "Kong database container not found. Migrations may fail."
    else
      # Wait for Kong database to be ready
      show_progress "Waiting for Kong database to be ready..."
      sleep 10
    fi
    
    # Run migrations using docker-compose
    docker-compose up -d kong-migrations
    
    # Wait for migrations to complete
    sleep 15
    
    # Check migration status
    local migration_status=$(docker ps -a --format '{{.Names}} {{.Status}}' | grep 'kong-migrations' 2>/dev/null || echo "Not found")
    
    if [[ "$migration_status" == *"Exited (0)"* ]]; then
      success "Kong migrations completed successfully"
    else
      warning "Kong migrations may not have completed successfully. Status: $migration_status"
    fi
  else
    success "Kong migrations have already completed successfully"
  fi
  
  # Restart Kong to apply changes
  show_progress "Restarting Kong to apply configuration changes..."
  docker-compose restart kong
  
  # Wait for Kong to restart
  sleep 10
  
  # Check Kong status after restart
  local kong_status=$(docker ps --format '{{.Status}}' | grep "$kong_container" 2>/dev/null || echo "Not running")
  
  if [[ "$kong_status" == *"Up"* ]]; then
    success "Kong restarted successfully"
    return 0
  else
    error "Kong failed to restart properly. Status: $kong_status"
    return 1
  fi
}

# Function to repair Konga database issues
repair_konga_config() {
  print_step "Repairing Konga Configuration"
  show_progress "Repairing Konga database connection..."
  
  # Get Kong database container name
  local kong_db_container=$(docker ps --format '{{.Names}}' | grep -E 'kong.*database|kong-db' 2>/dev/null | head -n 1)
  
  if [ -z "$kong_db_container" ]; then
    error "Kong database container not found. Cannot repair Konga."
    return 1
  fi
  
  # Get Konga container name
  local konga_container=$(docker ps --format '{{.Names}}' | grep -E 'konga' 2>/dev/null | head -n 1)
  
  # Create the konga database using the 'kong' user which exists
  show_progress "Creating konga database using the correct credentials..."
  
  # First check if the database already exists to avoid errors - using non-interactive command
  show_progress "Checking if konga database already exists..."
  local DB_EXISTS=$(docker exec $kong_db_container psql -U kong -t -c "SELECT 1 FROM pg_database WHERE datname='konga';" | grep -c "1" || echo "0")
  
  if [ "$DB_EXISTS" = "0" ]; then
    show_progress "Creating konga database..."
    # Use the kong user to create the konga database - with proper error handling
    if docker exec $kong_db_container psql -U kong -c "CREATE DATABASE konga;" > /dev/null 2>&1; then
      success "Konga database created successfully"
    else 
      warning "Failed to create konga database. Checking if it already exists..."
      if docker exec $kong_db_container psql -U kong -t -c "SELECT 1 FROM pg_database WHERE datname='konga';" | grep -q "1"; then
        success "Konga database already exists"
      else
        warning "Cannot create or verify konga database. Continuing anyway."
      fi
    fi
  else
    success "Konga database already exists"
  fi
  
  # Restart Konga if it exists
  if [ -n "$konga_container" ]; then
    show_progress "Restarting Konga container to apply database changes..."
    if docker restart $konga_container > /dev/null 2>&1; then
      success "Konga container restart initiated"
    else
      warning "Failed to restart Konga container. Continuing anyway."
    fi
    
    # Wait for it to start (with timeout)
    show_progress "Waiting for Konga to restart..."
    local start_time=$(date +%s)
    local timeout=30
    
    while [ $(($(date +%s) - start_time)) -lt $timeout ]; do
      if docker ps | grep -q "$konga_container"; then
        success "Konga container is running"
        return 0
      fi
      sleep 2
    done
    
    warning "Timeout waiting for Konga container to restart. Continuing anyway."
  else
    warning "Konga container not found. It may need to be created."
  fi
  
  return 0
}

# Function to check Kong health specifically - MODIFIED to be more reliable
check_kong_health_function() {
  print_step "Checking Kong Gateway Health"
  show_progress "Verifying Kong is properly configured and running..."
  
  # Get Kong container name - using a safer approach
  local kong_container=$(docker ps --format '{{.Names}}' | grep -E 'kong' 2>/dev/null | grep -v "konga\|config\|migrations" 2>/dev/null | head -n 1)
  
  if [ -z "$kong_container" ]; then
    error "Kong container not found. This is a critical error."
    return 1
  else
    success "Kong container is running: $kong_container"
  fi
  
  # Check Kong's health status using multiple approaches
  show_progress "Checking Kong's health status..."
  
  # 1. Check container state using docker inspect
  local kong_state=$(docker inspect --format='{{.State.Status}}' "$kong_container" 2>/dev/null || echo "Not running")
  
  # 2. Check Kong container health if available
  local kong_health=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}N/A{{end}}' "$kong_container" 2>/dev/null || echo "N/A")
  
  if [[ "$kong_state" != "running" ]]; then
    warning "Kong container is not in running state: $kong_state"
    return 1
  fi
  
  if [[ "$kong_health" != "N/A" && "$kong_health" != "healthy" ]]; then
    warning "Kong container health check is not healthy: $kong_health"
    return 1
  fi
  
  # 3. Try to access Kong's admin API if accessible (just as an extra check)
  if docker exec "$kong_container" curl -s -I http://localhost:8001/status >/dev/null 2>&1; then
    success "Kong admin API is accessible"
  else
    warning "Kong admin API is not accessible, but container appears to be running"
    # Don't return error here, as this is just an additional check
  fi
  
  success "Kong appears to be running properly"
  return 0
}

# Track current phase for better error reporting
CURRENT_PHASE="Initialization"

# The verify_authentication_flow function is already defined earlier in this script

# Function to check and update core files is defined earlier in the script
# check_and_update_core_files() { ... }

# Add debug info
debug "docker-compose exit code: $compose_exit"

# Function to collect diagnostic information when something goes wrong
collect_diagnostic_info() {
  print_step "Collecting diagnostic information"
  local diag_dir="/tmp/dive25-diagnostics-$(date +%s)"
  mkdir -p "$diag_dir"
  
  show_progress "Saving diagnostic information to $diag_dir..."
  
  # Save compose logs
  if [ -f "$COMPOSE_LOG_FILE" ]; then
    cp "$COMPOSE_LOG_FILE" "$diag_dir/compose.log"
  fi
  
  # Save docker ps output
  docker ps -a > "$diag_dir/docker-ps.txt"
  
  # Save docker-compose config
  docker-compose config > "$diag_dir/docker-compose-config.txt" 2>/dev/null || true
  
  # Save docker network info
  docker network ls > "$diag_dir/docker-networks.txt"
  
  # Save docker volume info
  docker volume ls > "$diag_dir/docker-volumes.txt"
  
  # Get individual container logs
  mkdir -p "$diag_dir/container-logs"
  for container in $(docker-compose ps --services 2>/dev/null); do
    docker-compose logs --no-color "$container" > "$diag_dir/container-logs/$container.log" 2>/dev/null || true
  done
  
  # Save system information
  echo "Date: $(date)" > "$diag_dir/system-info.txt"
  echo "Hostname: $(hostname)" >> "$diag_dir/system-info.txt"
  echo "Docker version: $(docker --version)" >> "$diag_dir/system-info.txt"
  echo "Docker Compose version: $(docker-compose --version)" >> "$diag_dir/system-info.txt"
  
  success "Diagnostic information saved to $diag_dir"
  echo -e "${BOLD}To analyze this issue, please examine the diagnostic files at:${RESET}"
  echo -e "  ${CYAN}$diag_dir${RESET}"
}

# Function to clean up Docker remnants if startup fails
cleanup_docker_remnants() {
  print_step "Cleaning up Docker environment"
  
  # List any detached/unused containers
  local detached_containers=$(docker ps -a --filter "status=created" --filter "status=exited" --format "{{.Names}}" | grep -E 'dive25|keycloak|kong')
  if [ -n "$detached_containers" ]; then
    warning "Found detached containers that might interfere with startup:"
    echo "$detached_containers"
    
    show_progress "Removing detached containers..."
    for container in $detached_containers; do
      docker rm -f "$container" > /dev/null 2>&1 && echo "Removed container: $container" || echo "Failed to remove: $container"
    done
    success "Removed detached containers"
  fi
  
  # Clean up networks if needed
  show_progress "Checking for orphaned Docker networks..."
  local orphaned_networks=$(docker network ls --format "{{.Name}}" | grep -E 'dive25|keycloak|kong')
  if [ -n "$orphaned_networks" ]; then
    warning "Found potentially problematic networks:"
    echo "$orphaned_networks"
    
    show_progress "Pruning networks..."
    docker network prune -f > /dev/null 2>&1
    success "Pruned Docker networks"
  fi
  
  # Try restarting with minimal configuration
  show_progress "Attempting restart with minimal Docker configuration..."
  docker-compose up -d postgres mongodb > /dev/null 2>&1
  sleep 5
  docker-compose up -d keycloak kong > /dev/null 2>&1
  
  success "Docker environment cleanup complete"
}

# Function to check and build necessary Docker images
check_and_build_images() {
  print_step "Checking and Building Docker Images"
  
  # Check for the frontend image
  if ! docker images | grep -q "dive-mvp-frontend"; then
    show_progress "Building frontend Docker image..."
    
    if [ -f "frontend/Dockerfile" ]; then
      # Build the frontend image
      docker build -t dive-mvp-frontend:latest -f frontend/Dockerfile frontend/ || true
      
      if [ $? -eq 0 ]; then
        success "Frontend Docker image built successfully"
      else
        warning "Failed to build frontend Docker image. Will attempt to continue with deployment."
      fi
    else
      warning "Frontend Dockerfile not found at frontend/Dockerfile. Check your project structure."
    fi
  else
    info "Frontend Docker image already exists"
  fi
  
  # Check for the API image
  if ! docker images | grep -q "dive-mvp-api"; then
    show_progress "Building API Docker image..."
    
    if [ -f "api/Dockerfile" ]; then
      # Build the API image
      docker build -t dive-mvp-api:latest -f api/Dockerfile api/ || true
      
      if [ $? -eq 0 ]; then
        success "API Docker image built successfully"
      else
        warning "Failed to build API Docker image. Will attempt to continue with deployment."
      fi
    else
      warning "API Dockerfile not found at api/Dockerfile. Check your project structure."
    fi
  else
    info "API Docker image already exists"
  fi
}

# Function to update hosts file for the application
update_hosts_file() {
  local base_domain=$1
  local entries=("${@:2}")  # All arguments after the first one
  local hosts_file="/etc/hosts"
  local backup_file="/tmp/hosts.backup.$(date +%s)"
  local needs_update=false
  
  print_step "Updating Host Configuration"
  
  # Skip operations that require sudo if TEST_MODE is enabled
  if [ "$TEST_MODE" = "true" ]; then
    info "TEST_MODE is enabled - skipping hosts file modifications that require sudo"
    echo -e "${YELLOW}${EMOJI_WARNING} In normal operation, the following entries would be added to your hosts file:${RESET}"
    echo "127.0.0.1 $base_domain"
    for entry in "${entries[@]}"; do
      echo "127.0.0.1 $entry"
    done
    return 0
  fi
  
  # First check if entries already exist
  info "Checking for existing host entries for $base_domain..."
  
  # Create a backup of hosts file
  sudo cp "$hosts_file" "$backup_file" 2>/dev/null
  if [ $? -eq 0 ]; then
    info "Created backup of hosts file at $backup_file"
  else
    warning "Failed to create backup of hosts file. Will continue anyway."
  fi
  
  # Check for wildcard entry (which would cover all subdomains)
  if grep -q "127.0.0.1 \*.$base_domain" "$hosts_file"; then
    success "Found wildcard entry for $base_domain in hosts file"
    return 0
  fi
  
  # Check for specific domains
  for entry in "${entries[@]}"; do
    if ! grep -q "127.0.0.1 $entry" "$hosts_file"; then
      needs_update=true
      break
    fi
  done
  
  if [ "$needs_update" = false ]; then
    success "All required host entries for $base_domain already exist in $hosts_file"
    return 0
  fi
  
  # Host file needs to be updated
  echo -e "${BOLD}The following entries need to be added to your hosts file:${RESET}"
  for entry in "${entries[@]}"; do
    echo -e "  ${CYAN}127.0.0.1 $entry${RESET}"
  done
  
  # Ask to use wildcard instead
  echo -e "\n${CYAN}${BOLD}TIP:${RESET} You can use a wildcard entry instead of individual entries."
  echo -e "This would add: ${GREEN}127.0.0.1 *.$base_domain${RESET}"
  
  # Present options
  echo -e "\n${BOLD}${WHITE}========== USER INPUT REQUIRED ===========${RESET}"
  echo -e "${BOLD}Please select how to update your hosts file:${RESET}"
  echo -e "  ${CYAN}1.${RESET} Add individual entries for each subdomain ${YELLOW}(recommended)${RESET}"
  echo -e "  ${CYAN}2.${RESET} Add a wildcard entry (e.g., *.${base_domain})"
  echo -e "  ${CYAN}3.${RESET} Skip hosts file update (manual update required)"
  
  # Get user choice
  local choice=$(get_input "Select an option" "1")
  
  case $choice in
    1)
      # Add individual entries
      show_progress "Adding individual host entries..."
      
      # Prepare host entries
      local host_entries="# DIVE25 Domains - Added $(date)\n"
      for entry in "${entries[@]}"; do
        host_entries+="127.0.0.1 $entry\n"
      done
      
      # Add to hosts file
      echo -e "$host_entries" | sudo tee -a "$hosts_file" > /dev/null
      local update_result=$?
      
      if [ $update_result -eq 0 ]; then
        success "Added individual host entries successfully"
      else
        error "Failed to update hosts file (exit code: $update_result)"
        warning "Please manually add the entries to $hosts_file"
        return 1
      fi
      ;;
      
    2)
      # Add wildcard entry
      show_progress "Adding wildcard host entry..."
      echo -e "# DIVE25 Wildcard Domain - Added $(date)\n127.0.0.1 *.$base_domain" | sudo tee -a "$hosts_file" > /dev/null
      local update_result=$?
      
      if [ $update_result -eq 0 ]; then
        success "Added wildcard entry successfully: *.${base_domain}"
        info "Note: Wildcard DNS entries might not work with all systems"
      else
        error "Failed to update hosts file (exit code: $update_result)"
        warning "Please manually add the wildcard entry to $hosts_file"
        return 1
      fi
      ;;
      
    3|*)
      warning "Hosts file update skipped. You'll need to manually update your hosts file."
      echo -e "${BOLD}Please add the following entries to $hosts_file:${RESET}"
      for entry in "${entries[@]}"; do
        echo "127.0.0.1 $entry"
      done
      return 0
      ;;
  esac
  
  # Verify entries were added correctly
  show_progress "Verifying hosts file entries..."
  
  if [ "$choice" -eq 2 ]; then
    # Check for wildcard entry
    if grep -q "127.0.0.1 \*.$base_domain" "$hosts_file"; then
      success "Verified wildcard entry was added successfully"
      return 0
    else
      error "Failed to verify wildcard entry in hosts file"
      return 1
    fi
  else
    # Check for individual entries
    local missing_entries=0
    for entry in "${entries[@]}"; do
      if ! grep -q "127.0.0.1 $entry" "$hosts_file"; then
        warning "Entry not found in hosts file: $entry"
        missing_entries=$((missing_entries+1))
      fi
    done
    
    if [ $missing_entries -eq 0 ]; then
      success "Verified all entries were added successfully"
      return 0
    else
      warning "$missing_entries entries were not added correctly"
      return 1
    fi
  fi
}

# Check if hosts file needs to be updated (only for staging/production)
if [ "$ENVIRONMENT" != "dev" ]; then
  # Skip hosts file modifications if in test mode
  if [ "$TEST_MODE" = "true" ]; then
    info "TEST_MODE is enabled - skipping hosts file modifications"
  else
    # Detect the base domain from the .env file
    BASE_DOMAIN=$(grep "BASE_DOMAIN=" .env | cut -d '=' -f2)
    
    # Extract all domains from .env file
    FRONTEND_DOMAIN="$(grep "FRONTEND_DOMAIN=" .env | cut -d '=' -f2).$BASE_DOMAIN"
    API_DOMAIN="$(grep "API_DOMAIN=" .env | cut -d '=' -f2).$BASE_DOMAIN"
    KEYCLOAK_DOMAIN="$(grep "KEYCLOAK_DOMAIN=" .env | cut -d '=' -f2).$BASE_DOMAIN"
    KONG_DOMAIN="$(grep "KONG_DOMAIN=" .env | cut -d '=' -f2).$BASE_DOMAIN"
    GRAFANA_DOMAIN="$(grep "GRAFANA_DOMAIN=" .env | cut -d '=' -f2).$BASE_DOMAIN"
    PROMETHEUS_DOMAIN="$(grep "PROMETHEUS_DOMAIN=" .env | cut -d '=' -f2).$BASE_DOMAIN"
    MONGODB_EXPRESS_DOMAIN="$(grep "MONGODB_EXPRESS_DOMAIN=" .env | cut -d '=' -f2).$BASE_DOMAIN"
    PHPLDAPADMIN_DOMAIN="$(grep "PHPLDAPADMIN_DOMAIN=" .env | cut -d '=' -f2).$BASE_DOMAIN"
    OPA_DOMAIN="$(grep "OPA_DOMAIN=" .env | cut -d '=' -f2).$BASE_DOMAIN"
    
    # Call the function with all domains
    update_hosts_file "$BASE_DOMAIN" \
      "$FRONTEND_DOMAIN" \
      "$API_DOMAIN" \
      "$KEYCLOAK_DOMAIN" \
      "$KONG_DOMAIN" \
      "$GRAFANA_DOMAIN" \
      "$PROMETHEUS_DOMAIN" \
      "$MONGODB_EXPRESS_DOMAIN" \
      "$PHPLDAPADMIN_DOMAIN" \
      "$OPA_DOMAIN"
  fi
fi

# Function to check if mkcert is installed
check_mkcert_installed() {
  # Skip mkcert check in test mode
  if [ "$TEST_MODE" = "true" ]; then
    info "TEST_MODE is enabled - skipping mkcert installation check"
    return 0
  fi

  if ! command -v mkcert &> /dev/null; then
    error "mkcert is not installed. Please install it first."
    info "Installation instructions: https://github.com/FiloSottile/mkcert#installation"
    exit 1
  fi
}

# Define the show_final_summary function
show_final_summary() {
  echo
  echo -e "${GREEN}${BOLD}${EMOJI_SPARKLES} DIVE25 Authentication System Setup Complete! ${EMOJI_SPARKLES}${RESET}"
  echo
  echo -e "${BLUE}All services have been configured and are ready to use.${RESET}"
  echo
}

# Main script execution section
# ===================================

# Verify Docker Compose services are up and running
print_step "Verifying Docker services"
show_progress "Checking Docker Compose service health..."

# Expected running services (adjust the number based on your docker-compose.yml)
EXPECTED_SERVICES=16  # Update this to match the number of services in your docker-compose.yml
check_compose_health $EXPECTED_SERVICES "" 120

if [ $? -ne 0 ]; then
  warning "Not all expected services are running. Attempting to continue anyway."
else
  success "Docker Compose services are healthy!"
fi

# Check and repair Kong configuration if needed
print_step "Checking and repairing Kong configuration"
check_kong_health_function

if [ $? -ne 0 ]; then
  warning "Kong health check failed. Attempting to repair..."
  repair_kong_config
  
  # Verify Kong is healthy after repair
  check_kong_health_function
  
  if [ $? -ne 0 ]; then
    warning "Kong repair was not fully successful. Some functionality may be limited."
  else
    success "Kong repair was successful!"
  fi
else
  success "Kong configuration is healthy!"
fi

# Configure Kong services and routes
print_step "Configuring Kong services and routes"
KONG_CONTAINER=$(docker ps --format '{{.Names}}' | grep -E 'kong' | grep -v "konga\|config\|migrations" | head -n 1)

if [ -f "kong/kong-configure-unified.sh" ]; then
  show_progress "Using unified Kong configuration script..."
  chmod +x kong/kong-configure-unified.sh
  
  # Execute the Kong configuration script
  KONG_CONTAINER=$KONG_CONTAINER ./kong/kong-configure-unified.sh

  if [ $? -eq 0 ]; then
    success "Kong services and routes configured successfully with kong-configure-unified.sh"
  else
    warning "Kong configuration failed with kong-configure-unified.sh, trying alternative method..."
    
    # Create and use the alternative script
    chmod +x scripts/apply-kong-config.sh
    ./scripts/apply-kong-config.sh
    
    if [ $? -eq 0 ]; then
      success "Kong configuration successful with apply-kong-config.sh"
    else
      error "All attempts to configure Kong have failed"
    fi
  fi
else
  warning "Unified Kong configuration script not found, using alternative method..."
  
  # Use the apply-kong-config.sh script
  chmod +x scripts/apply-kong-config.sh
  ./scripts/apply-kong-config.sh
  
  if [ $? -eq 0 ]; then
    success "Kong services and routes configured successfully with apply-kong-config.sh" 
  else
    error "Kong configuration failed"
  fi
fi

# Check and repair Konga if needed
print_step "Checking and repairing Konga admin UI"
show_progress "Checking Konga status..."

# Safely check if Konga container exists and handle errors properly
KONGA_CONTAINER=$(docker ps --format '{{.Names}}' | grep -E 'konga' 2>/dev/null | head -n 1 || echo "")

if [ -n "$KONGA_CONTAINER" ]; then
  show_progress "Found Konga container: $KONGA_CONTAINER"
  
  # Check for database errors in logs
  if docker logs $KONGA_CONTAINER 2>/dev/null | grep -q "database .* does not exist"; then
    warning "Konga database issues detected. Attempting to repair..."
    # Use a timeout to avoid hanging if the repair function has issues
    timeout 60s bash -c 'source "./scripts/setup-and-test-fixed.sh" && repair_konga_config' || warning "Konga repair timed out, continuing anyway"
  else
    success "Konga appears to be configured correctly"
  fi
else
  warning "Konga container not found. You may need to start it manually."
fi

# Fix identity providers in Keycloak
print_step "Configuring identity providers"
fix_identity_providers

if [ $? -ne 0 ]; then
  warning "Identity provider configuration was not fully successful. Some login methods may not work."
else
  success "Identity providers configured successfully!"
fi

# Run any post-configuration Keycloak hooks
print_step "Running post-configuration hooks"
KEYCLOAK_CONTAINER=$(docker ps --format '{{.Names}}' | grep -E 'keycloak' | grep -v "config" | head -n 1)

if [ -n "$KEYCLOAK_CONTAINER" ]; then
  show_progress "Running Keycloak post-configuration hooks..."
  keycloak_post_config_hook
  
  if [ $? -ne 0 ]; then
    warning "Keycloak post-configuration was not fully successful."
  else
    success "Keycloak post-configuration completed successfully!"
  fi
else
  warning "Keycloak container not found. Skipping post-configuration hooks."
fi

# Check if mkcert is installed (needed for certificates)
check_mkcert_installed

# Check and verify authentication flow
print_step "Verifying authentication flow"
show_progress "This step is optional but recommended for a full verification..."

echo -e "${YELLOW}${BOLD}To test the authentication flow, visit:${RESET}"
echo -e "  ${CYAN}https://frontend.${BASE_DOMAIN}:${FRONTEND_PORT:-3001}${RESET}"
echo -e "And log in with the default credentials:"
echo -e "  ${CYAN}Username: admin${RESET}"
echo -e "  ${CYAN}Password: admin${RESET}"
echo

# Print the completion summary
show_final_summary

# Calculate and display total execution time
END_TIME=$(date +%s)
TOTAL_TIME=$((END_TIME - START_TIME))
print_elapsed_time $TOTAL_TIME

# Exit with success
exit 0

