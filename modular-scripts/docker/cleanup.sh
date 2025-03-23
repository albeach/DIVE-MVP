#!/bin/bash
# Docker environment cleanup script

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Import required utility functions
source "$SCRIPT_DIR/../utils/logging.sh"
source "$SCRIPT_DIR/../utils/system.sh"
source "$SCRIPT_DIR/../utils/config.sh"

# Defaults
REMOVE_VOLUMES=${1:-false}
REMOVE_IMAGES=${2:-false}
FORCE_CLEAN=${3:-false}
PRESERVE_DATA=${4:-true}

# Function to stop and remove Docker containers
cleanup_docker_containers() {
  print_step "Cleaning up Docker containers"
  
  # Find all containers with the dive25 prefix
  local containers=$(docker ps -a --format '{{.Names}}' | grep "dive25")
  
  if [ -z "$containers" ]; then
    info "No containers to clean up"
    return $E_SUCCESS
  fi
  
  local container_count=$(echo "$containers" | wc -l)
  show_progress "Found $container_count containers to clean up"
  
  # First stop all containers gracefully
  show_progress "Stopping running containers..."
  docker ps --format '{{.Names}}' | grep "dive25" | xargs -r docker stop
  
  # Then remove all containers
  show_progress "Removing containers..."
  docker ps -a --format '{{.Names}}' | grep "dive25" | xargs -r docker rm -f
  
  # Verify containers were removed
  local remaining=$(docker ps -a --format '{{.Names}}' | grep -c "dive25" || true)
  if [ "$remaining" -gt 0 ]; then
    warning "Failed to remove all containers, $remaining still remaining"
    if [ "$FORCE_CLEAN" = "true" ]; then
      show_progress "Forcing removal with system prune..."
      docker system prune -f
    fi
    return $E_GENERAL_ERROR
  fi
  
  success "All containers removed successfully"
  return $E_SUCCESS
}

# Function to remove Docker volumes
cleanup_docker_volumes() {
  if [ "$REMOVE_VOLUMES" != "true" ]; then
    info "Skipping volume cleanup as per user request"
    return $E_SUCCESS
  fi
  
  print_step "Cleaning up Docker volumes"
  
  # Find all volumes with the dive25 prefix
  local volumes=$(docker volume ls -q | grep "dive25")
  
  if [ -z "$volumes" ]; then
    info "No volumes to clean up"
    return $E_SUCCESS
  fi
  
  local volume_count=$(echo "$volumes" | wc -l)
  show_progress "Found $volume_count volumes to clean up"
  
  # If we want to preserve data, back it up first
  if [ "$PRESERVE_DATA" = "true" ]; then
    show_progress "Backing up volume data before removal..."
    
    # Create backup directory
    local backup_dir="$ROOT_DIR/data-backup/$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$backup_dir"
    
    # For each volume, create a temporary container to copy the data
    for volume in $volumes; do
      local tmp_container="backup-$volume"
      docker run --name "$tmp_container" -v "$volume:/data" -d alpine sleep 3600
      docker cp "$tmp_container:/data" "$backup_dir/$volume"
      docker rm -f "$tmp_container"
      success "Backed up volume $volume to $backup_dir/$volume"
    done
    
    info "All volumes backed up to $backup_dir"
  fi
  
  # Remove volumes
  show_progress "Removing volumes..."
  echo "$volumes" | xargs -r docker volume rm
  
  # Verify volumes were removed
  local remaining=$(docker volume ls -q | grep -c "dive25" || true)
  if [ "$remaining" -gt 0 ]; then
    warning "Failed to remove all volumes, $remaining still remaining"
    if [ "$FORCE_CLEAN" = "true" ]; then
      show_progress "Forcing removal with volume prune..."
      docker volume prune -f
    fi
    return $E_GENERAL_ERROR
  fi
  
  success "All volumes removed successfully"
  return $E_SUCCESS
}

# Function to remove Docker networks
cleanup_docker_networks() {
  print_step "Cleaning up Docker networks"
  
  # Find all networks with the dive25 prefix
  local networks=$(docker network ls --format '{{.Name}}' | grep "dive25")
  
  if [ -z "$networks" ]; then
    info "No networks to clean up"
    return $E_SUCCESS
  fi
  
  local network_count=$(echo "$networks" | wc -l)
  show_progress "Found $network_count networks to clean up"
  
  # Remove networks
  for network in $networks; do
    docker network rm "$network" 2>/dev/null || true
  done
  
  # Verify networks were removed
  local remaining=$(docker network ls --format '{{.Name}}' | grep -c "dive25" || true)
  if [ "$remaining" -gt 0 ]; then
    warning "Failed to remove all networks, $remaining still remaining"
    show_progress "Some networks might still be in use by other containers"
    if [ "$FORCE_CLEAN" = "true" ]; then
      show_progress "Forcing removal with system prune..."
      docker system prune -f
    fi
    return $E_GENERAL_ERROR
  fi
  
  success "All networks removed successfully"
  return $E_SUCCESS
}

# Function to remove Docker images
cleanup_docker_images() {
  if [ "$REMOVE_IMAGES" != "true" ]; then
    info "Skipping image cleanup as per user request"
    return $E_SUCCESS
  fi
  
  print_step "Cleaning up Docker images"
  
  # Find all DIVE-related images
  local images=$(docker images --format '{{.Repository}}:{{.Tag}}' | grep -E "dive25|keycloak|kong|opa|curl-tools")
  
  if [ -z "$images" ]; then
    info "No images to clean up"
    return $E_SUCCESS
  fi
  
  local image_count=$(echo "$images" | wc -l)
  show_progress "Found $image_count images to clean up"
  
  # Remove images
  echo "$images" | xargs -r docker rmi || true
  
  # For force clean, also remove dangling images
  if [ "$FORCE_CLEAN" = "true" ]; then
    show_progress "Cleaning up dangling images..."
    docker image prune -f
  fi
  
  success "Image cleanup completed"
  return $E_SUCCESS
}

# Function to clean up host entries in /etc/hosts
cleanup_host_entries() {
  print_step "Cleaning up host entries"
  
  if ! grep -q "# DIVE25 - Added by setup script" /etc/hosts; then
    info "No DIVE25 entries found in /etc/hosts"
    return $E_SUCCESS
  fi
  
  show_progress "Removing DIVE25 entries from /etc/hosts..."
  
  if [ ! -w "/etc/hosts" ]; then
    warning "You don't have permission to write to /etc/hosts"
    warning "Please run the following command to clean up host entries:"
    echo "sudo sed -i.bak '/# DIVE25 - Added by setup script/,/# End of DIVE25 entries/d' /etc/hosts"
    return $E_PERMISSION_DENIED
  fi
  
  # Create a backup
  cp /etc/hosts /etc/hosts.bak.$(date +%Y%m%d%H%M%S)
  
  # Remove DIVE25 entries
  portable_sed '/# DIVE25 - Added by setup script/,/# End of DIVE25 entries/d' /etc/hosts
  
  # Verify entries were removed
  if grep -q "# DIVE25 - Added by setup script" /etc/hosts; then
    warning "Failed to remove DIVE25 entries from /etc/hosts"
    return $E_GENERAL_ERROR
  fi
  
  success "Host entries removed successfully"
  return $E_SUCCESS
}

# Function to remove temporary files and directories
cleanup_temp_files() {
  print_step "Cleaning up temporary files"
  
  # Clean up known temp directories
  local temp_dirs=(
    "/tmp/keycloak-config"
    "/tmp/kong-config"
    "/tmp/oidc-login"
    "/tmp/dive25-certs"
  )
  
  for dir in "${temp_dirs[@]}"; do
    if [ -d "$dir" ]; then
      show_progress "Removing temporary directory: $dir"
      rm -rf "$dir"
    fi
  done
  
  # Clean up any DIVE25-related temp files
  find /tmp -name "dive25-*" -type f -mtime +1 -delete 2>/dev/null || true
  
  success "Temporary files cleanup completed"
  return $E_SUCCESS
}

# Function to perform a deep clean
deep_clean() {
  print_step "Performing Deep Clean"
  
  show_progress "This will remove all DIVE25-related Docker resources and data"
  
  # Ensure containersare stopped and removed
  docker ps -a --format '{{.Names}}' | grep "dive25" | xargs -r docker rm -f
  
  # Use docker-compose down with all removal options
  if [ -f "$ROOT_DIR/docker-compose.yml" ]; then
    show_progress "Running docker-compose down with all cleanup options..."
    (cd "$ROOT_DIR" && docker-compose down --volumes --remove-orphans)
  fi
  
  # Remove volumes
  docker volume ls -q | grep "dive25" | xargs -r docker volume rm
  
  # Remove networks
  docker network ls --format '{{.Name}}' | grep "dive25" | xargs -r docker network rm
  
  # Remove images
  docker images --format '{{.Repository}}:{{.Tag}}' | grep -E "dive25|keycloak|kong|opa|curl-tools" | xargs -r docker rmi
  
  # Remove dangling resources
  show_progress "Running Docker system prune to remove dangling resources..."
  docker system prune -f
  
  # Clean up host entries
  cleanup_host_entries
  
  # Clean up temp files
  cleanup_temp_files
  
  # Remove generated certs
  if [ -d "$ROOT_DIR/certs" ]; then
    show_progress "Removing certificates..."
    rm -rf "$ROOT_DIR/certs/*"
  fi
  
  success "Deep clean completed"
  return $E_SUCCESS
}

# Function to confirm before proceeding
confirm_action() {
  local message="$1"
  local default="${2:-y}"
  
  # Skip confirmation in CI mode or if ACCEPT_ALL is set
  if [ "$CI_MODE" = "true" ] || [ "$ACCEPT_ALL" = "true" ]; then
    return 0
  fi
  
  show_prompt "$message (y/n)" "$default"
  
  local response
  read response
  
  # Normalize response
  response=$(echo "$response" | tr '[:upper:]' '[:lower:]')
  
  # If empty, use default
  if [ -z "$response" ]; then
    response="$default"
  fi
  
  # Check if user confirmed
  if [[ "$response" == "y" || "$response" == "yes" ]]; then
    return 0
  else
    return 1
  fi
}

# Function to clean up the entire Docker environment
cleanup_docker_environment() {
  local remove_volumes=${1:-false}
  local remove_images=${2:-false}
  local force_clean=${3:-false}
  
  # Set global flags
  REMOVE_VOLUMES=$remove_volumes
  REMOVE_IMAGES=$remove_images
  FORCE_CLEAN=$force_clean
  
  # First check if there are any containers or volumes to clean
  local containers=$(docker ps -a --format '{{.Names}}' | grep -c "dive25" || echo "0")
  local volumes=""
  if [ "$REMOVE_VOLUMES" = "true" ]; then
    volumes=$(docker volume ls -q | grep -c "dive25" || echo "0")
  fi
  
  # If no containers and no volumes (or not removing volumes), skip confirmation
  if [ "$containers" = "0" ] && ([ "$REMOVE_VOLUMES" != "true" ] || [ "$volumes" = "0" ]); then
    info "No DIVE25 containers or volumes found to clean up"
    return $E_SUCCESS
  fi
  
  # Ask for confirmation if not already confirmed
  print_header "Docker Environment Cleanup"
  
  if [ "$FAST_MODE" != "true" ] && [ "$CI_MODE" != "true" ] && [ "$ACCEPT_ALL" != "true" ] && [ "$TEST_MODE" != "true" ]; then
    warning "This will stop and remove all DIVE25 containers."
    if [ "$REMOVE_VOLUMES" = "true" ] && [ "$volumes" != "0" ]; then
      warning "It will also REMOVE ALL VOLUMES and DATA."
      if ! confirm_action "This will remove all containers and volumes. Are you sure?" "n"; then
        info "Cleanup cancelled by user"
        return $E_SUCCESS
      fi
    else
      if ! confirm_action "This will stop and remove all containers. Continue?" "y"; then
        info "Cleanup cancelled by user"
        return $E_SUCCESS
      fi
    fi
  fi
  
  # Print cleanup configuration
  print_header "Docker Environment Cleanup"
  echo -e "Configuration:"
  echo -e "  Remove Volumes: ${BOLD}$REMOVE_VOLUMES${RESET}"
  echo -e "  Remove Images: ${BOLD}$REMOVE_IMAGES${RESET}"
  echo -e "  Force Clean: ${BOLD}$FORCE_CLEAN${RESET}"
  echo
  
  # Special handling for deep clean
  if [ "$FORCE_CLEAN" = "true" ] && [ "$REMOVE_VOLUMES" = "true" ] && [ "$REMOVE_IMAGES" = "true" ]; then
    deep_clean
    return $?
  fi
  
  # Stop and remove Docker containers
  cleanup_docker_containers
  
  # Clean up Docker networks
  cleanup_docker_networks
  
  # Clean up Docker volumes if requested
  if [ "$REMOVE_VOLUMES" = "true" ]; then
    cleanup_docker_volumes
  fi
  
  # Clean up Docker images if requested
  if [ "$REMOVE_IMAGES" = "true" ]; then
    cleanup_docker_images
  fi
  
  # Clean up host entries if allowed
  if [ $UID -eq 0 ] || [ -w "/etc/hosts" ]; then
    cleanup_host_entries || true
  fi
  
  # Clean up temporary files
  cleanup_temp_files || true
  
  success "Docker environment cleanup completed"
  return $E_SUCCESS
}

# Main function to clean up the Docker environment
main() {
  # Parse command-line options
  local remove_volumes=false
  local remove_images=false
  local force_clean=false
  local deep_clean=false
  
  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      -v|--volumes)
        remove_volumes=true
        shift
        ;;
      -i|--images)
        remove_images=true
        shift
        ;;
      -f|--force)
        force_clean=true
        shift
        ;;
      -d|--deep)
        deep_clean=true
        remove_volumes=true
        remove_images=true
        force_clean=true
        shift
        ;;
      *)
        warning "Unknown option: $1"
        shift
        ;;
    esac
  done
  
  # Perform the cleanup
  cleanup_docker_environment "$remove_volumes" "$remove_images" "$force_clean"
  return $?
}

# Execute main function if script is run directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi 