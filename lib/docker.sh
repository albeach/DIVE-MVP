#!/bin/bash
# DIVE25 - Docker utilities library
# Handles Docker container and service management

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source common library if not already sourced
if [ -z "${log_info+x}" ]; then
  source "$SCRIPT_DIR/common.sh"
fi

# Function to clean up Docker environment
cleanup_docker_environment() {
  local remove_volumes="${1:-false}"
  local remove_images="${2:-false}"
  
  log_step "Cleaning up Docker environment"
  
  # Stop all containers
  log_progress "Stopping containers..."
  ENVIRONMENT=${ENVIRONMENT} docker-compose -f "$ROOT_DIR/docker-compose.yml" down --remove-orphans || true
  
  # Find any lingering dive25 containers
  local containers=$(docker ps -a --filter "name=dive25" -q)
  if [ -n "$containers" ]; then
    log_progress "Stopping additional containers..."
    docker stop $containers 2>/dev/null || true
    log_progress "Removing containers..."
    docker rm -f $containers 2>/dev/null || true
  fi
  
  # Remove networks
  log_progress "Removing networks..."
  local networks=$(docker network ls --filter "name=dive25" -q)
  if [ -n "$networks" ]; then
    docker network rm $networks 2>/dev/null || true
  fi
  
  # Optionally remove volumes
  if [ "$remove_volumes" = "true" ]; then
    log_progress "Removing volumes..."
    local volumes=$(docker volume ls --filter "name=dive25" -q)
    if [ -n "$volumes" ]; then
      docker volume rm $volumes 2>/dev/null || true
    fi
  fi
  
  # Optionally remove images
  if [ "$remove_images" = "true" ]; then
    log_progress "Removing images..."
    local images=$(docker images --filter "reference=dive25*" -q)
    if [ -n "$images" ]; then
      docker rmi -f $images 2>/dev/null || true
    fi
  fi
  
  log_success "Docker environment cleaned up"
  return $E_SUCCESS
}

# Function to start Docker services
start_docker_services() {
  local compose_file="${1:-docker-compose.yml}"
  local env_file="${2:-.env}"
  local detached="${3:-true}"
  
  log_step "Starting Docker services"
  
  # Check if docker-compose file exists
  if [ ! -f "$ROOT_DIR/$compose_file" ]; then
    log_error "Docker Compose file not found: $ROOT_DIR/$compose_file"
    return $E_RESOURCE_NOT_FOUND
  fi
  
  # Check if environment file exists
  if [ ! -f "$ROOT_DIR/$env_file" ]; then
    log_warning "Environment file not found: $ROOT_DIR/$env_file"
    log_info "Proceeding without environment file..."
  fi
  
  # Start the services
  log_progress "Starting Docker services using $compose_file..."
  
  if [ "$detached" = "true" ]; then
    if [ -f "$ROOT_DIR/$env_file" ]; then
      ENVIRONMENT=${ENVIRONMENT} docker-compose -f "$ROOT_DIR/$compose_file" --env-file "$ROOT_DIR/$env_file" up -d
    else
      ENVIRONMENT=${ENVIRONMENT} docker-compose -f "$ROOT_DIR/$compose_file" up -d
    fi
  else
    if [ -f "$ROOT_DIR/$env_file" ]; then
      ENVIRONMENT=${ENVIRONMENT} docker-compose -f "$ROOT_DIR/$compose_file" --env-file "$ROOT_DIR/$env_file" up
    else
      ENVIRONMENT=${ENVIRONMENT} docker-compose -f "$ROOT_DIR/$compose_file" up
    fi
  fi
  
  local result=$?
  if [ $result -ne 0 ]; then
    log_error "Failed to start Docker services"
    return $E_GENERAL_ERROR
  fi
  
  log_success "Docker services started"
  return $E_SUCCESS
}

# Function to check health of Docker services
check_docker_health() {
  local compose_file="${1:-docker-compose.yml}"
  local timeout="${2:-120}"  # 2 minute timeout
  
  log_step "Checking health of Docker services"
  
  # Check if docker-compose file exists
  if [ ! -f "$ROOT_DIR/$compose_file" ]; then
    log_error "Docker Compose file not found: $ROOT_DIR/$compose_file"
    return $E_RESOURCE_NOT_FOUND
  fi
  
  # Start timer
  local start_time=$(date +%s)
  local elapsed=0
  
  # Keep checking until all services are healthy or timeout
  log_progress "Waiting for services to become healthy..."
  
  while [ $elapsed -lt $timeout ]; do
    # Get all containers defined in docker-compose file
    local containers=$(ENVIRONMENT=${ENVIRONMENT} docker-compose -f "$ROOT_DIR/$compose_file" ps -q)
    local unhealthy=()
    
    # No containers running yet, wait and retry
    if [ -z "$containers" ]; then
      log_progress "No containers running yet, waiting..."
      sleep 5
      elapsed=$(($(date +%s) - start_time))
      continue
    fi
    
    local all_ready=true
    
    # Check each container
    for container in $containers; do
      # Get container status and health
      local status=$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null)
      local health=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$container" 2>/dev/null)
      local name=$(docker inspect --format='{{.Name}}' "$container" 2>/dev/null)
      
      # Check if container is running
      if [ "$status" != "running" ]; then
        unhealthy+=("$name (status: $status)")
        all_ready=false
      # Check if container has health check and if it's healthy
      elif [ "$health" != "healthy" ] && [ "$health" != "none" ]; then
        unhealthy+=("$name (health: $health)")
        all_ready=false
      fi
    done
    
    # If all containers are healthy, we're done
    if [ "$all_ready" = "true" ]; then
      log_success "All services are healthy"
      return $E_SUCCESS
    fi
    
    # Log progress and wait for next check
    log_progress "Waiting for unhealthy containers: ${unhealthy[*]}"
    sleep 5
    elapsed=$(($(date +%s) - start_time))
  done
  
  log_error "Timeout waiting for services to become healthy"
  return $E_TIMEOUT
}

# Function to ensure curl-tools container for testing and API requests
ensure_curl_tools() {
  local packages="${1:-"curl jq bash"}"
  local name="dive25-curl-tools"
  
  log_debug "Ensuring curl-tools container is available"
  
  # Check if container exists and is running
  if docker ps --format '{{.Names}}' | grep -q "$name"; then
    log_debug "curl-tools container is already running"
    echo "$name"
    return $E_SUCCESS
  fi
  
  # Check if container exists but is not running
  if docker ps -a --format '{{.Names}}' | grep -q "$name"; then
    log_debug "Starting existing curl-tools container"
    docker start "$name" >/dev/null 2>&1
    echo "$name"
    return $E_SUCCESS
  fi
  
  # Create new container
  log_debug "Creating new curl-tools container"
  docker run -d --name "$name" --network host alpine:latest \
    sh -c "apk add --no-cache $packages && sleep 3600" >/dev/null 2>&1
  
  if [ $? -ne 0 ]; then
    log_error "Failed to create curl-tools container"
    return $E_GENERAL_ERROR
  fi
  
  echo "$name"
  return $E_SUCCESS
}

# Function to execute command in a container
exec_in_container() {
  local container="$1"
  local command="$2"
  
  log_debug "Executing in container $container: $command"
  
  docker exec "$container" sh -c "$command"
  return $?
}

# Function to copy file to container
copy_to_container() {
  local source_file="$1"
  local container="$2"
  local dest_path="$3"
  
  log_debug "Copying $source_file to $container:$dest_path"
  
  docker cp "$source_file" "$container:$dest_path"
  return $?
}

# Function to copy file from container
copy_from_container() {
  local container="$1"
  local source_path="$2"
  local dest_file="$3"
  
  log_debug "Copying $container:$source_path to $dest_file"
  
  docker cp "$container:$source_path" "$dest_file"
  return $?
}

# Function to check if Docker Compose is version 2
is_docker_compose_v2() {
  if docker compose version >/dev/null 2>&1; then
    return 0
  else
    return 1
  fi
}

# Function to run docker-compose command
run_docker_compose() {
  local command="${1:-ps}"
  local compose_file="${2:-docker-compose.yml}"
  local env_file="${3:-.env}"
  
  log_debug "Running docker-compose $command"
  
  if [ -f "$ROOT_DIR/$compose_file" ]; then
    if [ -f "$ROOT_DIR/$env_file" ]; then
      ENVIRONMENT=${ENVIRONMENT} docker-compose -f "$ROOT_DIR/$compose_file" --env-file "$ROOT_DIR/$env_file" $command
    else
      ENVIRONMENT=${ENVIRONMENT} docker-compose -f "$ROOT_DIR/$compose_file" $command
    fi
  fi
  
  return $?
}

# Export all functions to make them available to sourcing scripts
export -f cleanup_docker_environment
export -f start_docker_services
export -f check_docker_health
export -f ensure_curl_tools
export -f exec_in_container
export -f copy_to_container
export -f copy_from_container
export -f is_docker_compose_v2
export -f run_docker_compose 