#!/bin/bash
# Main deployment script that brings together all modules

# Set strict error handling
set -e

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
MODULAR_SCRIPTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Import utility functions
source "$MODULAR_SCRIPTS_DIR/utils/logging.sh"
source "$MODULAR_SCRIPTS_DIR/utils/system.sh"
source "$MODULAR_SCRIPTS_DIR/utils/config.sh"

# Import module scripts
source "$MODULAR_SCRIPTS_DIR/docker/cleanup.sh"
source "$MODULAR_SCRIPTS_DIR/certificates/cert-manager.sh"
source "$MODULAR_SCRIPTS_DIR/network/network-utils.sh"
source "$MODULAR_SCRIPTS_DIR/kong/kong-setup.sh"
source "$MODULAR_SCRIPTS_DIR/keycloak/keycloak-setup.sh"
source "$MODULAR_SCRIPTS_DIR/verification/health-checks.sh"

# Display welcome message and explain what the script does
show_welcome() {
  clear
  echo -e "${BLUE}${BOLD}"
  echo "============================================================"
  echo "  ${EMOJI_ROCKET}DIVE25 - Authentication Workflow Setup Script${EMOJI_ROCKET}  "
  echo "============================================================"
  echo -e "${RESET}"
  echo -e "This script will set up and configure the DIVE25 authentication system."
  echo
}

# Function to select environment
select_environment() {
  print_header "Environment Selection"
  
  # In test or fast mode, use default environment without prompting
  if [ "$TEST_MODE" = "true" ] || [ "$FAST_SETUP" = "true" ]; then
    ENVIRONMENT="dev"
    ENV_DISPLAY="Development"
    info "Using default environment (Development) in test/fast mode"
  else
    echo -e "Please select the environment to set up:"
    echo -e "  ${CYAN}1.${RESET} Development ${YELLOW}(default)${RESET}"
    echo -e "  ${CYAN}2.${RESET} Staging"
    echo -e "  ${CYAN}3.${RESET} Production"
    echo
    
    # Use a simpler method for input to avoid the issue
    echo -e "\n${BOLD}${WHITE}========== USER INPUT REQUIRED ===========${RESET}"
    echo -en "${BOLD}${CYAN}>>> Please make a selection${RESET} [1]: "
    read env_choice
    
    # Debug line to see what's actually captured
    debug "User selected option: '$env_choice'"
    
    # Use default if empty
    if [ -z "$env_choice" ]; then
      env_choice="1"
    fi
    
    # Sanitize the input to prevent unexpected values
    env_choice=$(echo "$env_choice" | tr -d '[:space:]')
    
    case $env_choice in
      1|"")
        ENVIRONMENT="dev"
        ENV_DISPLAY="Development"
        ;;
      2)
        ENVIRONMENT="staging"
        ENV_DISPLAY="Staging"
        ;;
      3)
        ENVIRONMENT="prod"
        ENV_DISPLAY="Production"
        ;;
      *)
        echo -e "${YELLOW}${EMOJI_WARNING} WARNING: Invalid choice '${env_choice}'.${RESET}"
        echo -e "Defaulting to development environment."
        ENVIRONMENT="dev"
        ENV_DISPLAY="Development"
        ;;
    esac
  fi
  
  export ENVIRONMENT
  success "Using ${BOLD}$ENV_DISPLAY${RESET} environment"
}

# Function to check if containers are healthy
check_containers_health() {
  local required_containers=("$@")
  local unhealthy=()
  local missing=()
  
  for container in "${required_containers[@]}"; do
    # Check if container exists
    if ! docker ps --format '{{.Names}}' | grep -q "$container"; then
      missing+=("$container")
      continue
    fi
    
    # Check container health
    local status=$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null)
    local health=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$container" 2>/dev/null)
    
    if [ "$status" != "running" ]; then
      unhealthy+=("$container (status: $status)")
    elif [ "$health" != "healthy" ] && [ "$health" != "none" ]; then
      unhealthy+=("$container (health: $health)")
    fi
  done
  
  # Return results
  if [ ${#missing[@]} -gt 0 ]; then
    error "Missing containers: ${missing[*]}"
    return 1
  fi
  
  if [ ${#unhealthy[@]} -gt 0 ]; then
    error "Unhealthy containers: ${unhealthy[*]}"
    return 1
  fi
  
  return 0
}

# Function to ensure Kong Admin API is accessible
ensure_kong_admin_api() {
  print_step "Ensuring Kong Admin API is accessible"
  
  # First ensure the Kong container is healthy
  local kong_container=$(docker ps --format '{{.Names}}' | grep -E 'dive25.*kong$' | grep -v "config\|migrations\|database\|konga" | head -n 1)
  
  if [ -z "$kong_container" ]; then
    error "Kong container not found"
    return 1
  fi
  
  show_progress "Checking Kong container health..."
  
  if ! check_containers_health "$kong_container"; then
    error "Kong container is not healthy"
    return 1
  fi
  
  # Check if Kong Admin API is accessible on the expected port
  show_progress "Verifying Kong Admin API is responsive..."
  
  # Define the fixed admin URL - this is the standard port mapping used in docker-compose
  export KONG_ADMIN_URL="http://localhost:9444"
  
  # Provide diagnostic information
  info "Checking Kong Admin API at: $KONG_ADMIN_URL/status"
  
  # Try to access the Kong Admin API with diagnostic output for debugging
  local http_code=$(curl -s -o /dev/null -w "%{http_code}" "$KONG_ADMIN_URL/status")
  
  if [[ "$http_code" == "200" ]]; then
    success "Kong Admin API is responsive (HTTP $http_code)"
    return 0
  fi
  
  warning "Kong Admin API returned HTTP $http_code, not 200"
  
  # If direct access didn't work, try with curl-tools
  local curl_tools_container=$(docker ps --format '{{.Names}}' | grep -E 'dive25.*curl-tools|dive25-curl-tools' | head -n 1)
  
  if [ -n "$curl_tools_container" ]; then
    show_progress "Trying container-to-container access via curl-tools..."
    
    local container_response=$(docker exec "$curl_tools_container" curl -s "http://${kong_container}:8001/status")
    
    if [ -n "$container_response" ]; then
      success "Kong Admin API is accessible via container-to-container network"
      export KONG_ADMIN_URL="http://${kong_container}:8001"
      export KONG_ADMIN_ACCESS_METHOD="curl-tools"
      return 0
    fi
  fi
  
  # Final fallback - maybe direct localhost access is working but returned a non-200 code
  if curl -s "$KONG_ADMIN_URL/status" > /dev/null; then
    warning "Kong Admin API is reachable but returned a non-200 status code"
    return 0
  fi
  
  error "Kong Admin API is not accessible. Please check logs and network configuration."
  return 1
}

# Main function to orchestrate the deployment process
main() {
  # Display welcome message
  show_welcome
  
  # Start timer for execution time tracking
  start_timer
  
  # Check system requirements
  check_docker_requirements
  if [ $? -ne 0 ]; then
    error "System requirements not met. Exiting."
    exit 1
  fi
  
  # Select environment
  select_environment
  
  # Set default variables
  set_default_variables
  
  # Check for existing deployment and clean up if necessary
  # In test/fast mode, automatically clean up without prompting
  if [ "$TEST_MODE" = "true" ] || [ "$FAST_SETUP" = "true" ]; then
    info "Automatically cleaning existing deployment in test/fast mode"
    cleanup_docker_environment true true false
  else
    check_existing_deployment
  fi
  
  # Generate environment file from template if needed
  if [ -f "config/templates/env.template.$ENVIRONMENT.j2" ]; then
    print_step "Generating environment file for $ENV_DISPLAY"
    fix_template_files
    generate_env_file "config/templates/env.template.$ENVIRONMENT.j2" ".env" "$ENVIRONMENT"
  elif [ ! -f ".env" ]; then
    # If no environment file exists, create a minimal one
    print_step "Creating minimal environment file"
    echo "BASE_DOMAIN=dive25.local" > .env
    echo "ENVIRONMENT=$ENVIRONMENT" >> .env
    echo "FRONTEND_DOMAIN=frontend" >> .env
    echo "API_DOMAIN=api" >> .env
    echo "KEYCLOAK_DOMAIN=keycloak" >> .env
    echo "KONG_DOMAIN=kong" >> .env
    success "Created minimal environment file"
  fi
  
  # Load environment variables
  load_env_file ".env"
  
  # Set up host file entries for the domains
  if [ "$TEST_MODE" != "true" ]; then
    update_hosts_file "dive25.local" "frontend.dive25.local" "api.dive25.local" "keycloak.dive25.local" "kong.dive25.local"
  else
    info "Skipping hosts file update in test mode"
  fi
  
  # Set up certificates
  setup_certificates "dive25.local"
  
  # Start Docker services with reasonable timeout
  print_step "Starting Docker services"
  if [ "$TEST_MODE" = "true" ] || [ "$FAST_SETUP" = "true" ]; then
    info "Skipping Docker service startup in test/fast mode"
    # But we'll create a test container to help with verification
    if ! docker ps | grep -q "dive25.*curl-tools"; then
      info "Creating test container for verification"
      docker run -d --name "dive25-curl-tools" --network host alpine:latest sh -c "apk add --no-cache curl jq bash bind-tools ca-certificates && sleep 3600"
    fi
  else
    start_docker_services "docker-compose.yml" ".env"
    
    # Wait for services with a reasonable timeout
    local timeout=120
    if [ "$FAST_SETUP" = "true" ]; then
      timeout=30
    fi
    check_compose_health 16 "" $timeout
  fi
  
  # In a real deployment, continue with other setup tasks
  if [ "$TEST_MODE" != "true" ] && [ "$FAST_SETUP" != "true" ]; then
    # Distribute CA trust to containers
    print_step "Distributing CA Trust to Running Containers"
    
    # Get a list of actual running containers
    local running_containers=$(docker ps --format '{{.Names}}' | grep "dive25")
    
    if [ -n "$running_containers" ]; then
      info "Detected running containers: $running_containers"
      
      # Extract service names from container names (remove the dive25- prefix)
      local services=""
      for container in $running_containers; do
        # Extract service name (remove environment prefix like dive25-staging-)
        local service=$(echo $container | sed -E 's/dive25-([^-]+-)?(.*)/\2/')
        services="$services $service"
      done
      
      info "Distributing CA trust to services: $services"
      # Continue even if CA trust distribution fails
      distribute_ca_trust "$services" || warning "CA trust distribution had some issues but continuing with deployment"
    else
      warning "No running containers found for CA trust distribution"
    fi
    
    # Ensure Kong Admin API is ready before configuring Kong
    ensure_kong_admin_api
    
    # Configure Kong gateway
    wait_for_kong
    reset_kong_dns
    configure_keycloak_routes
    configure_api_routes
    configure_frontend_routes
    configure_base_domain_routes
    configure_oidc_plugin
    
    # Wait for Keycloak to be ready
    wait_for_keycloak
    
    # Update Keycloak configuration
    update_keycloak_client_config
    fix_identity_providers
    
    # Check DNS resolution between containers
    check_dns_resolution
    
    # Verify connectivity
    check_docker_network
    
    # Final health check
    check_all_services_health
  else
    info "Skipping setup steps in test/fast mode"
  fi
  
  # Display summary
  print_header "Deployment Summary"
  echo -e "${GREEN}${BOLD}${EMOJI_SPARKLES} DIVE25 Authentication System Setup Complete! ${EMOJI_SPARKLES}${RESET}"
  echo
  echo -e "${BLUE}All services have been configured and are ready to use.${RESET}"
  echo
  
  # Calculate and display elapsed time
  local end_time=$(date +%s)
  local duration=$((end_time - START_TIME))
  print_elapsed_time $duration
  
  return 0
}

# Function to wait for Kong to become healthy
wait_for_kong() {
  print_step "Waiting for Kong Admin API"
  show_progress "Checking Kong Admin API readiness..."
  
  # If we're in test mode, skip the actual check
  if [ "$TEST_MODE" = "true" ] || [ "$FAST_SETUP" = "true" ]; then
    info "Test/fast mode enabled - skipping Kong readiness check"
    return 0
  fi
  
  local retry=0
  while [ $retry -lt $MAX_RETRIES ]; do
    if curl -s -o /dev/null -w "%{http_code}" "$KONG_ADMIN_URL" | grep -q "200"; then
      success "Kong Admin API is ready"
      return 0
    fi
    retry=$((retry+1))
    echo "Attempt $retry/$MAX_RETRIES: Kong Admin API not ready yet, waiting $RETRY_INTERVAL seconds..."
    sleep $RETRY_INTERVAL
    
    # If we've been waiting for more than 2 minutes, give up
    if [ $retry -gt 24 ]; then # 24 * 5 seconds = 2 minutes
      warning "Kong Admin API did not become ready after 2 minutes, continuing anyway"
      return 0
    fi
  done
  
  warning "Kong Admin API did not become ready after $MAX_RETRIES attempts, continuing anyway"
  return 0
}

# Check and wait for Keycloak readiness
wait_for_keycloak() {
  print_step "Waiting for Keycloak"
  
  # If we're in test mode, skip the actual check
  if [ "$TEST_MODE" = "true" ] || [ "$FAST_SETUP" = "true" ]; then
    info "Test/fast mode enabled - skipping Keycloak readiness check"
    return 0
  fi
  
  # Get variables from environment or defaults
  local internal_keycloak_url=${INTERNAL_KEYCLOAK_URL:-"http://keycloak:8080"}
  local keycloak_realm=${KEYCLOAK_REALM:-"dive25"}
  local max_retries=${1:-20}
  local retry_interval=${2:-5}
  
  show_progress "Checking if Keycloak is ready..."
  
  # First check the marker file
  if [ -f "/tmp/keycloak-config/realm-ready" ]; then
    success "Found realm marker file"
    return 0
  fi
  
  # Then try direct check with Keycloak
  local retry=0
  while [ $retry -lt $max_retries ]; do
    local status_code=$(curl -s -o /dev/null -w "%{http_code}" "${internal_keycloak_url}/realms/${keycloak_realm}")
    
    if [ "$status_code" == "200" ]; then
      success "Keycloak realm ${keycloak_realm} is accessible"
      # Create marker file for future reference
      mkdir -p /tmp/keycloak-config
      echo "${keycloak_realm}" > /tmp/keycloak-config/realm-ready
      return 0
    fi
    
    retry=$((retry+1))
    echo "Attempt $retry/$max_retries: Keycloak realm not ready yet, waiting $retry_interval seconds..."
    sleep $retry_interval
    
    # If we've been waiting for more than 2 minutes, give up
    if [ $retry -gt 24 ]; then # 24 * 5 seconds = 2 minutes
      warning "Keycloak did not become ready after 2 minutes, continuing anyway"
      return 0
    fi
  done
  
  warning "Could not verify Keycloak realm readiness after $max_retries attempts, continuing anyway"
  return 0
}

# Execute main function
main "$@"
exit $? 