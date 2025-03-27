#!/bin/bash
# DIVE25 - Cleanup script
# Responsible for cleaning up the DIVE25 deployment

# Set strict error handling
set -o pipefail

# Get absolute paths
export SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
export LIB_DIR="$ROOT_DIR/lib"

# Default configuration
export DEBUG="false"
export REMOVE_VOLUMES="false"
export REMOVE_IMAGES="false"
export REMOVE_CONFIGS="false"

# Display help information
show_help() {
  echo "DIVE25 - Cleanup Script"
  echo
  echo "Usage: $0 [OPTIONS]"
  echo
  echo "OPTIONS:"
  echo "  -h, --help               Show this help message"
  echo "  -d, --debug              Enable debug output"
  echo "  -v, --volumes            Remove volumes (data will be lost)"
  echo "  -i, --images             Remove Docker images"
  echo "  -c, --configs            Remove configuration files"
  echo "  -a, --all                Remove everything (volumes, images, configs)"
  echo
  echo "Examples:"
  echo "  $0                       Remove containers and networks only"
  echo "  $0 -v                    Remove containers, networks, and volumes"
  echo "  $0 -a                    Remove everything"
}

# Parse command line arguments
parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      -h|--help)
        show_help
        exit 0
        ;;
      -d|--debug)
        export DEBUG="true"
        set -x  # Enable bash trace mode
        shift
        ;;
      -v|--volumes)
        export REMOVE_VOLUMES="true"
        shift
        ;;
      -i|--images)
        export REMOVE_IMAGES="true"
        shift
        ;;
      -c|--configs)
        export REMOVE_CONFIGS="true"
        shift
        ;;
      -a|--all)
        export REMOVE_VOLUMES="true"
        export REMOVE_IMAGES="true"
        export REMOVE_CONFIGS="true"
        shift
        ;;
      *)
        echo "Unknown option: $1"
        show_help
        exit 1
        ;;
    esac
  done
}

# Load all required libraries
load_libraries() {
  # Source the common library first, which will load logging and system
  if [ -f "$LIB_DIR/common.sh" ]; then
    source "$LIB_DIR/common.sh"
  else
    echo "Error: Required libraries not found."
    exit 1
  fi
}

# Main execution function
main() {
  # Parse command line arguments
  parse_arguments "$@"
  
  # Load libraries
  load_libraries
  
  # Display header
  log_header "DIVE25 - Cleanup"
  
  # Confirm cleanup
  if [ "$REMOVE_VOLUMES" = "true" ]; then
    echo "WARNING: You are about to remove all data volumes. This action is irreversible."
    read -p "Are you sure you want to continue? (y/N): " confirm
    if [[ "$confirm" != [yY] ]]; then
      log_info "Aborting cleanup."
      exit 0
    fi
  fi
  
  # Source docker library
  source "$LIB_DIR/docker.sh"
  
  # Perform cleanup
  log_step "Stopping containers"
  stop_docker_containers
  
  log_step "Removing containers and networks"
  remove_docker_containers_and_networks
  
  if [ "$REMOVE_VOLUMES" = "true" ]; then
    log_step "Removing volumes"
    remove_docker_volumes
  fi
  
  if [ "$REMOVE_IMAGES" = "true" ]; then
    log_step "Removing images"
    remove_docker_images
  fi
  
  if [ "$REMOVE_CONFIGS" = "true" ]; then
    log_step "Removing configuration files"
    remove_config_files
  fi
  
  log_success "Cleanup completed!"
  return 0
}

# Stop all Docker containers
stop_docker_containers() {
  log_info "Stopping all DIVE25 containers"
  docker-compose -f "$ROOT_DIR/docker-compose.yml" down --remove-orphans || true
  
  # Additional check for any lingering containers
  local containers=$(docker ps -a --filter "name=dive25" -q)
  if [ -n "$containers" ]; then
    log_info "Stopping additional containers"
    docker stop $containers || true
  fi
}

# Remove Docker containers and networks
remove_docker_containers_and_networks() {
  log_info "Removing all DIVE25 containers"
  
  # Remove any lingering containers
  local containers=$(docker ps -a --filter "name=dive25" -q)
  if [ -n "$containers" ]; then
    docker rm -f $containers || true
  fi
  
  # Remove networks
  log_info "Removing DIVE25 networks"
  local networks=$(docker network ls --filter "name=dive25" -q)
  if [ -n "$networks" ]; then
    docker network rm $networks || true
  fi
}

# Remove Docker volumes
remove_docker_volumes() {
  log_info "Removing all DIVE25 volumes"
  
  local volumes=$(docker volume ls --filter "name=dive25" -q)
  if [ -n "$volumes" ]; then
    docker volume rm $volumes || true
  fi
}

# Remove Docker images
remove_docker_images() {
  log_info "Removing all DIVE25 images"
  
  local images=$(docker images --filter "reference=dive25*" -q)
  if [ -n "$images" ]; then
    docker rmi -f $images || true
  fi
}

# Remove configuration files
remove_config_files() {
  log_info "Removing configuration files"
  
  # Remove .env file
  if [ -f "$ROOT_DIR/.env" ]; then
    rm -f "$ROOT_DIR/.env"
  fi
  
  # Remove generated certificates
  if [ -d "$ROOT_DIR/certs" ]; then
    rm -rf "$ROOT_DIR/certs"/*
  fi
  
  # Remove any other temporary files
  rm -f "$ROOT_DIR/*.bak" "$ROOT_DIR/*.backup.*" || true
}

# Execute main function
main "$@"
exit $? 