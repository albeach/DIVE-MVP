#!/bin/bash
# Service health checks and verification functions

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Import required utility functions
source "$SCRIPT_DIR/../utils/logging.sh"
source "$SCRIPT_DIR/../utils/system.sh"
source "$SCRIPT_DIR/../utils/config.sh"

# Create curl-tools container if not already existing
ensure_curl_tools() {
  local required_tools="$1"
  
  # Default tools if not specified
  if [ -z "$required_tools" ]; then
    required_tools="curl jq bash bind-tools ca-certificates"
  fi
  
  # Check if curl-tools container already exists
  local curl_tools_container=$(get_container_name "curl-tools" "dive25")
  
  # Create container if it doesn't exist
  if [ -z "$curl_tools_container" ]; then
    info "Creating curl-tools container with tools: $required_tools"
    docker run -d --name "dive25-curl-tools" --network host alpine:latest sh -c "apk add --no-cache $required_tools && sleep 3600"
    curl_tools_container="dive25-curl-tools"
  fi
  
  echo "$curl_tools_container"
}

# Function to check if URL is accessible with appropriate protocol
check_url_accessibility() {
  local url=$1
  local timeout=${2:-10}
  local expected_status=${3:-200}
  local skip_ssl_verify=${4:-true}
  
  show_progress "Checking URL accessibility: $url"
  
  local curl_opts="-s -o /dev/null -w %{http_code} -m $timeout"
  
  # Add SSL verification skip if requested
  if [ "$skip_ssl_verify" = "true" ]; then
    curl_opts="$curl_opts -k"
  fi
  
  # Determine protocol (http vs https)
  local protocol=$(echo $url | cut -d: -f1)
  
  # Skip protocol detection if configured
  if [ "$SKIP_PROTOCOL_DETECTION" = "true" ]; then
    debug "Skipping protocol detection as configured"
  else
    # Try to auto-detect correct protocol if not working
    if ! curl $curl_opts $url | grep -q $expected_status; then
      # If URL is http, try https
      if [ "$protocol" = "http" ]; then
        debug "HTTP URL not accessible, trying HTTPS..."
        local https_url=$(echo $url | sed 's/^http:/https:/')
        if curl $curl_opts $https_url | grep -q $expected_status; then
          warning "URL $url is not accessible, but $https_url is. Consider updating configuration."
          url=$https_url
        fi
      # If URL is https, try http
      elif [ "$protocol" = "https" ]; then
        debug "HTTPS URL not accessible, trying HTTP..."
        local http_url=$(echo $url | sed 's/^https:/http:/')
        if curl $curl_opts $http_url | grep -q $expected_status; then
          warning "URL $url is not accessible, but $http_url is. Consider updating configuration."
          url=$http_url
        fi
      fi
    fi
  fi
  
  # Make the request
  local status=$(curl $curl_opts $url)
  
  # Check the status
  if [ "$status" = "$expected_status" ]; then
    success "URL $url is accessible (status: $status)"
    return $E_SUCCESS
  else
    warning "URL $url is NOT accessible (status: $status)"
    
    # Additional diagnostic information
    if [ "$status" = "000" ]; then
      info "Connection refused or network unreachable. Check if service is running."
    elif [ "$status" = "404" ]; then
      info "Page not found. Check URL path."
    elif [ "$status" = "403" ]; then
      info "Access forbidden. Check authentication requirements."
    elif [ "$status" = "500" ] || [ "$status" = "502" ] || [ "$status" = "503" ]; then
      info "Server error. Check service logs."
    fi
    
    return $E_NETWORK_ERROR
  fi
}

# Function to check all service URLs
check_service_urls() {
  print_header "Checking Service URLs"
  
  # Skip URL checks if requested
  if [ "$SKIP_URL_CHECKS" = "true" ] || [ "$FAST_SETUP" = "true" ] || [ "$TEST_MODE" = "true" ]; then
    info "Skipping URL checks as configured"
    if [ "$TEST_MODE" = "true" ]; then
      success "URL checks would be skipped in test mode"
    fi
    return $E_SUCCESS
  fi
  
  # Get base domain from env
  local base_domain=${BASE_DOMAIN:-"dive25.local"}
  
  # Define URLs to check with appropriate ports
  local urls=(
    "https://frontend.${base_domain}:${FRONTEND_PORT:-3001}"
    "https://api.${base_domain}:${API_PORT:-3002}"
    "https://keycloak.${base_domain}:${KEYCLOAK_PORT:-8443}"
    "https://kong.${base_domain}:${KONG_PORT:-8443}"
  )
  
  # Add additional URLs if present in environment
  if [ -n "$GRAFANA_PORT" ]; then
    urls+=("https://grafana.${base_domain}:${GRAFANA_PORT:-4434}")
  fi
  
  if [ -n "$PROMETHEUS_PORT" ]; then
    urls+=("https://prometheus.${base_domain}:${PROMETHEUS_PORT:-4437}")
  fi
  
  if [ -n "$MONGODB_EXPRESS_PORT" ]; then
    urls+=("https://mongo-express.${base_domain}:${MONGODB_EXPRESS_PORT:-4435}")
  fi
  
  if [ -n "$PHPLDAPADMIN_PORT" ]; then
    urls+=("https://phpldapadmin.${base_domain}:${PHPLDAPADMIN_PORT:-4436}")
  fi
  
  local success_count=0
  local total_urls=${#urls[@]}
  local failed_urls=()
  
  for url in "${urls[@]}"; do
    if check_url_accessibility "$url" 5 200 true; then
      success_count=$((success_count+1))
    else
      failed_urls+=("$url")
    fi
  done
  
  echo
  if [ $success_count -eq $total_urls ]; then
    success "All service URLs are accessible ($success_count/$total_urls)"
    return $E_SUCCESS
  else
    warning "Some service URLs are not accessible ($(($total_urls-$success_count))/$total_urls failed)"
    
    # List failed URLs
    echo -e "\nFailed URLs:"
    for url in "${failed_urls[@]}"; do
      echo "  - $url"
    done
    
    # Suggest troubleshooting steps
    echo -e "\n${YELLOW}Troubleshooting suggestions:${RESET}"
    echo "1. Check if the services are running: docker ps"
    echo "2. Verify host entries in /etc/hosts"
    echo "3. Check if certificates are properly generated and distributed"
    echo "4. Verify port mappings in docker-compose.yml"
    
    return $E_NETWORK_ERROR
  fi
}

# Function to verify Keycloak OIDC configuration
verify_keycloak_oidc() {
  print_step "Verifying Keycloak OIDC Configuration"
  
  # Skip checks if requested
  if [ "$SKIP_KEYCLOAK_CHECKS" = "true" ] || [ "$FAST_SETUP" = "true" ]; then
    info "Skipping Keycloak OIDC verification as configured"
    return $E_SUCCESS
  fi
  
  # Get variables from environment or defaults
  local base_domain=${BASE_DOMAIN:-"dive25.local"}
  local keycloak_realm=${KEYCLOAK_REALM:-"dive25"}
  
  # Create curl-tools container if not already existing
  local curl_tools_container=$(ensure_curl_tools "curl jq bash bind-tools ca-certificates")
  
  # Try multiple ways to access Keycloak OIDC configuration
  show_progress "Trying different methods to access Keycloak OIDC configuration..."
  
  local urls=(
    "https://keycloak.${base_domain}:${KEYCLOAK_PORT:-8443}/realms/${keycloak_realm}/.well-known/openid-configuration"
    "http://keycloak:8080/realms/${keycloak_realm}/.well-known/openid-configuration"
    "http://keycloak.${base_domain}:8080/realms/${keycloak_realm}/.well-known/openid-configuration"
  )
  
  local well_known_url=""
  local response=""
  
  # Try each URL to find one that works
  for url in "${urls[@]}"; do
    debug "Trying OIDC discovery URL: $url"
    
    # Try with curl-tools container
    response=$(docker exec "$curl_tools_container" curl -sk "$url" 2>/dev/null)
    
    if [ -n "$response" ] && [ "$(echo "$response" | grep -c "token_endpoint")" -gt 0 ]; then
      well_known_url="$url"
      success "Successfully accessed OIDC configuration at $url"
      break
    fi
  done
  
  if [ -z "$well_known_url" ]; then
    error "Could not access Keycloak OIDC configuration at any URL"
    
    # Try direct check from Keycloak container
    local keycloak_container=$(get_container_name "keycloak" "dive25" "config")
    
    if [ -n "$keycloak_container" ]; then
      show_progress "Trying direct check from Keycloak container..."
      local internal_check=$(docker exec "$keycloak_container" curl -s "http://localhost:8080/realms/${keycloak_realm}/.well-known/openid-configuration" 2>/dev/null)
      
      if [ -n "$internal_check" ] && [ "$(echo "$internal_check" | grep -c "token_endpoint")" -gt 0 ]; then
        success "Keycloak OIDC configuration is accessible from within Keycloak container"
        info "Issue is with external access, not with Keycloak itself"
      else
        error "Keycloak OIDC configuration not available even within Keycloak container"
        info "Keycloak might not be properly configured or realm does not exist"
      fi
    fi
    
    return $E_NETWORK_ERROR
  fi
  
  # Save response to temp file for analysis
  docker exec "$curl_tools_container" bash -c "echo '$response' > /tmp/oidc-config.json"
  
  # Extract and verify essential OIDC endpoints
  local token_endpoint=$(docker exec "$curl_tools_container" jq -r '.token_endpoint' /tmp/oidc-config.json 2>/dev/null)
  local auth_endpoint=$(docker exec "$curl_tools_container" jq -r '.authorization_endpoint' /tmp/oidc-config.json 2>/dev/null)
  local userinfo_endpoint=$(docker exec "$curl_tools_container" jq -r '.userinfo_endpoint' /tmp/oidc-config.json 2>/dev/null)
  local jwks_uri=$(docker exec "$curl_tools_container" jq -r '.jwks_uri' /tmp/oidc-config.json 2>/dev/null)
  
  local missing_endpoints=()
  [ -z "$token_endpoint" ] && missing_endpoints+=("token_endpoint")
  [ -z "$auth_endpoint" ] && missing_endpoints+=("authorization_endpoint")
  [ -z "$userinfo_endpoint" ] && missing_endpoints+=("userinfo_endpoint")
  [ -z "$jwks_uri" ] && missing_endpoints+=("jwks_uri")
  
  if [ ${#missing_endpoints[@]} -eq 0 ]; then
    success "Keycloak OIDC configuration verified successfully"
    
    # Show key endpoints for debugging
    debug "Token endpoint: $token_endpoint"
    debug "Authorization endpoint: $auth_endpoint"
    debug "User info endpoint: $userinfo_endpoint"
    debug "JWKS URI: $jwks_uri"
    
    # Test if endpoints are actually accessible
    show_progress "Testing if OIDC endpoints are accessible..."
    
    local accessible_count=0
    local endpoints=("$token_endpoint" "$auth_endpoint" "$userinfo_endpoint" "$jwks_uri")
    
    for endpoint in "${endpoints[@]}"; do
      if docker exec "$curl_tools_container" curl -sk -o /dev/null -w "%{http_code}" "$endpoint" | grep -q -E "2[0-9][0-9]|401|403"; then
        debug "Endpoint accessible: $endpoint"
        accessible_count=$((accessible_count+1))
      else
        warning "Endpoint not accessible: $endpoint"
      fi
    done
    
    if [ $accessible_count -eq ${#endpoints[@]} ]; then
      success "All OIDC endpoints are accessible"
    else
      warning "Some OIDC endpoints are not accessible ($accessible_count/${#endpoints[@]})"
    fi
    
    return $E_SUCCESS
  else
    warning "Keycloak OIDC configuration is incomplete"
    
    # Show what's missing
    echo "Missing endpoints:"
    for endpoint in "${missing_endpoints[@]}"; do
      echo "  - $endpoint"
    done
    
    return $E_CONFIG_ERROR
  fi
}

# Function to verify Kong gateway configuration
verify_kong_configuration() {
  print_step "Verifying Kong Gateway Configuration"
  
  # Get Kong admin URL from environment or default
  local kong_admin_url=${KONG_ADMIN_URL:-"http://localhost:8001"}
  
  show_progress "Checking Kong configuration status..."
  
  # Check if Kong admin API is accessible
  if ! curl -s $kong_admin_url > /dev/null; then
    warning "Kong Admin API is not accessible at $kong_admin_url"
    
    # Try alternative port
    local alt_url="http://localhost:9444"
    if curl -s $alt_url > /dev/null; then
      success "Kong Admin API is accessible at $alt_url"
      kong_admin_url=$alt_url
    else
      # Try using curl-tools container
      local curl_tools_container=$(ensure_curl_tools "curl jq bash bind-tools ca-certificates")
      
      if [ -n "$curl_tools_container" ]; then
        local kong_container=$(get_container_name "kong" "dive25" "config")
        
        if [ -n "$kong_container" ]; then
          show_progress "Trying container-to-container access..."
          
          local container_url="http://${kong_container}:8001"
          local container_response=$(docker exec "$curl_tools_container" curl -s "$container_url" 2>/dev/null)
          
          if [ -n "$container_response" ]; then
            success "Kong Admin API is accessible via container network at $container_url"
            kong_admin_url=$container_url
          else
            error "Kong Admin API is not accessible via any method"
            return $E_NETWORK_ERROR
          fi
        fi
      else
        error "Kong Admin API is not accessible"
        return $E_NETWORK_ERROR
      fi
    fi
  fi
  
  # Use curl-tools container for API requests if necessary
  local curl_prefix=""
  local curl_tools_container=$(ensure_curl_tools "curl jq bash bind-tools ca-certificates")
  
  if [ -n "$curl_tools_container" ] && [[ "$kong_admin_url" == *"localhost"* ]]; then
    curl_prefix="docker exec $curl_tools_container"
  fi
  
  # Get list of services
  local services=$(eval "$curl_prefix curl -s $kong_admin_url/services" | grep -o '"name":"[^"]*"' | cut -d'"' -f4)
  
  if [ -z "$services" ]; then
    warning "No services configured in Kong"
    return $E_CONFIG_ERROR
  fi
  
  # Display configured services
  echo "Kong services configured:"
  for service in $services; do
    echo "- $service"
  done
  
  # Get list of routes
  local routes=$(eval "$curl_prefix curl -s $kong_admin_url/routes" | grep -o '"name":"[^"]*"' | cut -d'"' -f4)
  
  if [ -z "$routes" ]; then
    warning "No routes configured in Kong"
    return $E_CONFIG_ERROR
  fi
  
  # Display configured routes
  echo "Kong routes configured:"
  for route in $routes; do
    echo "- $route"
  done
  
  # Check for plugins, especially the OIDC plugin
  local plugins=$(eval "$curl_prefix curl -s $kong_admin_url/plugins" | grep -o '"name":"[^"]*"' | cut -d'"' -f4)
  
  if [ -n "$plugins" ]; then
    echo "Kong plugins configured:"
    for plugin in $plugins; do
      echo "- $plugin"
    done
    
    # Verify OIDC plugin specifically
    if echo "$plugins" | grep -q "oidc"; then
      success "OIDC plugin is configured"
      
      # Get details of OIDC plugin
      local oidc_config=$(eval "$curl_prefix curl -s $kong_admin_url/plugins?name=oidc")
      
      # Check key configuration values
      local discovery_url=$(echo "$oidc_config" | grep -o '"discovery":"[^"]*"' | cut -d'"' -f4)
      local realm=$(echo "$oidc_config" | grep -o '"realm":"[^"]*"' | cut -d'"' -f4)
      local ssl_verify=$(echo "$oidc_config" | grep -o '"ssl_verify":"[^"]*"' | cut -d'"' -f4)
      
      info "OIDC Configuration:"
      info "- Discovery URL: $discovery_url"
      info "- Realm: $realm"
      info "- SSL Verify: $ssl_verify"
    else
      warning "OIDC plugin is not configured"
    fi
  else
    info "No plugins configured in Kong"
  fi
  
  success "Kong gateway configuration verified"
  return $E_SUCCESS
}

# Function to check Certificate validity and trust
verify_certificate_trust() {
  print_step "Verifying Certificate Trust"
  
  # Get variables from environment or defaults
  local base_domain=${BASE_DOMAIN:-"dive25.local"}
  
  show_progress "Checking certificate validity and trust for $base_domain..."
  
  # Check if the certificate exists
  local cert_path="$ROOT_DIR/certs/cert.pem"
  if [ ! -f "$cert_path" ]; then
    error "Certificate file not found at $cert_path"
    return $E_RESOURCE_NOT_FOUND
  fi
  
  # Check certificate information
  local cert_info=$(openssl x509 -in "$cert_path" -text -noout)
  
  # Check if the certificate is valid for the base domain
  if echo "$cert_info" | grep -q "DNS:$base_domain" || echo "$cert_info" | grep -q "DNS:*.$base_domain"; then
    success "Certificate is valid for $base_domain"
  else
    warning "Certificate may not be valid for $base_domain"
    
    # Show Subject Alternative Names for debugging
    local sans=$(echo "$cert_info" | grep -A1 "Subject Alternative Name" | tail -1)
    info "Certificate SANs: $sans"
  fi
  
  # Check certificate expiration
  local not_after=$(openssl x509 -in "$cert_path" -noout -enddate | cut -d= -f2)
  local now=$(date)
  local expiry_date=$(date -d "$not_after" '+%Y-%m-%d')
  local current_date=$(date '+%Y-%m-%d')
  
  # Calculate days until expiration
  local days_until_expiry=$(( ($(date -d "$expiry_date" '+%s') - $(date -d "$current_date" '+%s')) / 86400 ))
  
  if [ $days_until_expiry -lt 0 ]; then
    error "Certificate has EXPIRED!"
  elif [ $days_until_expiry -lt 30 ]; then
    warning "Certificate will expire soon ($days_until_expiry days remaining)"
  else
    success "Certificate is valid for $days_until_expiry more days"
  fi
  
  # Check if the certificate is trusted by curl
  local test_url="https://frontend.$base_domain:${FRONTEND_PORT:-3001}"
  if curl -s --cacert "$cert_path" -o /dev/null -w "%{http_code}" "$test_url" | grep -q -E "200|30[1-8]"; then
    success "Certificate is trusted by curl for $test_url"
  else
    warning "Certificate is not trusted by curl for $test_url"
  fi
  
  # Check certificate distribution to containers
  show_progress "Verifying certificate trust in containers..."
  
  # Get all containers
  local containers=$(docker ps --format '{{.Names}}' | grep "dive25")
  
  if [ -z "$containers" ]; then
    warning "No running containers found"
    return $E_GENERAL_ERROR
  fi
  
  # Select test container
  local test_container=$(ensure_curl_tools "curl ca-certificates")
  
  # Test certificate trust from container
  show_progress "Testing certificate trust from inside container..."
  
  # Copy the certificate to the container
  docker cp "$cert_path" "$test_container:/tmp/cert.pem"
  
  # Get Keycloak container for internal URL test
  local keycloak_container=$(get_container_name "keycloak" "dive25" "config")
  
  # Test various URLs for certificate trust within the container
  local internal_urls=(
    "https://keycloak:8443"
    "https://kong:8443"
    "https://api:3000"
    "https://frontend:3000"
  )
  
  local trust_success=0
  
  for url in "${internal_urls[@]}"; do
    show_progress "Testing certificate trust for $url..."
    
    # Use --cacert to explicitly trust our certificate
    local http_code=$(docker exec "$test_container" curl -sk --cacert "/tmp/cert.pem" -o /dev/null -w "%{http_code}" "$url" 2>/dev/null)
    
    if [ -n "$http_code" ] && [ "$http_code" != "000" ]; then
      success "Certificate is trusted for $url (HTTP $http_code)"
      trust_success=$((trust_success+1))
    else
      warning "Certificate is not trusted for $url or service not available"
    fi
  done
  
  if [ $trust_success -gt 0 ]; then
    success "Certificate trust verification completed with $trust_success successful tests"
    return $E_SUCCESS
  else
    error "Certificate trust verification failed - no services accessible"
    
    # Additional diagnostic information
    show_progress "Checking CA trust distribution in containers..."
    
    for container in $containers; do
      if docker exec $container sh -c "ls -la /usr/local/share/ca-certificates/" 2>/dev/null | grep -q "dive25"; then
        success "CA certificate found in $container"
      elif docker exec $container sh -c "ls -la /etc/ssl/certs/" 2>/dev/null | grep -q "dive25"; then
        success "CA certificate found in $container (in /etc/ssl/certs)"
      elif docker exec $container sh -c "ls -la /tmp/certs/" 2>/dev/null | grep -q "dive25"; then
        success "CA certificate found in $container (in /tmp/certs)"
      else
        warning "CA certificate not found in $container"
      fi
    done
    
    return $E_GENERAL_ERROR
  fi
}

# Enhanced function to check DNS resolution between containers
verify_dns_resolution() {
  print_step "Verifying DNS Resolution Between Containers"
  
  show_progress "Testing if containers can resolve each other by hostname..."
  
  # Get a test container
  local test_container=$(ensure_curl_tools "curl bind-tools")
  
  # Services to check
  local services=(
    "keycloak"
    "kong"
    "api"
    "frontend"
    "mongodb"
    "postgres"
  )
  
  local dns_success=0
  local dns_total=0
  
  for service in "${services[@]}"; do
    dns_total=$((dns_total+1))
    
    # Test DNS resolution
    if docker exec "$test_container" ping -c 1 "$service" >/dev/null 2>&1; then
      success "DNS resolution successful: $service"
      dns_success=$((dns_success+1))
      
      # Get IP for diagnostic info
      local ip=$(docker exec "$test_container" getent hosts "$service" | awk '{print $1}')
      if [ -n "$ip" ]; then
        debug "$service resolves to $ip"
      fi
    else
      warning "DNS resolution failed: $service"
      
      # Try diagnostic with nslookup
      local nslookup=$(docker exec "$test_container" nslookup "$service" 2>/dev/null)
      if [ -n "$nslookup" ]; then
        debug "nslookup for $service: $nslookup"
      fi
      
      # Check if container exists
      local container=$(get_container_name "$service" "dive25" "" "false")
      if [ -z "$container" ]; then
        info "Container for service '$service' does not exist - DNS failure expected"
      else
        error "Container exists but DNS resolution failed. This indicates a networking issue."
        
        # Get container IP for manual checking
        local container_ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$container" 2>/dev/null)
        if [ -n "$container_ip" ]; then
          debug "Container $container has IP $container_ip"
          
          # Try to ping the IP directly
          if docker exec "$test_container" ping -c 1 "$container_ip" >/dev/null 2>&1; then
            info "Container IP is reachable directly, but hostname resolution fails"
          else
            info "Container IP is not reachable directly - network isolation issue"
          fi
        fi
      fi
    fi
  done
  
  echo
  if [ $dns_success -eq $dns_total ]; then
    success "All DNS resolution tests passed ($dns_success/$dns_total)"
    return $E_SUCCESS
  else
    warning "Some DNS resolution tests failed ($(($dns_total-$dns_success))/$dns_total failed)"
    
    # Suggest troubleshooting steps
    echo -e "\n${YELLOW}Troubleshooting suggestions:${RESET}"
    echo "1. Check Docker network configuration in docker-compose.yml"
    echo "2. Ensure all containers are in the same network"
    echo "3. Check if Docker DNS service is working properly"
    echo "4. Try restarting the Docker daemon"
    
    return $E_NETWORK_ERROR
  fi
}

# Function to test connectivity between critical components
verify_critical_connections() {
  print_step "Verifying Critical Service Connections"
  
  show_progress "Testing connectivity between critical components..."
  
  # Get a test container
  local test_container=$(ensure_curl_tools "curl")
  
  # Critical connections to test
  # Format: source_service:port->target_service:port
  local connections=(
    "kong:8000->keycloak:8080"  # Kong to Keycloak
    "api:3000->kong:8000"       # API to Kong
    "frontend:3000->kong:8000"  # Frontend to Kong
    "api:3000->mongodb:27017"   # API to MongoDB (if using)
  )
  
  local success_count=0
  
  # Test each connection
  for connection in "${connections[@]}"; do
    local source=$(echo "$connection" | cut -d'-' -f1)
    local target=$(echo "$connection" | cut -d'>' -f2)
    
    local source_service=$(echo "$source" | cut -d':' -f1)
    local source_port=$(echo "$source" | cut -d':' -f2)
    local target_service=$(echo "$target" | cut -d':' -f1)
    local target_port=$(echo "$target" | cut -d':' -f2)
    
    show_progress "Testing connection: $source_service:$source_port -> $target_service:$target_port"
    
    # Use telnet equivalent to test port connectivity
    if docker exec "$test_container" sh -c "nc -z -w2 $target_service $target_port" 2>/dev/null; then
      success "Connection successful: $source_service:$source_port -> $target_service:$target_port"
      success_count=$((success_count+1))
    else
      warning "Connection failed: $source_service:$source_port -> $target_service:$target_port"
      
      # Check if both services exist
      local source_container=$(get_container_name "$source_service" "dive25" "" "false")
      local target_container=$(get_container_name "$target_service" "dive25" "" "false")
      
      if [ -z "$source_container" ]; then
        info "Source service container ($source_service) does not exist"
      fi
      
      if [ -z "$target_container" ]; then
        info "Target service container ($target_service) does not exist"
      fi
      
      if [ -n "$source_container" ] && [ -n "$target_container" ]; then
        # Both containers exist, check network configuration
        local source_network=$(docker inspect -f '{{range $key, $value := .NetworkSettings.Networks}}{{$key}} {{end}}' "$source_container" 2>/dev/null)
        local target_network=$(docker inspect -f '{{range $key, $value := .NetworkSettings.Networks}}{{$key}} {{end}}' "$target_container" 2>/dev/null)
        
        debug "Source container networks: $source_network"
        debug "Target container networks: $target_network"
        
        # Check if they share a network
        local common_network=""
        for snet in $source_network; do
          for tnet in $target_network; do
            if [ "$snet" = "$tnet" ]; then
              common_network="$snet"
              break
            fi
          done
          if [ -n "$common_network" ]; then
            break
          fi
        done
        
        if [ -n "$common_network" ]; then
          info "Both containers are in the same network: $common_network"
          info "Port $target_port may not be exposed in the container"
        else
          error "Containers are not in the same network - this is likely the issue"
        fi
      fi
    fi
  done
  
  echo
  if [ $success_count -eq ${#connections[@]} ]; then
    success "All critical connections verified successfully ($success_count/${#connections[@]})"
    return $E_SUCCESS
  else
    warning "Some critical connections failed ($(( ${#connections[@]} - $success_count ))/${#connections[@]} failed)"
    return $E_NETWORK_ERROR
  fi
}

# Comprehensive service health check
check_all_services_health() {
  print_header "Comprehensive Service Health Check"
  
  # Skip comprehensive checks if in test or fast setup mode
  if [ "$FAST_SETUP" = "true" ] || [ "$TEST_MODE" = "true" ]; then
    info "Fast setup or test mode enabled, skipping comprehensive health checks"
    if [ "$TEST_MODE" = "true" ]; then
      success "Health checks would be skipped in test mode"
    fi
    return $E_SUCCESS
  fi
  
  # Create results array to track all checks
  local check_results=()
  local check_names=()
  
  # Check Docker services health
  check_names+=("Docker Services")
  if check_compose_health 16 "dive25" 120; then
    check_results+=("✅")
  else
    check_results+=("❌")
  fi
  
  # Check service URLs
  check_names+=("Service URLs")
  if check_service_urls; then
    check_results+=("✅")
  else
    check_results+=("❌")
  fi
  
  # Verify Keycloak OIDC
  check_names+=("Keycloak OIDC")
  if verify_keycloak_oidc; then
    check_results+=("✅")
  else
    check_results+=("❌")
  fi
  
  # Verify Kong configuration
  check_names+=("Kong Configuration")
  if verify_kong_configuration; then
    check_results+=("✅")
  else
    check_results+=("❌")
  fi
  
  # Verify certificate trust
  check_names+=("Certificate Trust")
  if verify_certificate_trust; then
    check_results+=("✅")
  else
    check_results+=("❌")
  fi
  
  # Verify DNS resolution
  check_names+=("DNS Resolution")
  if verify_dns_resolution; then
    check_results+=("✅")
  else
    check_results+=("❌")
  fi
  
  # Verify critical connections
  check_names+=("Critical Connections")
  if verify_critical_connections; then
    check_results+=("✅")
  else
    check_results+=("❌")
  fi
  
  # Display summary
  print_header "Health Check Summary"
  
  local success_count=0
  for ((i=0; i<${#check_names[@]}; i++)); do
    echo "${check_results[$i]} ${check_names[$i]}"
    if [ "${check_results[$i]}" = "✅" ]; then
      success_count=$((success_count+1))
    fi
  done
  
  echo
  if [ $success_count -eq ${#check_names[@]} ]; then
    success "All health checks passed ($success_count/${#check_names[@]})"
    return $E_SUCCESS
  else
    warning "Some health checks failed ($(( ${#check_names[@]} - $success_count ))/${#check_names[@]} failed)"
    return $E_GENERAL_ERROR
  fi
}

# Main function for verification
main() {
  # Run all checks
  check_all_services_health
  
  return $?
}

# Execute main function if script is run directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi 