#!/bin/bash
# DIVE25 - System library
# Contains system operation functions and error constants

# Error code definitions
if [ -z "${E_SUCCESS+x}" ]; then declare -r E_SUCCESS=0; fi
if [ -z "${E_GENERAL_ERROR+x}" ]; then declare -r E_GENERAL_ERROR=1; fi
if [ -z "${E_INVALID_ARGS+x}" ]; then declare -r E_INVALID_ARGS=2; fi
if [ -z "${E_RESOURCE_NOT_FOUND+x}" ]; then declare -r E_RESOURCE_NOT_FOUND=3; fi
if [ -z "${E_NETWORK_ERROR+x}" ]; then declare -r E_NETWORK_ERROR=4; fi
if [ -z "${E_PERMISSION_DENIED+x}" ]; then declare -r E_PERMISSION_DENIED=5; fi
if [ -z "${E_TIMEOUT+x}" ]; then declare -r E_TIMEOUT=6; fi
if [ -z "${E_DEPENDENCY_MISSING+x}" ]; then declare -r E_DEPENDENCY_MISSING=7; fi
if [ -z "${E_CONFIG_ERROR+x}" ]; then declare -r E_CONFIG_ERROR=8; fi

# Define required commands with fallback paths
OPENSSL=${OPENSSL:-$(which openssl)}
CURL=${CURL:-$(which curl)}
DOCKER=${DOCKER:-$(which docker)}
DOCKER_COMPOSE=${DOCKER_COMPOSE:-$(which docker-compose)}
JQ=${JQ:-$(which jq)}
SED=${SED:-$(which sed)}
GREP=${GREP:-$(which grep)}
AWK=${AWK:-$(which awk)}

# Timer for operation duration tracking
START_TIME=$(date +%s)

# Maximum retries for operations
MAX_RETRIES=${MAX_RETRIES:-10}
RETRY_INTERVAL=${RETRY_INTERVAL:-5}

# Function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Function to check required tools and dependencies
check_dependencies() {
  local dependencies=("$@")
  local missing=()
  
  for dependency in "${dependencies[@]}"; do
    if ! command_exists "$dependency"; then
      missing+=("$dependency")
    fi
  done
  
  if [ ${#missing[@]} -gt 0 ]; then
    return $E_DEPENDENCY_MISSING
  fi
  
  return $E_SUCCESS
}

# Function to check if Docker and Docker Compose are installed
check_docker_requirements() {
  local errors=0
  
  # Check for docker
  if ! command_exists "docker"; then
    errors=$((errors+1))
    return $E_DEPENDENCY_MISSING
  fi
  
  # Check for docker-compose
  if ! command_exists "docker-compose"; then
    errors=$((errors+1))
    return $E_DEPENDENCY_MISSING
  fi
  
  # Verify docker is running
  if ! docker info >/dev/null 2>&1; then
    errors=$((errors+1))
    return $E_DEPENDENCY_MISSING
  fi
  
  return $E_SUCCESS
}

# Function to check if a port is in use
is_port_in_use() {
  local port=$1
  
  if command_exists "lsof"; then
    lsof -i:"$port" >/dev/null 2>&1
    return $?
  elif command_exists "netstat"; then
    netstat -tuln | grep -q ":${port} "
    return $?
  else
    # Fallback to attempting a connection
    (echo > /dev/tcp/127.0.0.1/$port) >/dev/null 2>&1
    return $?
  fi
}

# Function to wait for a port to become available
wait_for_port() {
  local host="$1"
  local port="$2"
  local timeout="${3:-60}"
  local interval="${4:-1}"
  
  local elapsed=0
  local start_time=$(date +%s)
  
  while [ "$elapsed" -lt "$timeout" ]; do
    if (echo > /dev/tcp/$host/$port) >/dev/null 2>&1; then
      return $E_SUCCESS
    fi
    
    sleep "$interval"
    elapsed=$(($(date +%s) - start_time))
  done
  
  return $E_TIMEOUT
}

# Function to check if a URL is accessible
check_url_accessible() {
  local url="$1"
  local timeout="${2:-10}"
  local expected_status="${3:-200}"
  
  if ! command_exists "curl"; then
    return $E_DEPENDENCY_MISSING
  fi
  
  local status_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout "$timeout" "$url")
  
  if [ "$status_code" == "$expected_status" ]; then
    return $E_SUCCESS
  else
    return $E_NETWORK_ERROR
  fi
}

# Function to check if host entries exist
check_hosts_entries() {
  local domains=("$@")
  
  for domain in "${domains[@]}"; do
    if ! grep -q "$domain" /etc/hosts; then
      return $E_RESOURCE_NOT_FOUND
    fi
  done
  
  return $E_SUCCESS
}

# Function to update /etc/hosts file (requires sudo)
update_hosts_file() {
  local ip=${1:-"127.0.0.1"}
  shift
  local domains=("$@")
  
  # Check if we have permission to write to /etc/hosts
  if [ ! -w "/etc/hosts" ]; then
    return $E_PERMISSION_DENIED
  fi
  
  # Add each domain to the hosts file if not already present
  for domain in "${domains[@]}"; do
    if ! grep -q "$domain" /etc/hosts; then
      echo "$ip $domain" >> /etc/hosts
    fi
  done
  
  return $E_SUCCESS
}

# Function for portable sed usage (macOS compatibility)
portable_sed() {
  local pattern="$1"
  local file="$2"
  
  if [[ -z "$pattern" || -z "$file" ]]; then
    log_error "Missing pattern or file for sed operation"
    return $E_INVALID_ARGS
  fi
  
  if [ ! -f "$file" ]; then
    log_error "File not found for sed operation: $file"
    return $E_RESOURCE_NOT_FOUND
  fi
  
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS requires -i '' for in-place editing
    sed -i '' "$pattern" "$file"
  else
    # Linux uses -i without argument
    sed -i "$pattern" "$file"
  fi
  
  local result=$?
  if [ $result -ne 0 ]; then
    log_error "sed operation failed with pattern: $pattern on file: $file"
    return $E_GENERAL_ERROR
  fi
  
  return $E_SUCCESS
}

# Function to get a container name matching a pattern
get_container_name() {
  local service_pattern="$1"
  local prefix_pattern="${2:-}"
  local exclude_pattern="${3:-}"
  local exact_pattern="${4:-false}"
  
  # For direct match with a consistent naming pattern (dive25-staging-service)
  if [ "$exact_pattern" = "true" ]; then
    local container_name="dive25-staging-${service_pattern}"
    if docker ps -q -f "name=${container_name}" 2>/dev/null | grep -q .; then
      echo "$container_name"
      return 0
    fi
  fi

  # Try the standard prefixed pattern approach first
  local filter="name=${prefix_pattern}.*${service_pattern}"
  if [ -n "$prefix_pattern" ]; then
    # With prefix: dive25-staging-service
    local container=$(docker ps --format '{{.Names}}' | grep -E "${filter}" | head -n 1)
    if [ -n "$container" ]; then
      echo "$container"
      return 0
    fi
  fi
  
  # Try with standard prefix pattern: dive25-staging-service
  local container=$(docker ps --format '{{.Names}}' | grep -E "dive25-staging-${service_pattern}" | head -n 1)
  if [ -n "$container" ]; then
    echo "$container"
    return 0
  fi
  
  # Fallback to generic pattern
  local result=""
  local exclude=""
  
  if [ -n "$exclude_pattern" ]; then
    exclude="| grep -v \"${exclude_pattern}\""
  fi
  
  # We need to use eval here to properly handle the exclude grep
  result=$(eval "docker ps --format '{{.Names}}' | grep -i \"${service_pattern}\" $exclude | head -n 1")
  echo "$result"
  return 0
}

# Function to ensure a certain container exists and is running
ensure_container() {
  local name="$1"
  local image="$2"
  local command="${3:-}"
  
  # Check if container already exists
  if docker ps -a --format '{{.Names}}' | grep -q "$name"; then
    # Check if it's running
    if docker ps --format '{{.Names}}' | grep -q "$name"; then
      return $E_SUCCESS
    else
      # Start container if it exists but is not running
      docker start "$name" >/dev/null 2>&1
      return $?
    fi
  else
    # Create and start container
    if [ -n "$command" ]; then
      docker run -d --name "$name" "$image" $command >/dev/null 2>&1
    else
      docker run -d --name "$name" "$image" >/dev/null 2>&1
    fi
    return $?
  fi
}

# Function to calculate elapsed time
calculate_elapsed_time() {
  local end_time=${1:-$(date +%s)}
  local start_time=${2:-$START_TIME}
  local elapsed=$((end_time - start_time))
  
  local hours=$((elapsed / 3600))
  local minutes=$(((elapsed % 3600) / 60))
  local seconds=$((elapsed % 60))
  
  if [ $hours -gt 0 ]; then
    echo "${hours}h ${minutes}m ${seconds}s"
  elif [ $minutes -gt 0 ]; then
    echo "${minutes}m ${seconds}s"
  else
    echo "${seconds}s"
  fi
}

# Function to print elapsed time
print_elapsed_time() {
  local duration=${1:-$(calculate_elapsed_time)}
  echo "Total elapsed time: $duration"
}

# Function to verify the deployment
verify_deployment() {
  local verification_result=$E_SUCCESS
  
  # Verify Docker containers are running
  if ! docker ps | grep -q "dive25"; then
    verification_result=$E_GENERAL_ERROR
  fi
  
  # Verify Kong admin API is accessible
  if ! check_url_accessible "http://localhost:9444/status" 5; then
    verification_result=$E_GENERAL_ERROR
  fi
  
  # Verify Keycloak is accessible
  if ! check_url_accessible "http://localhost:8444" 5; then
    verification_result=$E_GENERAL_ERROR
  fi
  
  return $verification_result
}

# Function to handle errors with proper messaging
handle_error() {
  local error_code="$1"
  local error_message="$2"
  local exit_on_error="${3:-false}"
  
  case "$error_code" in
    $E_SUCCESS)
      # Not an error, just log success
      return $E_SUCCESS
      ;;
    $E_GENERAL_ERROR)
      error_message=${error_message:-"General error occurred"}
      ;;
    $E_INVALID_ARGS)
      error_message=${error_message:-"Invalid arguments provided"}
      ;;
    $E_RESOURCE_NOT_FOUND)
      error_message=${error_message:-"Required resource not found"}
      ;;
    $E_NETWORK_ERROR)
      error_message=${error_message:-"Network error occurred"}
      ;;
    $E_PERMISSION_DENIED)
      error_message=${error_message:-"Permission denied"}
      ;;
    $E_TIMEOUT)
      error_message=${error_message:-"Operation timed out"}
      ;;
    $E_DEPENDENCY_MISSING)
      error_message=${error_message:-"Required dependency is missing"}
      ;;
    $E_CONFIG_ERROR)
      error_message=${error_message:-"Configuration error"}
      ;;
    *)
      error_message=${error_message:-"Unknown error occurred"}
      ;;
  esac
  
  # Exit if requested and not a success
  if [ "$exit_on_error" = "true" ]; then
    exit "$error_code"
  fi
  
  return "$error_code"
}

# Export all functions to make them available to sourcing scripts
export -f command_exists
export -f check_dependencies
export -f check_docker_requirements
export -f is_port_in_use
export -f wait_for_port
export -f check_url_accessible
export -f check_hosts_entries
export -f update_hosts_file
export -f portable_sed
export -f get_container_name
export -f ensure_container
export -f calculate_elapsed_time
export -f print_elapsed_time
export -f verify_deployment
export -f handle_error 