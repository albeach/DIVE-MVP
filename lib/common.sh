#!/bin/bash
# DIVE25 - Common library
# Main library that imports logging and system libraries

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Check if logging.sh exists and source it
if [ -f "$SCRIPT_DIR/logging.sh" ]; then
  source "$SCRIPT_DIR/logging.sh"
else
  echo "Error: logging.sh not found in $SCRIPT_DIR"
  exit 1
fi

# Check if system.sh exists and source it
if [ -f "$SCRIPT_DIR/system.sh" ]; then
  source "$SCRIPT_DIR/system.sh"
else
  echo "Error: system.sh not found in $SCRIPT_DIR"
  exit 1
fi

# Initialize logging with default settings
init_logging "${ROOT_DIR}/logs/dive25.log" "${LOG_LEVEL:-info}"

# Array to track operations for potential rollback
ROLLBACK_OPERATIONS=()

# Function to register a rollback operation
register_rollback() {
  local operation="$1"
  ROLLBACK_OPERATIONS+=("$operation")
  log_debug "Registered rollback operation: $operation"
}

# Function to execute rollback operations in reverse order
execute_rollback() {
  local reason="$1"
  
  log_warning "Executing rollback due to: $reason"
  log_divider
  
  # Execute operations in reverse order
  for ((i=${#ROLLBACK_OPERATIONS[@]}-1; i>=0; i--)); do
    local operation="${ROLLBACK_OPERATIONS[$i]}"
    log_info "Rollback: $operation"
    
    eval "$operation" || log_warning "Rollback operation failed: $operation"
  done
  
  log_divider
  log_warning "Rollback completed"
}

# Function to run a command with rollback registration
run_with_rollback() {
  local command="$1"
  local rollback_command="$2"
  local exit_on_error="${3:-false}"
  
  log_debug "Running command with rollback: $command"
  
  eval "$command"
  local result=$?
  
  if [ $result -ne 0 ]; then
    log_error "Command failed with exit code $result: $command"
    
    if [ -n "$rollback_command" ]; then
      register_rollback "$rollback_command"
    fi
    
    if [ "$exit_on_error" = "true" ]; then
      execute_rollback "Command failed: $command"
      exit $result
    fi
    
    return $result
  fi
  
  return 0
}

# Function to create a backup of a file
backup_file() {
  local file_path="$1"
  local backup_dir="${2:-$ROOT_DIR/backups}"
  
  if [ ! -f "$file_path" ]; then
    log_warning "Cannot backup non-existent file: $file_path"
    return $E_RESOURCE_NOT_FOUND
  fi
  
  # Create backup directory if it doesn't exist
  mkdir -p "$backup_dir"
  
  # Generate backup filename with timestamp
  local timestamp=$(date +"%Y%m%d%H%M%S")
  local filename=$(basename "$file_path")
  local backup_path="$backup_dir/${filename}.${timestamp}.bak"
  
  # Copy the file
  cp "$file_path" "$backup_path"
  local result=$?
  
  if [ $result -ne 0 ]; then
    log_error "Failed to create backup of $file_path"
    return $E_GENERAL_ERROR
  fi
  
  log_debug "Created backup of $file_path at $backup_path"
  register_rollback "[ -f \"$backup_path\" ] && cp \"$backup_path\" \"$file_path\" && log_info \"Restored file from backup: $file_path\""
  
  echo "$backup_path"
  return $E_SUCCESS
}

# Function to load environment variables
load_env_file() {
  local env_file="${1:-.env}"
  
  # Use absolute path if not already
  if [[ ! "$env_file" == /* ]]; then
    env_file="$ROOT_DIR/$env_file"
  fi
  
  log_step "Loading environment variables from $env_file"
  
  if [ ! -f "$env_file" ]; then
    log_warning "Environment file not found: $env_file"
    return $E_RESOURCE_NOT_FOUND
  fi
  
  log_progress "Loading environment variables..."
  
  # Read each line of the env file
  while IFS= read -r line || [ -n "$line" ]; do
    # Skip comments and empty lines
    if [[ $line =~ ^# ]] || [[ -z $line ]]; then
      continue
    fi
    
    # Extract variable name and value
    if [[ $line =~ ^([A-Za-z0-9_]+)=(.*)$ ]]; then
      local var_name="${BASH_REMATCH[1]}"
      local var_value="${BASH_REMATCH[2]}"
      
      # Remove surrounding quotes if present
      var_value="${var_value#\"}"
      var_value="${var_value%\"}"
      var_value="${var_value#\'}"
      var_value="${var_value%\'}"
      
      # Export variable
      export "$var_name=$var_value"
      
      if [ "$DEBUG" = "true" ]; then
        log_debug "Loaded: $var_name=$var_value"
      fi
    fi
  done < "$env_file"
  
  log_success "Environment variables loaded successfully from $env_file"
  return $E_SUCCESS
}

# Function to get environment variable value with fallback
get_env_value() {
  local var_name="$1"
  local env_file="${2:-.env}"
  local default_value="$3"
  
  # Check if we have the value in environment variables
  if [ -n "${!var_name}" ]; then
    echo "${!var_name}"
    return $E_SUCCESS
  fi
  
  # If not found, check the env file
  if [ -f "$env_file" ]; then
    local var_value
    var_value=$(grep -E "^$var_name=" "$env_file" | cut -d= -f2-)
    
    # Remove surrounding quotes if present
    var_value="${var_value#\"}"
    var_value="${var_value%\"}"
    var_value="${var_value#\'}"
    var_value="${var_value%\'}"
    
    if [ -n "$var_value" ]; then
      echo "$var_value"
      return $E_SUCCESS
    fi
  fi
  
  # If still not found, return default value
  if [ -n "$default_value" ]; then
    echo "$default_value"
    return $E_SUCCESS
  fi
  
  # If no default value provided, return empty string
  echo ""
  return $E_RESOURCE_NOT_FOUND
}

# Function to set environment variable value in file
set_env_value() {
  local var_name="$1"
  local var_value="$2"
  local env_file="${3:-.env}"
  
  # Use absolute path if not already
  if [[ ! "$env_file" == /* ]]; then
    env_file="$ROOT_DIR/$env_file"
  fi
  
  if [ ! -f "$env_file" ]; then
    log_warning "Environment file not found: $env_file"
    return $E_RESOURCE_NOT_FOUND
  fi
  
  # Quote the value if it contains spaces or special characters
  if [[ "$var_value" =~ [[:space:]] || "$var_value" =~ [^a-zA-Z0-9_./:=-] ]]; then
    var_value="\"$var_value\""
  fi
  
  # Update or add the variable to the env file
  if grep -q "^$var_name=" "$env_file"; then
    # Variable exists, update it
    portable_sed "s|^$var_name=.*|$var_name=$var_value|" "$env_file"
  else
    # Variable doesn't exist, add it
    echo "$var_name=$var_value" >> "$env_file"
  fi
  
  # Update environment variable in current session
  export "$var_name=$var_value"
  
  log_debug "Updated $var_name=$var_value in $env_file"
  return $E_SUCCESS
}

# Function to run a command and log its output
run_command() {
  local command="$1"
  local log_output="${2:-true}"
  local exit_on_error="${3:-false}"
  
  log_debug "Running command: $command"
  
  # Run the command and capture output
  if [ "$log_output" = "true" ]; then
    local output
    output=$(eval "$command" 2>&1)
    local result=$?
    
    if [ $result -ne 0 ]; then
      log_error "Command failed with exit code $result: $command"
      log_command_output "$output"
      
      if [ "$exit_on_error" = "true" ]; then
        exit $result
      fi
      
      return $result
    else
      log_debug "Command succeeded: $command"
      log_command_output "$output"
    fi
  else
    eval "$command"
    local result=$?
    
    if [ $result -ne 0 ] && [ "$exit_on_error" = "true" ]; then
      exit $result
    fi
    
    return $result
  fi
  
  return 0
}

# Function to retry a command until it succeeds
retry_command() {
  local command="$1"
  local max_retries="${2:-$MAX_RETRIES}"
  local retry_interval="${3:-$RETRY_INTERVAL}"
  local exit_on_error="${4:-false}"
  
  log_debug "Retrying command up to $max_retries times: $command"
  
  local retry=0
  while [ $retry -lt $max_retries ]; do
    eval "$command" && return 0
    
    retry=$((retry+1))
    if [ $retry -lt $max_retries ]; then
      log_warning "Command failed, retry $retry/$max_retries in $retry_interval seconds"
      sleep $retry_interval
    else
      log_error "Command failed after $max_retries retries: $command"
      if [ "$exit_on_error" = "true" ]; then
        exit 1
      fi
      return 1
    fi
  done
  
  return 0
}

# Common sanity check function
sanity_check() {
  log_step "Running sanity checks"
  
  # Check dependencies
  check_dependencies "bash" "docker" "docker-compose" "curl" "openssl"
  if [ $? -ne 0 ]; then
    log_error "Missing required dependencies"
    return $E_DEPENDENCY_MISSING
  fi
  
  # Check Docker environment
  check_docker_requirements
  if [ $? -ne 0 ]; then
    log_error "Docker requirements not met"
    return $E_DEPENDENCY_MISSING
  fi
  
  # Check file permissions
  if [ ! -w "$ROOT_DIR" ]; then
    log_error "Cannot write to $ROOT_DIR"
    return $E_PERMISSION_DENIED
  fi
  
  log_success "Sanity checks passed"
  return $E_SUCCESS
}

# Export all functions to make them available to sourcing scripts
export -f load_env_file
export -f get_env_value
export -f set_env_value
export -f run_command
export -f retry_command
export -f sanity_check
export -f register_rollback
export -f execute_rollback
export -f run_with_rollback
export -f backup_file

# Log successful library initialization
log_debug "Common library initialized" 