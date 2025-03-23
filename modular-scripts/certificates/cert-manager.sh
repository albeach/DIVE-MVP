#!/bin/bash
# Certificate generation and management functions

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Import required utility functions
source "$SCRIPT_DIR/../utils/logging.sh"
source "$SCRIPT_DIR/../utils/system.sh"
source "$SCRIPT_DIR/../utils/config.sh"

# Directory for storing certificates
CERTS_DIR="${ROOT_DIR}/certs"
CA_DIR="${CERTS_DIR}/ca"

# Function to check if mkcert is installed
check_mkcert_installed() {
  print_step "Checking mkcert installation"
  
  # Skip mkcert check in test mode
  if [ "$TEST_MODE" = "true" ]; then
    info "TEST_MODE is enabled - skipping mkcert installation check"
    return 0
  fi

  if ! command_exists mkcert; then
    error "mkcert is not installed. Please install it first."
    info "Installation instructions: https://github.com/FiloSottile/mkcert#installation"
    return $E_DEPENDENCY_MISSING
  fi
  
  success "mkcert is installed"
  return $E_SUCCESS
}

# Function to setup CA and certificates
setup_certificates() {
  print_header "Setting Up Certificates"
  
  local base_domain="$1"
  local domains="${2:-""}"
  local force_recreate="${3:-false}"
  
  # Check if mkcert is installed
  check_mkcert_installed
  if [ $? -ne 0 ]; then
    # In test mode, we can continue without mkcert
    if [ "$TEST_MODE" != "true" ]; then
      warning "mkcert not installed, will use OpenSSL instead"
    fi
  fi
  
  # Create certificates directory if it doesn't exist
  mkdir -p "$CERTS_DIR"
  
  # Create CA directory if it doesn't exist
  mkdir -p "$CA_DIR"
  
  # Check if we need to generate new certificates
  if [ "$force_recreate" = "true" ] || [ ! -f "$CERTS_DIR/rootCA.pem" ]; then
    print_step "Generating root CA"
    
    # Generate root CA key
    show_progress "Generating root CA key..."
    openssl genrsa -out "$CA_DIR/rootCA.key" 4096
    
    # Generate root CA certificate
    show_progress "Generating root CA certificate..."
    openssl req -x509 -new -nodes -key "$CA_DIR/rootCA.key" -sha256 -days 3650 \
      -out "$CA_DIR/rootCA.pem" \
      -subj "/C=US/ST=State/L=City/O=DIVE25/OU=Development/CN=DIVE25 Root CA"
    
    # Copy root CA to main certs directory for compatibility
    cp "$CA_DIR/rootCA.pem" "$CERTS_DIR/rootCA.pem"
    
    success "Root CA generated successfully"
  else
    info "Using existing Root CA"
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
      domains="$domains,$(get_env_value "MONGODB_EXPRESS_DOMAIN" "$ROOT_DIR/.env" "mongo-express").$base_domain"
      domains="$domains,$(get_env_value "PHPLDAPADMIN_DOMAIN" "$ROOT_DIR/.env" "phpldapadmin").$base_domain"
      domains="$domains,$(get_env_value "OPA_DOMAIN" "$ROOT_DIR/.env" "opa").$base_domain"
    else
      # Default domains if .env file doesn't exist
      domains="$base_domain,frontend.$base_domain,api.$base_domain,keycloak.$base_domain,kong.$base_domain"
    fi
  fi
  
  # Convert comma-separated domains to space-separated for mkcert
  local mkcert_domains=$(echo "$domains" | sed 's/,/ /g')
  
  print_step "Generating certificates for domains: $domains"
  
  # Create domains directory for individual certificates
  mkdir -p "$CERTS_DIR/domains"
  
  # Generate wildcard certificate
  show_progress "Generating wildcard certificate for *.$base_domain..."
  
  if command_exists mkcert; then
    # Using mkcert for development certificates
    (cd "$CERTS_DIR" && mkcert -cert-file cert.pem -key-file key.pem \
      "$base_domain" "*.$base_domain" "localhost" "127.0.0.1")
    
    # Copy CAROOT certificate 
    if [ -n "$CAROOT" ] && [ -f "$CAROOT/rootCA.pem" ]; then
      cp "$CAROOT/rootCA.pem" "$CERTS_DIR/rootCA.pem"
    fi
  else
    # Fallback to OpenSSL if mkcert is not available
    show_progress "Using OpenSSL to generate certificates..."
    
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
  
  # Generate individual certificates for each domain if needed
  for domain in $(echo "$domains" | tr ',' ' '); do
    if [ "$force_recreate" = "true" ] || [ ! -f "$CERTS_DIR/domains/$domain.cert.pem" ]; then
      show_progress "Generating certificate for $domain..."
      
      # Get the container name for this domain (if it exists)
      local container_name=$(echo $domain | cut -d. -f1)
      local extra_dns=""
      
      # Check if container exists - add it to the SAN list
      if docker ps --format '{{.Names}}' | grep -q "${container_name}"; then
        extra_dns="DNS.3 = ${container_name}"
        debug "Adding container name $container_name to certificate SAN"
      fi
      
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
$extra_dns
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
    fi
  done
  
  success "Certificates generated successfully"
  return $E_SUCCESS
}

# Function to distribute CA trust to containers
distribute_ca_trust() {
  print_header "Distributing CA Trust"
  
  # List of services to distribute CA trust to
  local services="$1"
  
  if [ -z "$services" ]; then
    # Get services from docker-compose
    services=$(docker-compose ps --services 2>/dev/null)
    
    if [ -z "$services" ]; then
      # Get running container names as a fallback
      services=$(docker ps --format '{{.Names}}' | grep "dive25" | sed 's/^dive25-//' | sed 's/^dive25_//')
    fi
  fi
  
  # Use the enhanced version in utils directory
  debug "Using enhanced CA trust distribution from utils"
  bash "$SCRIPT_DIR/../utils/distribute-ca-trust.sh" $services
  
  local result=$?
  if [ $result -ne 0 ]; then
    warning "CA trust distribution encountered issues (exit code: $result)"
  else
    success "CA trust distribution completed successfully"
  fi
  
  return $result
}

# Function to verify certificate installation
verify_certificates() {
  print_step "Verifying Certificates"
  
  # Check if certificate files exist
  if [ ! -f "$CERTS_DIR/cert.pem" ] || [ ! -f "$CERTS_DIR/key.pem" ]; then
    error "Certificate files not found"
    return $E_RESOURCE_NOT_FOUND
  fi
  
  # Verify certificate validity
  show_progress "Checking certificate validity..."
  local cert_end_date=$(openssl x509 -enddate -noout -in "$CERTS_DIR/cert.pem" | cut -d= -f2)
  local cert_start_date=$(openssl x509 -startdate -noout -in "$CERTS_DIR/cert.pem" | cut -d= -f2)
  local cert_issuer=$(openssl x509 -issuer -noout -in "$CERTS_DIR/cert.pem")
  local cert_subject=$(openssl x509 -subject -noout -in "$CERTS_DIR/cert.pem")
  local cert_san=$(openssl x509 -text -noout -in "$CERTS_DIR/cert.pem" | grep -A1 "Subject Alternative Name" | tail -n1)
  
  info "Certificate details:"
  info "  Valid from: $cert_start_date"
  info "  Valid until: $cert_end_date"
  info "  Issuer: $cert_issuer"
  info "  Subject: $cert_subject"
  info "  SAN: $cert_san"
  
  # Check certificate isn't expired
  if ! openssl x509 -checkend 0 -noout -in "$CERTS_DIR/cert.pem"; then
    error "Certificate has expired"
    return $E_GENERAL_ERROR
  fi
  
  # Verify certificate matches private key
  show_progress "Verifying certificate matches private key..."
  local cert_modulus=$(openssl x509 -noout -modulus -in "$CERTS_DIR/cert.pem" | openssl md5)
  local key_modulus=$(openssl rsa -noout -modulus -in "$CERTS_DIR/key.pem" | openssl md5)
  
  if [ "$cert_modulus" != "$key_modulus" ]; then
    error "Certificate does not match private key"
    return $E_GENERAL_ERROR
  fi
  
  # Check for existing CA certificate
  if [ -f "$CERTS_DIR/rootCA.pem" ]; then
    info "Found existing Root CA certificate:"
    
    # Get certificate info
    ca_subject=$(openssl x509 -noout -subject -in "$CERTS_DIR/rootCA.pem" | sed 's/subject=//g')
    ca_issuer=$(openssl x509 -noout -issuer -in "$CERTS_DIR/rootCA.pem" | sed 's/issuer=//g')
    ca_start_date=$(openssl x509 -noout -startdate -in "$CERTS_DIR/rootCA.pem" | sed 's/notBefore=//g')
    ca_end_date=$(openssl x509 -noout -enddate -in "$CERTS_DIR/rootCA.pem" | sed 's/notAfter=//g')
    
    info "  Subject: $ca_subject"
    info "  Issuer: $ca_issuer"
    info "  Valid from: $ca_start_date"
    info "  Valid until: $ca_end_date"
    
    # Check CA certificate isn't expired
    if ! openssl x509 -checkend 0 -noout -in "$CERTS_DIR/rootCA.pem"; then
      error "Root CA certificate has expired"
      return $E_GENERAL_ERROR
    fi
  else
    warning "Root CA certificate not found"
  fi
  
  success "Certificate verification successful"
  return $E_SUCCESS
}

# Main function to generate certificates
main() {
  # Default domain if not specified
  local base_domain="${1:-dive25.local}"
  local domains="${2:-}"
  local force_recreate="${3:-false}"
  
  # Set up certificates
  setup_certificates "$base_domain" "$domains" "$force_recreate"
  local cert_result=$?
  
  # Verify certificates
  verify_certificates
  local verify_result=$?
  
  # Distribute CA trust if we have Docker running
  if docker info >/dev/null 2>&1; then
    distribute_ca_trust
  else
    warning "Docker not running, skipping CA trust distribution"
  fi
  
  # Return appropriate error code
  if [ $cert_result -ne 0 ]; then
    return $cert_result
  elif [ $verify_result -ne 0 ]; then
    return $verify_result
  else
    return $E_SUCCESS
  fi
}

# Execute main function if script is run directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi 