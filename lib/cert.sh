#!/bin/bash
# DIVE25 - Certificate management library
# Handles generation and distribution of SSL certificates

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source common library if not already sourced
if [ -z "${log_info+x}" ]; then
  source "$SCRIPT_DIR/common.sh"
fi

# Directory for storing certificates
CERTS_DIR="${ROOT_DIR}/certs"
CA_DIR="${CERTS_DIR}/ca"

# Function to check if mkcert is installed
check_mkcert_installed() {
  log_progress "Checking for mkcert installation"
  
  # Skip mkcert check in test mode
  if [ "$TEST_MODE" = "true" ] || [ "$FAST_MODE" = "true" ]; then
    log_info "Test/fast mode enabled - skipping mkcert installation check"
    return $E_SUCCESS
  fi

  if ! command_exists mkcert; then
    log_warning "mkcert is not installed"
    log_info "Installation instructions: https://github.com/FiloSottile/mkcert#installation"
    log_info "Will use OpenSSL instead"
    return $E_DEPENDENCY_MISSING
  fi
  
  log_success "mkcert is installed"
  return $E_SUCCESS
}

# Function to setup CA and certificates
setup_certificates() {
  log_header "Setting Up Certificates"
  
  local base_domain="${1:-dive25.local}"
  local force_recreate="${2:-false}"
  local domains="${3:-""}"
  
  # Create certificates directory if it doesn't exist
  mkdir -p "$CERTS_DIR"
  
  # Create CA directory if it doesn't exist
  mkdir -p "$CA_DIR"
  
  # Check if mkcert is installed
  check_mkcert_installed
  local use_mkcert=$?
  
  # Check if we need to generate new certificates
  if [ "$force_recreate" = "true" ] || [ ! -f "$CA_DIR/rootCA.pem" ]; then
    log_step "Generating root CA"
    
    # Generate root CA key
    log_progress "Generating root CA key..."
    openssl genrsa -out "$CA_DIR/rootCA.key" 4096
    
    # Generate root CA certificate
    log_progress "Generating root CA certificate..."
    openssl req -x509 -new -nodes -key "$CA_DIR/rootCA.key" -sha256 -days 3650 \
      -out "$CA_DIR/rootCA.pem" \
      -subj "/C=US/ST=State/L=City/O=DIVE25/OU=Development/CN=DIVE25 Root CA"
    
    # Copy root CA to main certs directory for compatibility
    cp "$CA_DIR/rootCA.pem" "$CERTS_DIR/rootCA.pem"
    
    log_success "Root CA generated successfully"
  else
    log_info "Using existing Root CA"
  fi
  
  # Parse domains list
  if [ -z "$domains" ]; then
    # Extract domains from .env file if they exist
    if [ -f "$ROOT_DIR/.env" ]; then
      base_domain=$(get_env_value "BASE_DOMAIN" "$ROOT_DIR/.env" "$base_domain")
      
      # Build domains list from .env variables
      domains="$base_domain"
      domains="$domains,$(get_env_value "FRONTEND_DOMAIN" "$ROOT_DIR/.env" "frontend").$base_domain"
      domains="$domains,$(get_env_value "API_DOMAIN" "$ROOT_DIR/.env" "api").$base_domain"
      domains="$domains,$(get_env_value "KEYCLOAK_DOMAIN" "$ROOT_DIR/.env" "keycloak").$base_domain"
      domains="$domains,$(get_env_value "KONG_DOMAIN" "$ROOT_DIR/.env" "kong").$base_domain"
      domains="$domains,$(get_env_value "GRAFANA_DOMAIN" "$ROOT_DIR/.env" "grafana").$base_domain"
      domains="$domains,$(get_env_value "PROMETHEUS_DOMAIN" "$ROOT_DIR/.env" "prometheus").$base_domain"
    else
      # Default domains if .env file doesn't exist
      domains="$base_domain,frontend.$base_domain,api.$base_domain,keycloak.$base_domain,kong.$base_domain"
    fi
  fi
  
  # Convert comma-separated domains to space-separated for mkcert
  local mkcert_domains=$(echo "$domains" | sed 's/,/ /g')
  
  log_step "Generating certificates for domains: $domains"
  
  # Create domains directory for individual certificates
  mkdir -p "$CERTS_DIR/domains"
  
  # Generate wildcard certificate
  log_progress "Generating wildcard certificate for *.$base_domain..."
  
  if [ $use_mkcert -eq 0 ] && command_exists mkcert; then
    # Using mkcert for development certificates
    (cd "$CERTS_DIR" && mkcert -cert-file cert.pem -key-file key.pem \
      "$base_domain" "*.$base_domain" "localhost" "127.0.0.1")
    
    # Copy CAROOT certificate 
    if [ -n "$CAROOT" ] && [ -f "$CAROOT/rootCA.pem" ]; then
      cp "$CAROOT/rootCA.pem" "$CERTS_DIR/rootCA.pem"
    fi
  else
    # Fallback to OpenSSL if mkcert is not available
    log_progress "Using OpenSSL to generate certificates..."
    
    # Generate key
    openssl genrsa -out "$CERTS_DIR/key.pem" 2048
    
    # Create a config file for the certificate
    cat > "$CERTS_DIR/openssl.cnf" << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = US
ST = State
L = City
O = DIVE25
OU = Development
CN = $base_domain

[v3_req]
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = $base_domain
DNS.2 = *.$base_domain
DNS.3 = localhost
IP.1 = 127.0.0.1
EOF
    
    # Generate CSR
    openssl req -new -key "$CERTS_DIR/key.pem" -out "$CERTS_DIR/csr.pem" \
      -config "$CERTS_DIR/openssl.cnf"
    
    # Sign certificate with the Root CA
    openssl x509 -req -in "$CERTS_DIR/csr.pem" \
      -CA "$CA_DIR/rootCA.pem" \
      -CAkey "$CA_DIR/rootCA.key" \
      -CAcreateserial \
      -out "$CERTS_DIR/cert.pem" \
      -days 825 \
      -extensions v3_req \
      -extfile "$CERTS_DIR/openssl.cnf"
    
    # Clean up CSR
    rm "$CERTS_DIR/csr.pem"
  fi
  
  # Create combined PEM for services that need it
  cat "$CERTS_DIR/cert.pem" "$CERTS_DIR/key.pem" > "$CERTS_DIR/fullchain.pem"
  
  # Create copies for Kong's specific naming
  cp "$CERTS_DIR/cert.pem" "$CERTS_DIR/dive25-cert.pem"
  cp "$CERTS_DIR/key.pem" "$CERTS_DIR/dive25-key.pem"
  
  log_success "Main certificates generated successfully"
  
  # Generate individual certificates for specific domains if needed
  log_step "Generating individual domain certificates"
  
  for domain in $(echo "$domains" | tr ',' ' '); do
    if [ "$force_recreate" = "true" ] || [ ! -f "$CERTS_DIR/domains/$domain.cert.pem" ]; then
      log_progress "Generating certificate for $domain..."
      
      # Set up openssl.cnf for this domain
      cat > "$CERTS_DIR/domains/$domain.cnf" << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = US
ST = State
L = City
O = DIVE25
OU = Development
CN = $domain

[v3_req]
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = $domain
DNS.2 = $(echo $domain | cut -d. -f1)  # Container name
EOF
      
      # Generate key
      openssl genrsa -out "$CERTS_DIR/domains/$domain.key.pem" 2048
      
      # Generate CSR
      openssl req -new -key "$CERTS_DIR/domains/$domain.key.pem" \
        -out "$CERTS_DIR/domains/$domain.csr.pem" \
        -config "$CERTS_DIR/domains/$domain.cnf"
      
      # Sign certificate with the Root CA
      openssl x509 -req -in "$CERTS_DIR/domains/$domain.csr.pem" \
        -CA "$CA_DIR/rootCA.pem" \
        -CAkey "$CA_DIR/rootCA.key" \
        -CAcreateserial \
        -out "$CERTS_DIR/domains/$domain.cert.pem" \
        -days 825 \
        -extensions v3_req \
        -extfile "$CERTS_DIR/domains/$domain.cnf"
      
      # Clean up CSR
      rm "$CERTS_DIR/domains/$domain.csr.pem"
    else
      log_debug "Certificate for $domain already exists, skipping"
    fi
  done
  
  log_success "All certificates generated successfully"
  return $E_SUCCESS
}

# Function to distribute CA trust to containers
distribute_ca_trust() {
  log_step "Distributing CA trust to containers"
  
  local ca_file="${CERTS_DIR}/rootCA.pem"
  local services=("$@")
  
  # Check if CA file exists
  if [ ! -f "$ca_file" ]; then
    log_error "CA file not found: $ca_file"
    return $E_RESOURCE_NOT_FOUND
  fi
  
  # If no services specified, get all running containers
  if [ ${#services[@]} -eq 0 ]; then
    log_info "No services specified, distributing to all running containers"
    
    # Get all running container names
    local containers=$(docker ps --format '{{.Names}}' | grep "dive25")
    
    for container in $containers; do
      # Extract service name from container name
      local service=$(echo $container | sed -E 's/dive25-([^-]+-)?(.*)/\2/')
      services+=("$service")
    done
  fi
  
  log_info "Distributing CA trust to services: ${services[*]}"
  
  # Process each service
  for service in "${services[@]}"; do
    # Get container name that matches the service pattern
    local container=$(get_container_name "$service" "dive25")
    
    if [ -z "$container" ]; then
      log_warning "No container found for service: $service"
      continue
    fi
    
    log_progress "Distributing CA trust to container: $container"
    
    # Detect container OS and distribution method
    local distro=""
    if exec_in_container "$container" "command -v apt-get" >/dev/null 2>&1; then
      distro="debian"
    elif exec_in_container "$container" "command -v apk" >/dev/null 2>&1; then
      distro="alpine"
    elif exec_in_container "$container" "command -v yum" >/dev/null 2>&1; then
      distro="redhat"
    else
      log_warning "Unknown distribution in container $container, skipping"
      continue
    fi
    
    # Copy CA certificate to container
    copy_to_container "$ca_file" "$container" "/tmp/rootCA.pem"
    
    # Install certificate according to distribution
    case $distro in
      debian)
        # Debian/Ubuntu method
        exec_in_container "$container" "mkdir -p /usr/local/share/ca-certificates"
        exec_in_container "$container" "cp /tmp/rootCA.pem /usr/local/share/ca-certificates/dive25-ca.crt"
        exec_in_container "$container" "update-ca-certificates" >/dev/null 2>&1
        ;;
      alpine)
        # Alpine method
        exec_in_container "$container" "mkdir -p /usr/local/share/ca-certificates"
        exec_in_container "$container" "cp /tmp/rootCA.pem /usr/local/share/ca-certificates/dive25-ca.crt"
        exec_in_container "$container" "update-ca-certificates" >/dev/null 2>&1
        ;;
      redhat)
        # RHEL/CentOS method
        exec_in_container "$container" "mkdir -p /etc/pki/ca-trust/source/anchors"
        exec_in_container "$container" "cp /tmp/rootCA.pem /etc/pki/ca-trust/source/anchors/dive25-ca.pem"
        exec_in_container "$container" "update-ca-trust extract" >/dev/null 2>&1
        ;;
    esac
    
    # Clean up
    exec_in_container "$container" "rm -f /tmp/rootCA.pem"
    
    log_success "CA trust distributed to $container"
  done
  
  log_success "CA trust distribution completed"
  return $E_SUCCESS
}

# Function to verify certificate installation
verify_certificate() {
  local domain="$1"
  local port="${2:-443}"
  
  log_progress "Verifying certificate for $domain:$port"
  
  if ! command_exists openssl; then
    log_error "OpenSSL not found, cannot verify certificate"
    return $E_DEPENDENCY_MISSING
  fi
  
  # Get certificate information
  local cert_info=$(openssl s_client -connect $domain:$port -showcerts </dev/null 2>/dev/null | \
    openssl x509 -text)
  
  if [ -z "$cert_info" ]; then
    log_error "Failed to retrieve certificate information for $domain:$port"
    return $E_NETWORK_ERROR
  fi
  
  # Check if certificate is valid
  local enddate=$(echo "$cert_info" | grep "Not After" | awk -F': ' '{print $2}')
  log_info "Certificate expires: $enddate"
  
  # Parse certificate to check if domain is in Subject Alternative Names
  local sans=$(echo "$cert_info" | grep -A 1 "Subject Alternative Name" | tail -n 1)
  if [[ "$sans" == *"DNS:$domain"* ]]; then
    log_success "Certificate is valid for $domain"
    return $E_SUCCESS
  else
    log_warning "Certificate may not be valid for $domain"
    log_info "Subject Alternative Names: $sans"
    return $E_GENERAL_ERROR
  fi
}

# Export all functions to make them available to sourcing scripts
export -f check_mkcert_installed
export -f setup_certificates
export -f distribute_ca_trust
export -f verify_certificate 