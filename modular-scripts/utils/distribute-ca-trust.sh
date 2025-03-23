#!/bin/bash
# Enhanced certificate distribution script with verification

# Import required utility functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/logging.sh"
source "$SCRIPT_DIR/system.sh"
source "$SCRIPT_DIR/config.sh"

# Directory for storing certificates
CERTS_DIR="${CERTS_DIR:-$ROOT_DIR/certs}"

# Function to verify a certificate is properly trusted in a container
verify_cert_trust() {
  local container_name="$1"
  local domain="${2:-keycloak.dive25.local}"
  
  # Check if container has curl
  if ! docker exec "${container_name}" sh -c "command -v curl" &>/dev/null; then
    debug "Container ${container_name} doesn't have curl installed, trying to install..."
    
    # Try to install curl based on OS
    if docker exec "${container_name}" sh -c "command -v apk" &>/dev/null; then
      # Alpine
      docker exec "${container_name}" sh -c "apk add --no-cache curl" &>/dev/null
    elif docker exec "${container_name}" sh -c "command -v apt-get" &>/dev/null; then
      # Debian/Ubuntu
      docker exec "${container_name}" sh -c "apt-get update && apt-get install -y curl" &>/dev/null
    elif docker exec "${container_name}" sh -c "command -v yum" &>/dev/null; then
      # CentOS/RHEL
      docker exec "${container_name}" sh -c "yum install -y curl" &>/dev/null
    else
      warning "Cannot install curl in ${container_name}, skipping verification"
      return 0  # Skip verification
    fi
  fi
  
  # Check if curl can connect to the domain using system CA trust
  if docker exec "${container_name}" sh -c "curl -s -o /dev/null -w '%{http_code}' https://${domain} || true" &>/dev/null; then
    success "Certificate for ${domain} is trusted in ${container_name}"
    return 0
  fi
  
  # Try with explicitly specifying the certificate for containers that may not have updated system trust
  if docker exec "${container_name}" sh -c "test -f /tmp/certs/dive25-rootCA.pem && curl -s -o /dev/null --cacert /tmp/certs/dive25-rootCA.pem -w '%{http_code}' https://${domain} || true" &>/dev/null; then
    success "Certificate for ${domain} is trusted in ${container_name} with explicit cert path"
    return 0
  fi
  
  warning "Certificate for ${domain} is NOT trusted in ${container_name}"
  return 1
}

# Function to install a certificate in an Alpine-based container
install_cert_alpine() {
  local container_name="$1"
  local cert_path="${2:-/tmp/dive25-rootCA.crt}"
  
  # First copy the certificate
  if ! docker cp "$CERTS_DIR/rootCA.pem" "${container_name}:${cert_path}" 2>/dev/null; then
    warning "Failed to copy certificate to ${container_name}"
    return 1
  fi
  
  debug "Successfully copied certificate to ${container_name}:${cert_path}"
  
  # Create backup dir for fallback
  docker exec "${container_name}" sh -c "mkdir -p /tmp/certs" 2>/dev/null
  docker cp "$CERTS_DIR/rootCA.pem" "${container_name}:/tmp/certs/dive25-rootCA.pem" 2>/dev/null
  
  # Install ca-certificates package and update CA trust
  docker exec "${container_name}" sh -c "apk update && apk add --no-cache ca-certificates" &>/dev/null
  
  # Move to standard locations and update trust
  docker exec "${container_name}" sh -c "cp ${cert_path} /usr/local/share/ca-certificates/dive25-rootCA.crt && update-ca-certificates" &>/dev/null
  
  # Verify trust
  if verify_cert_trust "${container_name}"; then
    success "Certificate successfully installed in ${container_name}"
    return 0
  else
    warning "Certificate installation in ${container_name} could not be verified"
    return 1
  fi
}

# Function to install a certificate in a Debian/Ubuntu-based container
install_cert_debian() {
  local container_name="$1"
  local cert_path="${2:-/tmp/dive25-rootCA.crt}"
  
  # First copy the certificate
  if ! docker cp "$CERTS_DIR/rootCA.pem" "${container_name}:${cert_path}" 2>/dev/null; then
    warning "Failed to copy certificate to ${container_name}"
    return 1
  fi
  
  debug "Successfully copied certificate to ${container_name}:${cert_path}"
  
  # Create backup dir for fallback
  docker exec "${container_name}" sh -c "mkdir -p /tmp/certs" 2>/dev/null
  docker cp "$CERTS_DIR/rootCA.pem" "${container_name}:/tmp/certs/dive25-rootCA.pem" 2>/dev/null
  
  # Install ca-certificates package and update CA trust
  docker exec "${container_name}" sh -c "apt-get update && apt-get install -y ca-certificates" &>/dev/null
  
  # Move to standard locations and update trust
  docker exec "${container_name}" sh -c "cp ${cert_path} /usr/local/share/ca-certificates/dive25-rootCA.crt && update-ca-certificates" &>/dev/null
  
  # Verify trust
  if verify_cert_trust "${container_name}"; then
    success "Certificate successfully installed in ${container_name}"
    return 0
  else
    warning "Certificate installation in ${container_name} could not be verified"
    return 1
  fi
}

# Function to install a certificate in a RedHat/CentOS-based container
install_cert_redhat() {
  local container_name="$1"
  local cert_path="${2:-/tmp/dive25-rootCA.crt}"
  
  # First copy the certificate
  if ! docker cp "$CERTS_DIR/rootCA.pem" "${container_name}:${cert_path}" 2>/dev/null; then
    warning "Failed to copy certificate to ${container_name}"
    return 1
  fi
  
  debug "Successfully copied certificate to ${container_name}:${cert_path}"
  
  # Create backup dir for fallback
  docker exec "${container_name}" sh -c "mkdir -p /tmp/certs" 2>/dev/null
  docker cp "$CERTS_DIR/rootCA.pem" "${container_name}:/tmp/certs/dive25-rootCA.pem" 2>/dev/null
  
  # Install ca-certificates package and update CA trust
  docker exec "${container_name}" sh -c "yum install -y ca-certificates" &>/dev/null
  
  # Move to standard locations and update trust
  docker exec "${container_name}" sh -c "cp ${cert_path} /etc/pki/ca-trust/source/anchors/dive25-rootCA.crt && update-ca-trust extract" &>/dev/null
  
  # Verify trust
  if verify_cert_trust "${container_name}"; then
    success "Certificate successfully installed in ${container_name}"
    return 0
  else
    warning "Certificate installation in ${container_name} could not be verified"
    return 1
  fi
}

# Function to handle specialized containers like Keycloak, Node.js, etc.
handle_special_container() {
  local container_name="$1"
  local service_name="$2"
  
  case "${service_name}" in
    keycloak)
      # Copy to standard locations and Java keystore locations
      docker cp "$CERTS_DIR/rootCA.pem" "${container_name}:/tmp/dive25-rootCA.crt" 2>/dev/null
      docker exec "${container_name}" sh -c "mkdir -p /tmp/certs" 2>/dev/null
      docker cp "$CERTS_DIR/rootCA.pem" "${container_name}:/tmp/certs/dive25-rootCA.pem" 2>/dev/null
      
      # Try to import into Java keystore if keytool is available
      if docker exec "${container_name}" sh -c "command -v keytool" &>/dev/null; then
        # Get Java home
        local java_home=$(docker exec "${container_name}" sh -c "echo \$JAVA_HOME" 2>/dev/null)
        if [ -z "$java_home" ]; then
          java_home="/usr/lib/jvm/default-jvm"  # Fallback
        fi
        
        # Import into Java cacerts
        docker exec "${container_name}" sh -c "keytool -import -trustcacerts -cacerts -storepass changeit -noprompt -alias dive25rootca -file /tmp/dive25-rootCA.crt" &>/dev/null
        
        # Also copy to Keycloak specific location
        docker exec "${container_name}" sh -c "mkdir -p /opt/keycloak/conf/certs" 2>/dev/null
        docker cp "$CERTS_DIR/rootCA.pem" "${container_name}:/opt/keycloak/conf/certs/dive25-rootCA.pem" 2>/dev/null
      fi
      
      # Verify trust
      verify_cert_trust "${container_name}"
      return 0
      ;;
      
    frontend|api|node*)
      # Node.js based containers - set NODE_EXTRA_CA_CERTS
      docker cp "$CERTS_DIR/rootCA.pem" "${container_name}:/tmp/dive25-rootCA.crt" 2>/dev/null
      docker exec "${container_name}" sh -c "mkdir -p /tmp/certs" 2>/dev/null
      docker cp "$CERTS_DIR/rootCA.pem" "${container_name}:/tmp/certs/dive25-rootCA.pem" 2>/dev/null
      
      # Set environment variable if possible
      docker exec "${container_name}" sh -c "export NODE_EXTRA_CA_CERTS=/tmp/certs/dive25-rootCA.pem" &>/dev/null
      
      # For npm/node containers, try to use update-ca-certificates if available
      if docker exec "${container_name}" sh -c "command -v update-ca-certificates" &>/dev/null; then
        docker exec "${container_name}" sh -c "cp /tmp/dive25-rootCA.crt /usr/local/share/ca-certificates/ && update-ca-certificates" &>/dev/null
      fi
      
      # Verify trust
      verify_cert_trust "${container_name}"
      return 0
      ;;
      
    kong)
      # Kong uses OpenResty/Nginx - try various methods
      docker cp "$CERTS_DIR/rootCA.pem" "${container_name}:/tmp/dive25-rootCA.crt" 2>/dev/null
      docker exec "${container_name}" sh -c "mkdir -p /tmp/certs" 2>/dev/null
      docker cp "$CERTS_DIR/rootCA.pem" "${container_name}:/tmp/certs/dive25-rootCA.pem" 2>/dev/null
      
      # Try standard system methods first
      if docker exec "${container_name}" sh -c "command -v update-ca-certificates" &>/dev/null; then
        docker exec "${container_name}" sh -c "cp /tmp/dive25-rootCA.crt /usr/local/share/ca-certificates/ && update-ca-certificates" &>/dev/null
      elif docker exec "${container_name}" sh -c "command -v update-ca-trust" &>/dev/null; then
        docker exec "${container_name}" sh -c "cp /tmp/dive25-rootCA.crt /etc/pki/ca-trust/source/anchors/ && update-ca-trust extract" &>/dev/null
      fi
      
      # Also try Kong specific location
      docker exec "${container_name}" sh -c "mkdir -p /usr/local/kong/ssl" 2>/dev/null
      docker cp "$CERTS_DIR/rootCA.pem" "${container_name}:/usr/local/kong/ssl/dive25-rootCA.pem" 2>/dev/null
      
      # Verify trust
      verify_cert_trust "${container_name}"
      return 0
      ;;
  esac
  
  return 1  # Container wasn't handled by special cases
}

# Function to detect container OS and install certificate accordingly
distribute_cert_to_container() {
  local container_name="$1"
  local service_name="$2"
  
  # Skip if container is known to be problematic
  case "${service_name}" in
    curl-tools)
      debug "Skipping certificate installation for curl-tools container"
      return 0
      ;;
  esac
  
  # First try specialized handlers for known container types
  if handle_special_container "${container_name}" "${service_name}"; then
    debug "Used specialized handler for ${service_name}"
    return 0
  fi
  
  # Check if container has a shell
  if ! docker exec "${container_name}" sh -c "echo test" >/dev/null 2>&1; then
    warning "Container ${container_name} doesn't have a standard shell. Using direct copy method."
    
    # Copy certificate to multiple possible locations
    docker cp "$CERTS_DIR/rootCA.pem" "${container_name}:/tmp/dive25-rootCA.crt" 2>/dev/null
    docker exec "${container_name}" sh -c "mkdir -p /tmp/certs" 2>/dev/null
    docker cp "$CERTS_DIR/rootCA.pem" "${container_name}:/tmp/certs/dive25-rootCA.pem" 2>/dev/null
    
    # Try common certificate locations
    for cert_dir in "/usr/local/share/ca-certificates" "/etc/ssl/certs" "/etc/pki/ca-trust/source/anchors"; do
      docker cp "$CERTS_DIR/rootCA.pem" "${container_name}:${cert_dir}/dive25-rootCA.crt" 2>/dev/null
    done
    
    debug "Copied certificate to multiple locations in ${container_name}"
    return 0
  fi
  
  # Detect OS and use appropriate method
  if docker exec "${container_name}" sh -c "command -v apk" &>/dev/null; then
    # Alpine-based
    install_cert_alpine "${container_name}"
  elif docker exec "${container_name}" sh -c "command -v apt-get" &>/dev/null; then
    # Debian/Ubuntu-based
    install_cert_debian "${container_name}"
  elif docker exec "${container_name}" sh -c "command -v yum" &>/dev/null || \
       docker exec "${container_name}" sh -c "command -v dnf" &>/dev/null; then
    # RedHat/CentOS-based
    install_cert_redhat "${container_name}"
  else
    # Unknown OS, try general approach
    warning "Unknown OS in ${container_name}, trying general approach"
    
    # Copy certificate to multiple locations
    docker cp "$CERTS_DIR/rootCA.pem" "${container_name}:/tmp/dive25-rootCA.crt" 2>/dev/null
    docker exec "${container_name}" sh -c "mkdir -p /tmp/certs" 2>/dev/null
    docker cp "$CERTS_DIR/rootCA.pem" "${container_name}:/tmp/certs/dive25-rootCA.pem" 2>/dev/null
    
    # If update-ca-certificates is available, use it
    if docker exec "${container_name}" sh -c "command -v update-ca-certificates" &>/dev/null; then
      docker exec "${container_name}" sh -c "mkdir -p /usr/local/share/ca-certificates/ && cp /tmp/dive25-rootCA.crt /usr/local/share/ca-certificates/ && update-ca-certificates" &>/dev/null
    else
      # Try to copy to common certificate locations
      for cert_dir in "/usr/local/share/ca-certificates" "/etc/ssl/certs" "/etc/pki/ca-trust/source/anchors"; do
        docker exec "${container_name}" sh -c "mkdir -p ${cert_dir} 2>/dev/null && cp /tmp/dive25-rootCA.crt ${cert_dir}/" 2>/dev/null
      done
    fi
    
    # Verify trust
    verify_cert_trust "${container_name}"
  fi
  
  return 0
}

# Main function to distribute CA trust to all containers
distribute_ca_trust() {
  print_header "Distributing CA Trust"
  
  # Check if CA certificate exists
  if [ ! -f "$CERTS_DIR/rootCA.pem" ]; then
    error "Root CA certificate not found at $CERTS_DIR/rootCA.pem"
    return 1
  fi
  
  # List of services to distribute CA trust to
  local services="$@"
  
  if [ -z "$services" ]; then
    # Get all running containers with dive25 prefix
    services=$(docker ps --format '{{.Names}}' | grep "dive25" | sed 's/^dive25-//' | sed 's/^dive25_//')
  fi
  
  print_step "Distributing CA trust to services: $services"
  
  local success_count=0
  local total_services=0
  
  for service in $services; do
    total_services=$((total_services+1))
    show_progress "Distributing CA trust to $service..."
    
    # Skip if container doesn't exist
    local container_name=$(docker ps --format '{{.Names}}' | grep -E "dive25.*${service}$|${service}$" | head -n 1)
    if [ -z "$container_name" ]; then
      warning "Container for service $service not found, skipping"
      continue
    fi
    
    debug "Found container: $container_name for service: $service"
    
    # Distribute certificate to the container
    if distribute_cert_to_container "${container_name}" "${service}"; then
      success "CA trust distributed to $service"
      success_count=$((success_count+1))
    else
      warning "Failed to distribute CA trust to $service"
    fi
  done
  
  # Report results
  if [ $success_count -eq $total_services ]; then
    success "CA trust distributed to all $total_services containers"
    return 0
  else
    warning "CA trust distributed to $success_count out of $total_services containers"
    if [ $success_count -eq 0 ]; then
      return 1
    fi
    return 0
  fi
}

# Execute main function if script is run directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  # Get list of services from command line or use all running containers
  services="$@"
  distribute_ca_trust "$services"
fi 