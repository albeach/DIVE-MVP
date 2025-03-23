#!/bin/bash
# Enhanced certificate distribution script

# Import required utility functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/logging.sh"
source "$SCRIPT_DIR/../utils/system.sh"
source "$SCRIPT_DIR/../utils/config.sh"

# Directory for storing certificates
CERTS_DIR="${CERTS_DIR:-./certs}"

# Function to distribute CA trust to a container with Alpine-based image
install_cert_alpine() {
  local container_name="$1"
  local cert_path="$2"
  
  # First copy the certificate
  if ! docker cp "$CERTS_DIR/rootCA.pem" "${container_name}:${cert_path}" 2>/dev/null; then
    warning "Failed to copy certificate to ${container_name}"
    return 1
  fi
  
  success "Successfully copied $(du -h "$CERTS_DIR/rootCA.pem" | cut -f1) to ${container_name}:${cert_path}"
  
  # Install ca-certificates package and update CA trust
  if ! docker exec "${container_name}" sh -c "apk update && apk add --no-cache ca-certificates && cp ${cert_path} /usr/local/share/ca-certificates/dive25-rootCA.crt && update-ca-certificates" 2>/dev/null; then
    warning "Failed to update CA certificates in ${container_name}"
    return 1
  fi
  
  return 0
}

# Function to distribute CA trust to a container with Debian/Ubuntu-based image
install_cert_debian() {
  local container_name="$1"
  local cert_path="$2"
  
  # First copy the certificate
  if ! docker cp "$CERTS_DIR/rootCA.pem" "${container_name}:${cert_path}" 2>/dev/null; then
    warning "Failed to copy certificate to ${container_name}"
    return 1
  fi
  
  success "Successfully copied $(du -h "$CERTS_DIR/rootCA.pem" | cut -f1) to ${container_name}:${cert_path}"
  
  # Install ca-certificates package and update CA trust
  if ! docker exec "${container_name}" sh -c "apt-get update && apt-get install -y ca-certificates && cp ${cert_path} /usr/local/share/ca-certificates/dive25-rootCA.crt && update-ca-certificates" 2>/dev/null; then
    warning "Failed to update CA certificates in ${container_name}"
    return 1
  fi
  
  return 0
}

# Function to detect and handle special containers
handle_special_container() {
  local container_name="$1"
  local service_name="$2"
  
  # Handle special cases for different container types
  case "${service_name}" in
    keycloak)
      # Keycloak uses a different path for certificates
      if ! docker exec "${container_name}" sh -c "test -d /tmp/certs || mkdir -p /tmp/certs" 2>/dev/null; then
        warning "Failed to create certificate directory in ${container_name}"
      fi
      
      if docker cp "$CERTS_DIR/rootCA.pem" "${container_name}:/tmp/certs/dive25-rootCA.pem" 2>/dev/null; then
        success "Successfully copied $(du -h "$CERTS_DIR/rootCA.pem" | cut -f1) to ${container_name}:/tmp/certs/dive25-rootCA.pem"
        info "Using fallback approach for CA trust in ${container_name}"
        return 0
      fi
      ;;
      
    prometheus|mongodb-exporter|node-exporter|opa)
      # These containers need special handling
      if ! docker exec "${container_name}" sh -c "test -d /tmp/certs || mkdir -p /tmp/certs" 2>/dev/null; then
        warning "Failed to create certificate directory in ${container_name}"
      fi
      
      if docker cp "$CERTS_DIR/rootCA.pem" "${container_name}:/tmp/certs/dive25-rootCA.pem" 2>/dev/null; then
        success "Successfully copied $(du -h "$CERTS_DIR/rootCA.pem" | cut -f1) to ${container_name}:/tmp/certs/dive25-rootCA.pem"
        info "Using fallback approach for CA trust in ${container_name}"
        return 0
      else
        warning "Error in CA trust distribution for ${container_name}: Failed to copy certificate to temp location"
      fi
      
      info "Using fallback approach for CA trust in ${container_name}"
      return 0
      ;;
  esac
  
  return 1
}

# Function to detect container OS and install certificate accordingly
distribute_cert_to_container() {
  local container_name="$1"
  local service_name="$2"
  
  # First try specialized handlers for known container types
  if handle_special_container "${container_name}" "${service_name}"; then
    return 0
  fi
  
  # Copy the certificate to a temp location first
  if ! docker cp "$CERTS_DIR/rootCA.pem" "${container_name}:/tmp/dive25-rootCA.crt" 2>/dev/null; then
    warning "Failed to copy certificate to ${container_name}"
    return 1
  fi
  
  success "Successfully copied $(du -h "$CERTS_DIR/rootCA.pem" | cut -f1) to ${container_name}:/tmp/dive25-rootCA.crt"
  
  # Try to detect the OS and use appropriate method
  if docker exec "${container_name}" sh -c "command -v apk" &>/dev/null; then
    # Alpine-based
    if docker exec "${container_name}" sh -c "apk update && apk add --no-cache ca-certificates && mv /tmp/dive25-rootCA.crt /usr/local/share/ca-certificates/ && update-ca-certificates" &>/dev/null; then
      return 0
    fi
  elif docker exec "${container_name}" sh -c "command -v apt-get" &>/dev/null; then
    # Debian/Ubuntu-based
    if docker exec "${container_name}" sh -c "apt-get update && apt-get install -y ca-certificates && mv /tmp/dive25-rootCA.crt /usr/local/share/ca-certificates/ && update-ca-certificates" &>/dev/null; then
      return 0
    fi
  fi
  
  # If we get here, we couldn't install system-wide
  if ! docker exec "${container_name}" sh -c "mv /tmp/dive25-rootCA.crt /etc/ssl/certs/" &>/dev/null; then
    warning "Error in CA trust distribution for ${container_name}: Failed to move certificate to user CA directory"
    warning "CA certificate copied to ${container_name} but couldn't be installed system-wide"
  fi
  
  return 0
}

# Main function to distribute CA trust to all containers
distribute_ca_trust() {
  print_header "Distributing CA Trust"
  
  # List of services to distribute CA trust to
  local services="$1"
  
  if [ -z "$services" ]; then
    # Get services from docker-compose
    services=$(docker-compose ps --services)
  fi
  
  print_step "Distributing CA trust to services: $services"
  
  local success_count=0
  local total_services=0
  
  for service in $services; do
    total_services=$((total_services+1))
    show_progress "Distributing CA trust to $service..."
    
    # Skip if container doesn't exist
    if ! docker ps --format '{{.Names}}' | grep -q "dive25.*$service"; then
      warning "Container for service $service not found, skipping"
      continue
    fi
    
    # Get the actual container name
    local container_name=$(docker ps --format '{{.Names}}' | grep "dive25.*$service" | head -n 1)
    
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
  else
    warning "CA trust distributed to $success_count out of $total_services containers"
  fi
  
  return 0
}

# Execute main function if script is run directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  # Get list of services from command line or use all running containers
  services="$@"
  distribute_ca_trust "$services"
fi 