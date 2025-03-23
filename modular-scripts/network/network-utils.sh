#!/bin/bash
# Network utility functions

# Import required utility functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/logging.sh"
source "$SCRIPT_DIR/../utils/system.sh"
source "$SCRIPT_DIR/../utils/config.sh"

# Function to check for and update hosts file entries
update_hosts_file() {
  local domains=("$@")
  local base_domain="${domains[0]}"
  
  print_header "Updating Hosts File"
  show_progress "Adding entries to /etc/hosts for $base_domain and subdomains..."
  
  # Skip hosts file modifications if in test mode
  if [ "$TEST_MODE" = "true" ]; then
    info "TEST_MODE is enabled - skipping hosts file modifications"
    success "Hosts file update would add entries for domains: ${domains[*]}"
    return 0
  fi
  
  # Determine the local IP address for loopback
  local ip_addr="127.0.0.1"
  
  # Check if we have permissions to modify /etc/hosts
  if [ ! -w "/etc/hosts" ]; then
    warning "You don't have permission to write to /etc/hosts"
    warning "The script will now use sudo to update the hosts file"
    
    # Check if sudo is available
    if ! command_exists sudo; then
      error "sudo is not available. Please manually update your hosts file."
      return 1
    fi
    
    # Generate a temporary file with all entries
    local temp_file=$(mktemp)
    echo "# DIVE25 - Added by setup script" > $temp_file
    
    for domain in "${domains[@]}"; do
      echo "$ip_addr    $domain" >> $temp_file
    done
    
    # Use sudo to append to hosts file
    echo "The following entries will be added to your hosts file:"
    cat $temp_file
    
    # In non-interactive mode, use default answers
    if [ "$FAST_SETUP" = "true" ]; then
      RESPONSE="y"
      info "Auto-accepting hosts file update in fast mode"
    else
      echo -e "\n${BOLD}${WHITE}========== USER INPUT REQUIRED ===========${RESET}"
      echo -en "${BOLD}${CYAN}>>> Do you want to update your hosts file with these entries? (y/n)${RESET} [y]: "
      read RESPONSE
      
      # Default to yes if empty
      if [ -z "$RESPONSE" ]; then
        RESPONSE="y"
      fi
    fi
    
    if [[ "$RESPONSE" != "n" && "$RESPONSE" != "N" ]]; then
      # First check if the marker already exists
      if sudo grep -q "# DIVE25 - Added by setup script" /etc/hosts; then
        # Remove existing DIVE25 entries
        show_progress "Removing existing DIVE25 entries..."
        sudo sed -i.bak '/# DIVE25 - Added by setup script/,/# End of DIVE25 entries/d' /etc/hosts
      fi
      
      # Add new entries
      show_progress "Adding new entries..."
      echo "# End of DIVE25 entries" >> $temp_file
      sudo bash -c "cat $temp_file >> /etc/hosts"
      
      # Verify the entries were added
      if sudo grep -q "# DIVE25 - Added by setup script" /etc/hosts; then
        success "Hosts file updated successfully"
        rm -f $temp_file
        return 0
      else
        error "Failed to update hosts file"
        rm -f $temp_file
        return 1
      fi
    else
      info "Skipping hosts file update as per user request"
      rm -f $temp_file
      return 0
    fi
  else
    # We have write permission, proceed directly
    # Check if the marker already exists
    if grep -q "# DIVE25 - Added by setup script" /etc/hosts; then
      # Remove existing DIVE25 entries
      show_progress "Removing existing DIVE25 entries..."
      sed -i.bak '/# DIVE25 - Added by setup script/,/# End of DIVE25 entries/d' /etc/hosts
    fi
    
    # Add new entries
    show_progress "Adding new entries..."
    echo "# DIVE25 - Added by setup script" >> /etc/hosts
    
    for domain in "${domains[@]}"; do
      echo "$ip_addr    $domain" >> /etc/hosts
    done
    
    echo "# End of DIVE25 entries" >> /etc/hosts
    
    # Verify the entries were added
    local missing_entries=0
    for domain in "${domains[@]}"; do
      if ! grep -q "$domain" /etc/hosts; then
        warning "Entry not found in hosts file: $domain"
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

# Function to check Docker network connectivity
check_docker_network() {
  print_step "Checking Docker Network Connectivity"
  
  # List of containers to check connectivity between
  local containers=(
    "frontend"
    "api"
    "keycloak"
    "kong"
    "mongodb"
    "postgres"
  )
  
  # Skip in test mode with a success message
  if [ "$TEST_MODE" = "true" ]; then
    info "TEST_MODE is enabled - skipping Docker network connectivity check"
    success "Docker network connectivity check would test: ${containers[*]}"
    return 0
  fi
  
  # Get the actual container names with prefix
  local container_names=()
  for container in "${containers[@]}"; do
    local name=$(docker ps --format '{{.Names}}' | grep "dive25.*$container" | head -n 1)
    if [ -n "$name" ]; then
      container_names+=("$name")
    fi
  done
  
  # Skip if no containers found
  if [ ${#container_names[@]} -eq 0 ]; then
    warning "No containers found to check network connectivity"
    return 1
  fi
  
  show_progress "Testing network connectivity between ${#container_names[@]} containers..."
  
  # Test connectivity between each pair
  local total_tests=0
  local successful_tests=0
  
  for ((i=0; i<${#container_names[@]}; i++)); do
    for ((j=0; j<${#container_names[@]}; j++)); do
      if [ $i -ne $j ]; then
        local source=${container_names[$i]}
        local target=${containers[$j]}  # Use service name, not container name
        
        # Increment test counter
        total_tests=$((total_tests+1))
        
        # Test ping from source to target
        if docker exec $source ping -c 1 $target >/dev/null 2>&1; then
          debug "$source -> $target: Ping successful"
          successful_tests=$((successful_tests+1))
        else
          warning "$source -> $target: Ping failed"
        fi
      fi
    done
  done
  
  # Report results
  if [ $successful_tests -eq $total_tests ]; then
    success "All network connectivity tests passed ($successful_tests/$total_tests)"
    return 0
  else
    warning "Some network connectivity tests failed ($(($total_tests-$successful_tests))/$total_tests failed)"
    
    # Suggest troubleshooting steps
    echo -e "\n${YELLOW}Troubleshooting suggestions:${RESET}"
    echo "1. Check Docker networks configuration in docker-compose.yml"
    echo "2. Make sure containers are in the same network"
    echo "3. Check if Docker DNS resolution is working"
    
    return 1
  fi
}

# Function to check container DNS resolution
check_dns_resolution() {
  print_step "Checking Container DNS Resolution"
  
  # Skip in test mode with a success message
  if [ "$TEST_MODE" = "true" ]; then
    info "TEST_MODE is enabled - skipping DNS resolution check"
    success "DNS resolution check would be skipped"
    return 0
  fi
  
  # Choose a container to test DNS resolution from
  local test_container=$(docker ps --format '{{.Names}}' | grep "dive25.*curl-tools" | head -n 1)
  
  if [ -z "$test_container" ]; then
    # Fallback to another container if curl-tools is not available
    test_container=$(docker ps --format '{{.Names}}' | grep "dive25" | head -n 1)
  fi
  
  if [ -z "$test_container" ]; then
    warning "No containers found to test DNS resolution"
    return 1
  fi
  
  show_progress "Testing DNS resolution from $test_container..."
  
  # Services to check
  local services=(
    "frontend"
    "api"
    "keycloak"
    "kong"
    "mongodb"
    "postgres"
  )
  
  local total_tests=0
  local successful_tests=0
  
  for service in "${services[@]}"; do
    # Increment test counter
    total_tests=$((total_tests+1))
    
    # Test DNS resolution
    if docker exec $test_container getent hosts $service >/dev/null 2>&1; then
      debug "$service: DNS resolution successful"
      successful_tests=$((successful_tests+1))
    else
      warning "$service: DNS resolution failed"
    fi
  done
  
  # Report results
  if [ $successful_tests -eq $total_tests ]; then
    success "All DNS resolution tests passed ($successful_tests/$total_tests)"
    return 0
  else
    warning "Some DNS resolution tests failed ($(($total_tests-$successful_tests))/$total_tests failed)"
    
    # Suggest troubleshooting steps
    echo -e "\n${YELLOW}Troubleshooting suggestions:${RESET}"
    echo "1. Make sure all containers are in the same Docker network"
    echo "2. Check if Docker DNS service is working"
    echo "3. Restart Docker daemon if persistent issues occur"
    
    return 1
  fi
}

# Function to update container /etc/hosts files
update_container_hosts() {
  print_step "Updating Container Hosts Files"
  
  # Skip in test mode with a success message
  if [ "$TEST_MODE" = "true" ]; then
    info "TEST_MODE is enabled - skipping container hosts update"
    success "Container hosts update would be skipped"
    return 0
  fi
  
  # List of containers to update
  local containers=$(docker ps --format '{{.Names}}' | grep "dive25")
  
  # Skip if no containers found
  if [ -z "$containers" ]; then
    warning "No containers found to update hosts files"
    return 1
  fi
  
  # Get services from docker-compose
  local services=$(docker-compose ps --services)
  
  # Create hosts entries
  local hosts_entries=""
  for service in $services; do
    # Get the IP address of the service
    local ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(docker ps --format '{{.Names}}' | grep "dive25.*$service" | head -n 1) 2>/dev/null)
    
    if [ -n "$ip" ]; then
      hosts_entries+="$ip $service\n"
    fi
  done
  
  if [ -z "$hosts_entries" ]; then
    warning "No service IP addresses found"
    return 1
  fi
  
  show_progress "Updating hosts files in ${#containers[@]} containers..."
  
  # Update each container's hosts file
  for container in $containers; do
    # Create a temporary hosts file
    local temp_file=$(mktemp)
    
    # Get current hosts file and strip out any existing entries
    docker exec $container cat /etc/hosts | grep -v "# Added by DIVE25 setup" > $temp_file
    
    # Add new entries
    echo -e "\n# Added by DIVE25 setup" >> $temp_file
    echo -e $hosts_entries >> $temp_file
    echo "# End of DIVE25 entries" >> $temp_file
    
    # Copy back to container
    docker cp $temp_file $container:/etc/hosts
    
    # Clean up
    rm -f $temp_file
    
    debug "Updated hosts file in $container"
  done
  
  success "Container hosts files updated successfully"
  return 0
}

# Main function to set up networking
main() {
  local base_domain="${1:-dive25.local}"
  local update_host_entry="${2:-true}"
  local domains=()
  
  # Build domain list
  if [ -f ".env" ]; then
    domains+=("$base_domain")
    domains+=("$(get_env_value "FRONTEND_DOMAIN" ".env" "frontend").$base_domain")
    domains+=("$(get_env_value "API_DOMAIN" ".env" "api").$base_domain")
    domains+=("$(get_env_value "KEYCLOAK_DOMAIN" ".env" "keycloak").$base_domain")
    domains+=("$(get_env_value "KONG_DOMAIN" ".env" "kong").$base_domain")
  else
    domains=(
      "$base_domain"
      "frontend.$base_domain"
      "api.$base_domain"
      "keycloak.$base_domain"
      "kong.$base_domain"
    )
  fi
  
  # Skip in test mode with success message
  if [ "$TEST_MODE" = "true" ]; then
    info "TEST_MODE is enabled - running in test mode"
    update_hosts_file "${domains[@]}"
    
    # Return early as we're in test mode
    return 0
  fi
  
  # Update hosts file entries if requested
  if [ "$update_host_entry" = "true" ]; then
    update_hosts_file "${domains[@]}"
  fi
  
  # Check Docker network connectivity
  check_docker_network
  
  # Check DNS resolution
  check_dns_resolution
  
  # Update container hosts files if needed
  # Commented out as this is usually not necessary with Docker's built-in DNS
  # update_container_hosts
  
  success "Network setup completed successfully"
  return 0
}

# Execute main function if script is run directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi 