#!/bin/bash
# Common system utilities and error handling

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Import logging utilities
source "$SCRIPT_DIR/logging.sh"

# Error code definitions for standardized error handling
if [[ -z "${E_SUCCESS+x}" ]]; then
  declare -r E_SUCCESS=0
  declare -r E_GENERAL_ERROR=1
  declare -r E_INVALID_ARGS=2
  declare -r E_RESOURCE_NOT_FOUND=3
  declare -r E_NETWORK_ERROR=4
  declare -r E_PERMISSION_DENIED=5
  declare -r E_TIMEOUT=6
  declare -r E_DEPENDENCY_MISSING=7
  declare -r E_CONFIG_ERROR=8
fi

# Container name cache to avoid repeated lookups
# Use simple variables instead of associative array for older bash versions
_CONTAINER_CACHE=""

# Function to get a cached container name
get_cached_container() {
  local key=$1
  if [[ "$_CONTAINER_CACHE" == *"|$key:"* ]]; then
    echo "$_CONTAINER_CACHE" | grep -o "|$key:[^|]*" | cut -d: -f2
    return 0
  fi
  return 1
}

# Function to set a cached container name
set_cached_container() {
  local key=$1
  local value=$2
  # Add or update the cache
  if [[ "$_CONTAINER_CACHE" == *"|$key:"* ]]; then
    # Replace existing entry
    _CONTAINER_CACHE=$(echo "$_CONTAINER_CACHE" | sed "s/|$key:[^|]*|/|$key:$value|/g")
  else
    # Add new entry
    _CONTAINER_CACHE="${_CONTAINER_CACHE}|$key:$value|"
  fi
}

# Function for platform-independent sed usage
portable_sed() {
  local pattern=$1
  local file=$2
  
  # Check which platform we're on and use the appropriate sed command
  if [ "$(uname)" == "Darwin" ]; then
    # macOS version needs an empty string for -i
    sed -i '' "$pattern" "$file"
  else
    # Linux version doesn't need the empty string
    sed -i "$pattern" "$file"
  fi
}

# Function to display elapsed time in a human-readable format
print_elapsed_time() {
  local seconds=$1
  local minutes=$((seconds / 60))
  local hours=$((minutes / 60))
  
  seconds=$((seconds % 60))
  minutes=$((minutes % 60))
  
  if [ $hours -gt 0 ]; then
    echo -e "${BLUE}Total execution time: ${BOLD}${hours}h ${minutes}m ${seconds}s${RESET}"
  elif [ $minutes -gt 0 ]; then
    echo -e "${BLUE}Total execution time: ${BOLD}${minutes}m ${seconds}s${RESET}"
  else
    echo -e "${BLUE}Total execution time: ${BOLD}${seconds}s${RESET}"
  fi
}

# Function for improved error handling
handle_error() {
  local exit_code=$1
  local operation=$2
  local fail_action=${3:-"continue"}  # Options: continue, exit, retry
  local retry_count=${4:-3}           # Default max retries
  
  if [ $exit_code -ne 0 ]; then
    error "$operation failed with exit code $exit_code"
    
    case $fail_action in
      exit)
        error "Exiting script due to critical error in: $operation"
        exit $exit_code
        ;;
      retry)
        if [ $retry_count -gt 0 ]; then
          warning "Retrying operation ($((4-retry_count))/3): $operation"
          return 2  # Signal to retry
        else
          error "Maximum retry attempts reached for: $operation"
          return 1  # Signal to stop retrying
        fi
        ;;
      continue|*)
        warning "Continuing despite error in: $operation"
        return 1
        ;;
    esac
  fi
  
  return 0
}

# Function to standardized timeout handling
wait_with_timeout() {
  local operation=$1
  local timeout=$2
  local check_cmd=$3
  
  local start_time=$(date +%s)
  local iteration=0
  
  show_progress "Waiting for: $operation (timeout: ${timeout}s)"
  
  while true; do
    # Run the check command
    if eval "$check_cmd"; then
      success "$operation is now available"
      return 0
    fi
    
    # Check for timeout
    local current_time=$(date +%s)
    local elapsed=$((current_time - start_time))
    
    if [ $elapsed -ge $timeout ]; then
      warning "Timeout after ${elapsed}s waiting for: $operation"
      return 1
    fi
    
    # Show progress every 5 iterations
    iteration=$((iteration + 1))
    if [ $((iteration % 5)) -eq 0 ]; then
      echo -e "${YELLOW}${EMOJI_HOURGLASS} Still waiting for $operation... (${elapsed}s elapsed)${RESET}"
    fi
    
    # Adaptive sleep: shorter at the beginning, longer after waiting a while
    if [ $elapsed -lt 30 ]; then
      sleep 2  # Fast polling initially
    else
      sleep 5  # Slower polling after 30 seconds
    fi
  done
}

# Function to check if a command exists
command_exists() {
  type "$1" >/dev/null 2>&1
}

# Improved function to get user input more reliably and consistently
get_input() {
  local prompt=$1
  local default=$2
  local response
  
  # Display a clear user input marker
  echo -e "\n${BOLD}${WHITE}========== USER INPUT REQUIRED ===========${RESET}"
  
  # Temporarily disable the ALRM trap to prevent interruptions
  local old_trap
  old_trap=$(trap -p ALRM | sed -e "s/^trap -- '\(.*\)' ALRM$/\1/")
  trap '' ALRM
  
  # Display the prompt with the default value
  echo -en "${BOLD}${CYAN}>>> $prompt${RESET} [${default}]: "
  
  # Read the input into a separate variable
  read response
  
  # Re-enable the original ALRM trap
  trap "$old_trap" ALRM
  
  # Use default if no input provided
  if [ -z "$response" ]; then
    echo "$default"
  else
    # Trim whitespace but preserve internal spaces
    response=$(echo "$response" | xargs)
    echo "$response"
  fi
}

# Start timer to track execution time
start_timer() {
  export START_TIME=$(date +%s)
}

# Show container logs summary 
show_container_summary() {
  echo -e "\n${BLUE}${BOLD}==== Container Status Summary =====${RESET}"
  docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
  echo -e "\n${YELLOW}Check container logs with: docker logs <container_name>${RESET}"
}

# Function to check Docker Compose service health
check_compose_health() {
  local expected_containers="$1"
  local container_prefix="${2:-}"
  local timeout="${3:-120}"
  
  print_step "Checking Docker Compose Health"
  
  show_progress "Waiting for Docker services to be healthy..."
  
  # Start timer
  local start_time=$(date +%s)
  local end_time=$((start_time + timeout))
  local current_time=$start_time
  
  # Continue checking until timeout
  while [ $current_time -lt $end_time ]; do
    # Get list of all containers
    local all_containers=$(docker ps -a --format '{{.Names}}' | grep "${container_prefix}" | wc -l)
    
    # Get list of healthy containers
    local running_containers=$(docker ps --format '{{.Names}}' | grep "${container_prefix}" | wc -l)
    # Use fixed grep patterns to avoid parentheses balancing issues
    local healthy_containers=$(docker ps --format '{{.Names}}{{.Status}}' | grep -E "${container_prefix}.*healthy" | grep -v "unhealthy" | wc -l)
    local no_health_check=$(docker ps --format '{{.Names}}{{.Status}}' | grep -E "${container_prefix}" | grep -v "healthy" | grep -v "health" | wc -l)
    
    # Calculate total healthy containers (including those without health checks)
    local total_healthy=$((healthy_containers + no_health_check))
    
    # If we have an expected count, check against it
    if [ -n "$expected_containers" ] && [ "$expected_containers" -gt 0 ]; then
      local target_count=$expected_containers
    else
      local target_count=$all_containers
    fi
    
    # Debug info
    debug "Current state: $total_healthy/$target_count containers ready"
    debug "Running: $running_containers, Healthy: $healthy_containers, No health check: $no_health_check"
    
    # Check if we've reached the target
    if [ "$total_healthy" -ge "$target_count" ]; then
      # Check for unhealthy containers
      local unhealthy_containers=$(docker ps --format '{{.Names}}{{.Status}}' | grep -E "${container_prefix}.*unhealthy" | wc -l)
      if [ "$unhealthy_containers" -gt 0 ]; then
        warning "Some containers are in unhealthy state"
        # List unhealthy containers
        docker ps --format '{{.Names}}{{.Status}}' | grep -E "${container_prefix}.*unhealthy"
      fi
      
      success "All $total_healthy containers are ready"
      return $E_SUCCESS
    fi
    
    # Wait and update current time
    sleep 5
    current_time=$(date +%s)
    
    # Show progress every 15 seconds
    if [ $((current_time - start_time)) -gt 0 ] && [ $(((current_time - start_time) % 15)) -eq 0 ]; then
      local elapsed=$((current_time - start_time))
      local remain=$((end_time - current_time))
      local percent=$(( (elapsed * 100) / timeout ))
      show_progress "[$percent%] $total_healthy/$target_count containers ready - $remain seconds remaining..."
    fi
  done
  
  # If we get here, we've timed out
  warning "Timeout reached waiting for containers to be healthy"
  warning "Current state: $total_healthy/$target_count containers ready"
  
  # Show status of all containers
  echo "Current container status:"
  docker ps -a
  
  return $E_TIMEOUT
}

# Function to get OS type
get_os_type() {
  case "$(uname -s)" in
    Linux*)     echo "linux";;
    Darwin*)    echo "darwin";;
    CYGWIN*)    echo "windows";;
    MINGW*)     echo "windows";;
    *)          echo "unknown";;
  esac
}

# Function to get container name from service name
get_container_name() {
  local service_name="$1"
  local prefix="${2:-dive25}"
  local exclude_pattern="${3:-NONEXISTINGPATTERN}"
  
  # Check if we have this container name in our cache
  local cache_key="${prefix}_${service_name}_${exclude_pattern}"
  local cached_value=$(get_cached_container "$cache_key")
  
  if [ -n "$cached_value" ]; then
    debug "Using cached container name: $cached_value for $service_name"
    echo "$cached_value"
    return 0
  fi
  
  # First try simple name pattern with possible environment prefixes
  local container_name=""
  
  # Try direct match based on convention (preferred)
  container_name=$(docker ps --format '{{.Names}}' | grep -E "${prefix}(-[^-]+)?-${service_name}$" | grep -v "$exclude_pattern" | head -n 1)
  
  # If not found, try looser pattern
  if [ -z "$container_name" ]; then
    container_name=$(docker ps --format '{{.Names}}' | grep -E "${service_name}" | grep -v "$exclude_pattern" | head -n 1)
  fi
  
  # Cache the result
  if [ -n "$container_name" ]; then
    set_cached_container "$cache_key" "$container_name"
  fi
  
  echo "$container_name"
  
  # Return success if container found, error otherwise
  [ -n "$container_name" ] && return 0 || return $E_RESOURCE_NOT_FOUND
}

# Function to clear container name cache
clear_container_name_cache() {
  debug "Clearing container name cache"
  # Reset the simple string-based cache instead of using associative array
  _CONTAINER_CACHE=""
}

# Function to start docker-compose with a specific compose file and environment
start_docker_services() {
  local compose_file="${1:-docker-compose.yml}"
  local env_file="${2:-.env}"
  local services="${3:-}"
  
  print_step "Starting Docker Services"
  
  if [ ! -f "$compose_file" ]; then
    error "Compose file not found: $compose_file"
    return $E_RESOURCE_NOT_FOUND
  fi
  
  if [ ! -f "$env_file" ]; then
    warning "Environment file not found: $env_file"
    warning "Using default environment variables"
  fi
  
  show_progress "Starting Docker services..."
  
  # Prepare the docker-compose command
  local cmd="docker-compose -f $compose_file"
  
  # Add environment file if it exists
  if [ -f "$env_file" ]; then
    cmd="$cmd --env-file $env_file"
  fi
  
  # Add services if specified
  if [ -n "$services" ]; then
    cmd="$cmd up -d $services"
  else
    cmd="$cmd up -d"
  fi
  
  # Execute the command
  debug "Executing: $cmd"
  
  if eval "$cmd"; then
    success "Docker services started successfully"
    # Clear container name cache after starting new containers
    clear_container_name_cache
    return $E_SUCCESS
  else
    error "Failed to start Docker services"
    return $E_GENERAL_ERROR
  fi
}

# Function to get service information from Docker
get_service_info() {
  local service_name="$1"
  local info_type="${2:-ip}"
  
  local container_name=$(get_container_name "$service_name")
  
  if [ -z "$container_name" ]; then
    warning "Could not find container for service '$service_name'"
    return $E_RESOURCE_NOT_FOUND
  fi
  
  case "$info_type" in
    ip)
      docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$container_name" 2>/dev/null
      ;;
    network)
      docker inspect -f '{{range $key, $value := .NetworkSettings.Networks}}{{$key}}{{end}}' "$container_name" 2>/dev/null
      ;;
    ports)
      docker inspect -f '{{range $p, $conf := .NetworkSettings.Ports}}{{$p}}{{end}}' "$container_name" 2>/dev/null
      ;;
    running)
      docker inspect -f '{{.State.Running}}' "$container_name" 2>/dev/null
      ;;
    health)
      docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$container_name" 2>/dev/null
      ;;
    *)
      warning "Unknown info type: $info_type"
      return $E_INVALID_ARGS
      ;;
  esac
  
  return $E_SUCCESS
}

# Function to check Docker requirements
check_docker_requirements() {
  print_step "Checking System Requirements"
  show_progress "Verifying installed dependencies..."
  
  if ! command_exists docker; then
    error "Docker is not installed. Please install Docker first."
    return $E_DEPENDENCY_MISSING
  fi
  success "Docker is installed"
  
  if ! command_exists docker-compose; then
    error "docker-compose is not installed. Please install docker-compose first."
    return $E_DEPENDENCY_MISSING
  fi
  success "Docker Compose is installed"
  
  # Check Docker daemon is running
  if ! docker info >/dev/null 2>&1; then
    error "Docker daemon is not running. Please start Docker daemon first."
    return $E_DEPENDENCY_MISSING
  fi
  success "Docker daemon is running"
  
  return $E_SUCCESS
}

# Main function for testing
main() {
  check_docker_requirements
  
  if [ $? -ne 0 ]; then
    error "System requirements not met."
    return $E_DEPENDENCY_MISSING
  fi
  
  success "System requirements check passed."
  return $E_SUCCESS
}

# Execute main function if script is run directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi 