#!/bin/bash
# DIVE25 Troubleshooting and Repair Script

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Import required utility functions
source "$SCRIPT_DIR/utils/logging.sh"
source "$SCRIPT_DIR/utils/system.sh"
source "$SCRIPT_DIR/utils/config.sh"

# Import specific modules
source "$SCRIPT_DIR/certificates/cert-manager.sh"
source "$SCRIPT_DIR/network/network-utils.sh"
source "$SCRIPT_DIR/verification/health-checks.sh"
source "$SCRIPT_DIR/kong/kong-setup.sh"
source "$SCRIPT_DIR/keycloak/keycloak-setup.sh"

# Display the troubleshooter header
print_header "DIVE25 Troubleshooter and Repair Tool"
echo -e "${BLUE}This tool will check and fix common issues with your DIVE25 setup.${RESET}"
echo

# Check if running with sufficient permissions
check_permissions() {
  print_step "Checking Permissions"
  
  # Check for Docker access
  if ! docker ps &>/dev/null; then
    warning "Cannot access Docker. Make sure Docker is running and you have permissions to use it."
    warning "You might need to run this script with sudo or add your user to the docker group."
    warning "To add user to docker group: sudo usermod -aG docker $USER"
    return 1
  fi
  
  # Check for file access
  if [ ! -w "$ROOT_DIR" ]; then
    warning "Cannot write to $ROOT_DIR directory."
    warning "You might need to run this script with sudo or fix permissions."
    return 1
  fi
  
  success "You have sufficient permissions to run this tool."
  return 0
}

# Check Docker environment
check_docker_environment() {
  print_step "Checking Docker Environment"
  
  # Check if Docker is running
  if ! docker info &>/dev/null; then
    error "Docker is not running. Please start Docker and try again."
    return 1
  fi
  
  # Check for running containers
  local container_count=$(docker ps --format '{{.Names}}' | grep -c "dive25")
  
  if [ "$container_count" -eq 0 ]; then
    warning "No DIVE25 containers are currently running."
    ask_to_start_containers
    return 1
  fi
  
  info "Found $container_count running DIVE25 containers."
  
  # Check container health
  local unhealthy_count=$(docker ps --format '{{.Names}}{{.Status}}' | grep "dive25" | grep -c "unhealthy")
  if [ "$unhealthy_count" -gt 0 ]; then
    warning "Found $unhealthy_count unhealthy containers."
    show_unhealthy_containers
    offer_to_restart_unhealthy
  else
    success "All running containers are healthy."
  fi
  
  return 0
}

# Show unhealthy containers
show_unhealthy_containers() {
  echo -e "\n${YELLOW}Unhealthy containers:${RESET}"
  docker ps --format '{{.Names}}\t{{.Status}}' | grep "dive25" | grep "unhealthy"
  echo
}

# Offer to restart unhealthy containers
offer_to_restart_unhealthy() {
  read -p "Would you like to restart unhealthy containers? (y/n): " restart_choice
  if [[ "$restart_choice" == "y" || "$restart_choice" == "Y" ]]; then
    docker ps --format '{{.Names}}' | grep "dive25" | grep "unhealthy" | xargs docker restart
    success "Restarted unhealthy containers. Waiting for them to stabilize..."
    sleep 10
    
    local still_unhealthy=$(docker ps --format '{{.Names}}{{.Status}}' | grep "dive25" | grep -c "unhealthy")
    if [ "$still_unhealthy" -gt 0 ]; then
      warning "Some containers are still unhealthy. You may need to check their logs."
    else
      success "All containers are now healthy."
    fi
  fi
}

# Ask to start containers if none are running
ask_to_start_containers() {
  if [ -f "$ROOT_DIR/docker-compose.yml" ]; then
    read -p "Would you like to start the DIVE25 containers? (y/n): " start_choice
    if [[ "$start_choice" == "y" || "$start_choice" == "Y" ]]; then
      info "Starting DIVE25 containers..."
      docker-compose -f "$ROOT_DIR/docker-compose.yml" up -d
      success "Containers started. Please wait a few moments for them to initialize."
    fi
  else
    warning "docker-compose.yml not found in $ROOT_DIR. Cannot start containers automatically."
  fi
}

# Check certificate issues
check_certificate_issues() {
  print_step "Checking Certificate Issues"
  
  if [ ! -d "$ROOT_DIR/certs" ]; then
    warning "Certificate directory not found at $ROOT_DIR/certs"
    offer_to_regenerate_certs
    return 1
  fi
  
  # Check for required certificate files
  if [ ! -f "$ROOT_DIR/certs/rootCA.pem" ] || [ ! -f "$ROOT_DIR/certs/cert.pem" ] || [ ! -f "$ROOT_DIR/certs/key.pem" ]; then
    warning "Missing one or more required certificate files."
    offer_to_regenerate_certs
    return 1
  fi
  
  # Check certificate validity
  local cert_end_date=$(openssl x509 -enddate -noout -in "$ROOT_DIR/certs/cert.pem" | cut -d= -f2)
  local now=$(date)
  local expiry_date=$(date -d "$not_after" '+%Y-%m-%d' 2>/dev/null || date -j -f "%b %d %H:%M:%S %Y %Z" "$cert_end_date" "+%Y-%m-%d" 2>/dev/null)
  local current_date=$(date '+%Y-%m-%d')
  
  # Try to calculate days until expiration (platform independent)
  days_until_expiry=-1
  if command -v python3 >/dev/null 2>&1; then
    days_until_expiry=$(python3 -c "from datetime import datetime; d1 = datetime.strptime('$expiry_date', '%Y-%m-%d'); d2 = datetime.strptime('$current_date', '%Y-%m-%d'); print((d1 - d2).days)" 2>/dev/null || echo -1)
  fi
  
  if [ "$days_until_expiry" -lt 0 ]; then
    warning "Certificate may be expired or date calculation failed."
    offer_to_regenerate_certs
  elif [ "$days_until_expiry" -lt 30 ]; then
    warning "Certificate will expire in $days_until_expiry days."
    offer_to_regenerate_certs
  else
    success "Certificates appear to be valid (expires in $days_until_expiry days)."
    
    # Offer to redistribute CA trust
    local container_count=$(docker ps --format '{{.Names}}' | grep -c "dive25")
    if [ "$container_count" -gt 0 ]; then
      read -p "Would you like to redistribute CA trust to all containers? (y/n): " redistribute_choice
      if [[ "$redistribute_choice" == "y" || "$redistribute_choice" == "Y" ]]; then
        distribute_ca_trust
      fi
    fi
  fi
  
  return 0
}

# Offer to regenerate certificates
offer_to_regenerate_certs() {
  read -p "Would you like to regenerate certificates? (y/n): " regen_choice
  if [[ "$regen_choice" == "y" || "$regen_choice" == "Y" ]]; then
    # Get base domain
    local base_domain=$(get_env_value "BASE_DOMAIN" "$ROOT_DIR/.env" "dive25.local")
    
    # Regenerate certificates
    setup_certificates "$base_domain" "" "true"
    
    # Offer to redistribute CA trust if successful
    if [ $? -eq 0 ]; then
      local container_count=$(docker ps --format '{{.Names}}' | grep -c "dive25")
      if [ "$container_count" -gt 0 ]; then
        read -p "Would you like to redistribute CA trust to all containers? (y/n): " redistribute_choice
        if [[ "$redistribute_choice" == "y" || "$redistribute_choice" == "Y" ]]; then
          distribute_ca_trust
        fi
      fi
    fi
  fi
}

# Check network connectivity issues
check_network_issues() {
  print_step "Checking Network Connectivity"
  
  # Basic network check
  if ! ping -c 1 1.1.1.1 &>/dev/null; then
    warning "Cannot reach internet. Check your network connection."
  fi
  
  # Docker network check
  local dive_networks=$(docker network ls --format '{{.Name}}' | grep -c "dive25")
  if [ "$dive_networks" -eq 0 ]; then
    warning "No DIVE25 Docker networks found."
    return 1
  fi
  
  info "Found $dive_networks DIVE25 Docker networks."
  
  # Check DNS resolution between containers
  local container_count=$(docker ps --format '{{.Names}}' | grep -c "dive25")
  if [ "$container_count" -gt 0 ]; then
    # Find a container to use for testing
    local curl_tools=$(docker ps --format '{{.Names}}' | grep "dive25.*curl-tools" | head -n 1)
    
    if [ -z "$curl_tools" ]; then
      warning "No curl-tools container found. Creating one for DNS tests..."
      docker run -d --name "dive25-curl-tools" --network host alpine:latest sh -c "apk add --no-cache curl bind-tools && tail -f /dev/null"
      curl_tools="dive25-curl-tools"
    fi
    
    # Test DNS resolution between key services
    local key_services=("keycloak" "kong" "api" "frontend")
    local resolved_count=0
    
    for service in "${key_services[@]}"; do
      if docker exec "$curl_tools" nslookup "$service" &>/dev/null; then
        success "DNS resolution successful: $service"
        resolved_count=$((resolved_count+1))
      else
        warning "DNS resolution failed: $service"
      fi
    done
    
    if [ "$resolved_count" -lt "${#key_services[@]}" ]; then
      warning "Some DNS resolutions failed. Consider restarting Docker or checking your network config."
      offer_to_fix_dns
    else
      success "DNS resolution is working properly for all key services."
    fi
  fi
  
  return 0
}

# Offer to fix DNS issues
offer_to_fix_dns() {
  read -p "Would you like to attempt to fix DNS issues? (y/n): " fix_dns_choice
  if [[ "$fix_dns_choice" == "y" || "$fix_dns_choice" == "Y" ]]; then
    local fix_method
    echo -e "\nChoose a fix method:"
    echo "1. Restart Docker containers (preserves data)"
    echo "2. Restart Docker service (may require root/sudo)"
    echo "3. Add manual /etc/hosts entries"
    read -p "Enter choice [1-3]: " fix_method
    
    case $fix_method in
      1)
        docker-compose -f "$ROOT_DIR/docker-compose.yml" restart
        success "Restarted Docker containers."
        ;;
      2)
        sudo systemctl restart docker || sudo service docker restart || docker restart
        success "Restarted Docker service."
        ;;
      3)
        update_hosts_file_automation
        ;;
      *)
        warning "Invalid choice."
        ;;
    esac
  fi
}

# Update hosts file with automatic IP detection
update_hosts_file_automation() {
  info "Detecting container IPs for host file entries..."
  
  local base_domain=$(get_env_value "BASE_DOMAIN" "$ROOT_DIR/.env" "dive25.local")
  local host_entries=()
  local key_services=("keycloak" "kong" "api" "frontend")
  
  for service in "${key_services[@]}"; do
    local container=$(docker ps --format '{{.Names}}' | grep "dive25.*$service" | head -n 1)
    if [ -n "$container" ]; then
      local ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$container")
      if [ -n "$ip" ]; then
        host_entries+=("$ip $service.$base_domain $service")
      fi
    fi
  done
  
  if [ ${#host_entries[@]} -eq 0 ]; then
    warning "Could not detect any container IPs."
    return 1
  fi
  
  echo -e "\nThe following entries will be added to /etc/hosts:"
  for entry in "${host_entries[@]}"; do
    echo "$entry"
  done
  
  read -p "Proceed with updating hosts file? (y/n): " update_hosts_choice
  if [[ "$update_hosts_choice" == "y" || "$update_hosts_choice" == "Y" ]]; then
    for entry in "${host_entries[@]}"; do
      sudo sh -c "echo '$entry' >> /etc/hosts"
    done
    success "Updated /etc/hosts file with container IPs."
  fi
}

# Check and repair Kong setup
check_kong_setup() {
  print_step "Checking Kong API Gateway Setup"
  
  # Check if Kong container is running
  local kong_container=$(docker ps --format '{{.Names}}' | grep "dive25.*kong" | grep -v "config\|database\|konga" | head -n 1)
  
  if [ -z "$kong_container" ]; then
    warning "Kong container is not running."
    return 1
  fi
  
  # Check Kong health
  if ! docker exec $kong_container kong health &>/dev/null; then
    warning "Kong service is not healthy."
    offer_to_repair_kong
    return 1
  else
    info "Kong service is healthy."
  fi
  
  # Check if Kong Admin API is accessible
  if ! curl -s http://localhost:8001 &>/dev/null && ! curl -s http://localhost:9444 &>/dev/null; then
    warning "Kong Admin API is not accessible."
    offer_to_repair_kong
    return 1
  else
    success "Kong Admin API is accessible."
  fi
  
  # Offer to reconfigure Kong routes
  read -p "Would you like to reconfigure Kong routes and services? (y/n): " reconfig_choice
  if [[ "$reconfig_choice" == "y" || "$reconfig_choice" == "Y" ]]; then
    repair_kong_config
  fi
  
  return 0
}

# Offer to repair Kong
offer_to_repair_kong() {
  read -p "Would you like to attempt to repair Kong? (y/n): " repair_choice
  if [[ "$repair_choice" == "y" || "$repair_choice" == "Y" ]]; then
    local kong_container=$(docker ps --format '{{.Names}}' | grep "dive25.*kong" | grep -v "config\|database\|konga" | head -n 1)
    
    if [ -n "$kong_container" ]; then
      docker restart "$kong_container"
      success "Restarted Kong container."
      sleep 10
      
      if docker exec $kong_container kong health &>/dev/null; then
        success "Kong service is now healthy."
      else
        warning "Kong service is still not healthy after restart."
      fi
    fi
  fi
}

# Check and repair Keycloak setup
check_keycloak_setup() {
  print_step "Checking Keycloak Setup"
  
  # Check if Keycloak container is running
  local keycloak_container=$(docker ps --format '{{.Names}}' | grep "dive25.*keycloak" | grep -v "config" | head -n 1)
  
  if [ -z "$keycloak_container" ]; then
    warning "Keycloak container is not running."
    return 1
  fi
  
  # Check if Keycloak is accessible
  local keycloak_realm="dive25"
  local internal_keycloak_url="http://keycloak:8080"
  local keycloak_access=false
  
  # Try direct access
  if curl -s http://localhost:8444/admin &>/dev/null; then
    success "Keycloak Admin UI is accessible via localhost:8444"
    keycloak_access=true
  fi
  
  # Try using curl-tools container
  local curl_tools=$(docker ps --format '{{.Names}}' | grep "dive25.*curl-tools" | head -n 1)
  if [ -n "$curl_tools" ]; then
    if docker exec "$curl_tools" curl -s "http://${keycloak_container}:8080/admin" &>/dev/null; then
      success "Keycloak Admin UI is accessible via container network"
      keycloak_access=true
    fi
  fi
  
  if [ "$keycloak_access" = false ]; then
    warning "Cannot access Keycloak admin interface."
    offer_to_repair_keycloak
    return 1
  fi
  
  # Check for realm
  local realm_check=false
  
  if [ -n "$curl_tools" ]; then
    if docker exec "$curl_tools" curl -s "${internal_keycloak_url}/realms/${keycloak_realm}" &>/dev/null; then
      success "Keycloak realm $keycloak_realm is accessible"
      realm_check=true
    fi
  fi
  
  if [ "$realm_check" = false ]; then
    warning "Keycloak realm $keycloak_realm may not be properly configured."
    offer_to_repair_keycloak
    return 1
  fi
  
  success "Keycloak setup appears to be functioning properly."
  return 0
}

# Offer to repair Keycloak
offer_to_repair_keycloak() {
  read -p "Would you like to attempt to repair Keycloak? (y/n): " repair_choice
  if [[ "$repair_choice" == "y" || "$repair_choice" == "Y" ]]; then
    local keycloak_container=$(docker ps --format '{{.Names}}' | grep "dive25.*keycloak" | grep -v "config" | head -n 1)
    
    if [ -n "$keycloak_container" ]; then
      docker restart "$keycloak_container"
      success "Restarted Keycloak container."
      sleep 15
      
      # Run Keycloak configuration container
      local keycloak_config_container=$(docker ps -a --format '{{.Names}}' | grep "dive25.*keycloak-config" | head -n 1)
      
      if [ -n "$keycloak_config_container" ]; then
        docker start "$keycloak_config_container"
        success "Started Keycloak configuration container."
        info "This container will configure the Keycloak realm and exit when complete."
        info "This may take a minute or two."
      else
        warning "Keycloak configuration container not found."
      fi
    fi
  fi
}

# Perform comprehensive health check
run_comprehensive_health_check() {
  print_step "Running Comprehensive Health Check"
  
  # Run the health check
  check_all_services_health
  
  # Return the result
  return $?
}

# Check environment variables
check_environment_variables() {
  print_step "Checking Environment Variables"
  
  local env_file="$ROOT_DIR/.env"
  
  if [ ! -f "$env_file" ]; then
    warning "Environment file not found at $env_file"
    offer_to_create_env_file
    return 1
  fi
  
  # Load environment file
  load_env_file "$env_file"
  
  # Check mandatory variables
  local missing_vars=0
  local essential_vars=(
    "BASE_DOMAIN"
    "ENVIRONMENT"
    "FRONTEND_DOMAIN"
    "API_DOMAIN"
    "KEYCLOAK_DOMAIN"
    "KONG_DOMAIN"
    "KEYCLOAK_REALM"
    "KEYCLOAK_CLIENT_ID_FRONTEND"
    "KEYCLOAK_CLIENT_ID_API"
  )
  
  for var in "${essential_vars[@]}"; do
    local value=$(get_env_value "$var" "$env_file" "")
    if [ -z "$value" ]; then
      warning "Missing essential environment variable: $var"
      missing_vars=$((missing_vars+1))
    else
      info "Found $var = $value"
    fi
  done
  
  if [ $missing_vars -gt 0 ]; then
    warning "Missing $missing_vars essential environment variables."
    offer_to_create_env_file
    return 1
  fi
  
  success "All essential environment variables are set."
  return 0
}

# Offer to create environment file
offer_to_create_env_file() {
  read -p "Would you like to create a basic environment file? (y/n): " create_env_choice
  if [[ "$create_env_choice" == "y" || "$create_env_choice" == "Y" ]]; then
    local env_file="$ROOT_DIR/.env"
    
    # Get base domain
    local base_domain="dive25.local"
    read -p "Enter base domain [$base_domain]: " input
    base_domain=${input:-$base_domain}
    
    # Create basic .env file
    cat > "$env_file" << EOF
# Basic environment file created by troubleshooter
BASE_DOMAIN=$base_domain
ENVIRONMENT=dev
FRONTEND_DOMAIN=frontend
API_DOMAIN=api
KEYCLOAK_DOMAIN=keycloak
KONG_DOMAIN=kong
KEYCLOAK_REALM=dive25
KEYCLOAK_CLIENT_ID_FRONTEND=dive25-frontend
KEYCLOAK_CLIENT_ID_API=dive25-api
KEYCLOAK_CLIENT_SECRET=change-me-in-production
FRONTEND_PORT=3001
API_PORT=3002
KEYCLOAK_PORT=8443
KEYCLOAK_INTERNAL_PORT=8080
KONG_PORT=8443
KONG_ADMIN_PORT=8001
KONG_ADMIN_HTTPS_PORT=9444
KEYCLOAK_AUTH_PATH=/auth
EOF
    
    success "Created basic environment file at $env_file"
    
    # Reload environment file
    load_env_file "$env_file"
  fi
}

# Interactive menu
show_menu() {
  echo -e "\n${BLUE}${BOLD}Main Menu${RESET}"
  echo "1. Check Docker Environment"
  echo "2. Check Certificate Issues"
  echo "3. Check Network Issues"
  echo "4. Check Kong Setup"
  echo "5. Check Keycloak Setup"
  echo "6. Check Environment Variables"
  echo "7. Run Comprehensive Health Check"
  echo "8. Run All Checks"
  echo "9. Exit"
  
  read -p "Enter your choice [1-9]: " choice
  
  case $choice in
    1) check_docker_environment ;;
    2) check_certificate_issues ;;
    3) check_network_issues ;;
    4) check_kong_setup ;;
    5) check_keycloak_setup ;;
    6) check_environment_variables ;;
    7) run_comprehensive_health_check ;;
    8) run_all_checks ;;
    9) exit 0 ;;
    *) warning "Invalid choice." ;;
  esac
  
  # Return to menu after action completes
  read -p "Press Enter to return to the main menu..."
  show_menu
}

# Run all checks
run_all_checks() {
  print_header "Running All Checks"
  
  check_permissions
  check_docker_environment
  check_certificate_issues
  check_network_issues
  check_kong_setup
  check_keycloak_setup
  check_environment_variables
  run_comprehensive_health_check
  
  print_header "All Checks Complete"
  
  return 0
}

# Run the main menu if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  check_permissions
  show_menu
fi 