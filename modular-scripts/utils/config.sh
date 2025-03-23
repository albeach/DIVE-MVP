#!/bin/bash
# Configuration utility functions

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Import logging utilities but avoid circular dependencies
if [[ ! "$BASH_SOURCE" == *"logging.sh" ]]; then
  source "$SCRIPT_DIR/logging.sh"
fi

# Cached values to avoid multiple disk reads (simple string instead of associative array)
_ENV_CACHE=""

# Helper functions for env cache
get_env_cache() {
  local key=$1
  if [[ "$_ENV_CACHE" == *"|$key:"* ]]; then
    echo "$_ENV_CACHE" | grep -o "|$key:[^|]*" | cut -d: -f2
    return 0
  fi
  return 1
}

set_env_cache() {
  local key=$1
  local value=$2
  
  # Escape special characters in key and value for sed
  local escaped_key=$(echo "$key" | sed 's/[\/&]/\\&/g')
  local escaped_value=$(echo "$value" | sed 's/[\/&]/\\&/g')
  
  # Add or update the cache
  if [[ "$_ENV_CACHE" == *"|$key:"* ]]; then
    # Replace existing entry using a different approach to avoid sed issues
    local old_cache="$_ENV_CACHE"
    _ENV_CACHE=""
    
    # Process each entry
    while IFS= read -r entry; do
      if [[ "$entry" == *"|$key:"* ]]; then
        # Replace this entry
        _ENV_CACHE="${_ENV_CACHE}|$key:$value|"
      else
        # Keep this entry as is
        _ENV_CACHE="${_ENV_CACHE}${entry}"
      fi
    done < <(echo "$old_cache" | grep -o "|[^|]*|")
    
    # If no entries were processed, reset with just the new entry
    if [ -z "$_ENV_CACHE" ]; then
      _ENV_CACHE="|$key:$value|"
    fi
  else
    # Add new entry
    _ENV_CACHE="${_ENV_CACHE}|$key:$value|"
  fi
}

env_cache_size() {
  echo "$_ENV_CACHE" | grep -o "|" | wc -l
}

# Function to load settings from .env file
load_env_file() {
  local env_file="${1:-.env}"
  
  # Use absolute path if not already
  if [[ ! "$env_file" == /* ]]; then
    env_file="$ROOT_DIR/$env_file"
  fi
  
  print_step "Loading environment variables from $env_file"

  if [ ! -f "$env_file" ]; then
    warning "Environment file not found: $env_file"
    return $E_RESOURCE_NOT_FOUND
  fi

  show_progress "Loading environment variables..."
  
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
      
      # Cache the value
      set_env_cache "$var_name" "$var_value"
      
      if [ "$DEBUG" = "true" ]; then
        debug "Loaded: $var_name=$var_value"
      fi
    fi
  done < "$env_file"
  
  success "Environment variables loaded successfully from $env_file"
  return $E_SUCCESS
}

# Function to get environment variable value with fallback
get_env_value() {
  local var_name="$1"
  local env_file="${2:-.env}"
  local default_value="$3"
  
  # First check if we have the value in our cache
  local cached_value
  cached_value=$(get_env_cache "$var_name")
  if [ $? -eq 0 ] && [ -n "$cached_value" ]; then
    echo "$cached_value"
    return $E_SUCCESS
  fi
  
  # Then check if we have the value in environment variables
  if [ -n "${!var_name}" ]; then
    # Cache the value for future use
    set_env_cache "$var_name" "${!var_name}"
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
      # Cache the value for future use
      set_env_cache "$var_name" "$var_value"
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
    warning "Environment file not found: $env_file"
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
  
  # Update cache
  set_env_cache "$var_name" "$var_value"
  
  debug "Updated $var_name=$var_value in $env_file"
  return $E_SUCCESS
}

# Function to update template file with environment variables
update_template() {
  local template_file="$1"
  local output_file="$2"
  local env_file="${3:-.env}"
  
  show_progress "Updating template file: $template_file -> $output_file"
  
  if [ ! -f "$template_file" ]; then
    error "Template file not found: $template_file"
    return $E_RESOURCE_NOT_FOUND
  fi
  
  # Load environment variables if not already loaded
  if [ $(env_cache_size) -eq 0 ]; then
    load_env_file "$env_file"
  fi
  
  # Create output directory if it doesn't exist
  local output_dir=$(dirname "$output_file")
  if [ ! -d "$output_dir" ]; then
    mkdir -p "$output_dir"
  fi
  
  # Read template and replace variables
  while IFS= read -r line || [ -n "$line" ]; do
    # Replace ${VAR} with the value of the environment variable VAR
    while [[ "$line" =~ \$\{([A-Za-z0-9_]+)\} ]]; do
      local var_name="${BASH_REMATCH[1]}"
      local var_value=$(get_env_value "$var_name" "$env_file" "")
      line="${line//${BASH_REMATCH[0]}/$var_value}"
    done
    
    # Append line to output file
    echo "$line" >> "$output_file"
  done < "$template_file"
  
  success "Template file updated successfully"
  return $E_SUCCESS
}

# Function to generate an environment file from a template
generate_env_file() {
  local template_file="$1"
  local output_file="$2"
  local environment="${3:-dev}"
  
  print_step "Generating environment file from template"
  
  if [ ! -f "$template_file" ]; then
    error "Template file not found: $template_file"
    return $E_RESOURCE_NOT_FOUND
  fi
  
  show_progress "Generating $output_file from $template_file for environment: $environment"
  
  # Check if the output file already exists
  if [ -f "$output_file" ]; then
    # Create a backup
    local backup_file="$output_file.backup.$(date +%Y%m%d%H%M%S)"
    cp "$output_file" "$backup_file"
    debug "Created backup of existing file: $backup_file"
  fi
  
  # Create a temporary file for sed to work with
  local temp_file=$(mktemp)
  
  # Copy template to temporary file
  cp "$template_file" "$temp_file"
  
  # Replace environment placeholders
  portable_sed "s/__ENVIRONMENT__/$environment/g" "$temp_file"
  
  # Replace other standard placeholders if needed
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  portable_sed "s/__TIMESTAMP__/$timestamp/g" "$temp_file"
  
  # Copy updated template to output file
  cp "$temp_file" "$output_file"
  
  # Clean up
  rm -f "$temp_file"
  
  success "Generated environment file: $output_file"
  
  # Load the new environment file
  load_env_file "$output_file"
  
  return $E_SUCCESS
}

# Function to fix template files if they use the wrong variable syntax
fix_template_files() {
  print_step "Fixing template files"
  
  show_progress "Checking for template files with incorrect variable syntax..."
  
  # Find all template files
  local template_files=$(find "$ROOT_DIR" -name "*.template.*" -o -name "*.tpl" -o -name "*.j2" 2>/dev/null)
  
  if [ -z "$template_files" ]; then
    info "No template files found"
    return $E_SUCCESS
  fi
  
  for template in $template_files; do
    debug "Checking template file: $template"
    
    # Check for incorrect variable syntax like {{ VAR }} (should be ${VAR})
    if grep -q "{{[[:space:]]*[A-Za-z0-9_]\+[[:space:]]*}}" "$template"; then
      show_progress "Fixing Jinja2-style variables in $template..."
      
      # Create a backup
      local backup_file="$template.backup.$(date +%Y%m%d%H%M%S)"
      cp "$template" "$backup_file"
      
      # Replace {{ VAR }} with ${VAR}
      portable_sed 's/{{[[:space:]]*\([A-Za-z0-9_]\+\)[[:space:]]*}}/${\1}/g' "$template"
      
      success "Fixed template file: $template"
    fi
    
    # Check for incorrect variable syntax like %VAR% (should be ${VAR})
    if grep -q "%[A-Za-z0-9_]\+%" "$template"; then
      show_progress "Fixing Windows-style variables in $template..."
      
      # Create a backup if not already done
      if [ ! -f "$template.backup.$(date +%Y%m%d%H%M%S)" ]; then
        local backup_file="$template.backup.$(date +%Y%m%d%H%M%S)"
        cp "$template" "$backup_file"
      fi
      
      # Replace %VAR% with ${VAR}
      portable_sed 's/%\([A-Za-z0-9_]\+\)%/${\1}/g' "$template"
      
      success "Fixed template file: $template"
    fi
  done
  
  success "Template files fixed successfully"
  return $E_SUCCESS
}

# Function to set default deployment variables
set_default_variables() {
  print_step "Setting default variables"
  
  # Load environment variables if not already loaded
  if [ $(env_cache_size) -eq 0 ] && [ -f "$ROOT_DIR/.env" ]; then
    load_env_file "$ROOT_DIR/.env"
  fi
  
  # Set default domain if not set
  if [ -z "$BASE_DOMAIN" ]; then
    export BASE_DOMAIN="dive25.local"
    set_env_cache "BASE_DOMAIN" "dive25.local"
    debug "Set default BASE_DOMAIN=$BASE_DOMAIN"
  fi
  
  # Set default subdomains if not set
  if [ -z "$FRONTEND_DOMAIN" ]; then
    export FRONTEND_DOMAIN="frontend"
    set_env_cache "FRONTEND_DOMAIN" "frontend"
    debug "Set default FRONTEND_DOMAIN=$FRONTEND_DOMAIN"
  fi
  
  if [ -z "$API_DOMAIN" ]; then
    export API_DOMAIN="api"
    set_env_cache "API_DOMAIN" "api"
    debug "Set default API_DOMAIN=$API_DOMAIN"
  fi
  
  if [ -z "$KEYCLOAK_DOMAIN" ]; then
    export KEYCLOAK_DOMAIN="keycloak"
    set_env_cache "KEYCLOAK_DOMAIN" "keycloak"
    debug "Set default KEYCLOAK_DOMAIN=$KEYCLOAK_DOMAIN"
  fi
  
  if [ -z "$KONG_DOMAIN" ]; then
    export KONG_DOMAIN="kong"
    set_env_cache "KONG_DOMAIN" "kong"
    debug "Set default KONG_DOMAIN=$KONG_DOMAIN"
  fi
  
  # Set default ports if not set
  if [ -z "$FRONTEND_PORT" ]; then
    export FRONTEND_PORT="3001"
    set_env_cache "FRONTEND_PORT" "3001"
    debug "Set default FRONTEND_PORT=$FRONTEND_PORT"
  fi
  
  if [ -z "$API_PORT" ]; then
    export API_PORT="3002"
    set_env_cache "API_PORT" "3002"
    debug "Set default API_PORT=$API_PORT"
  fi
  
  if [ -z "$KEYCLOAK_PORT" ]; then
    export KEYCLOAK_PORT="8443"
    set_env_cache "KEYCLOAK_PORT" "8443"
    debug "Set default KEYCLOAK_PORT=$KEYCLOAK_PORT"
  fi
  
  if [ -z "$KEYCLOAK_INTERNAL_PORT" ]; then
    export KEYCLOAK_INTERNAL_PORT="8080"
    set_env_cache "KEYCLOAK_INTERNAL_PORT" "8080"
    debug "Set default KEYCLOAK_INTERNAL_PORT=$KEYCLOAK_INTERNAL_PORT"
  fi
  
  if [ -z "$KONG_PORT" ]; then
    export KONG_PORT="8443"
    set_env_cache "KONG_PORT" "8443"
    debug "Set default KONG_PORT=$KONG_PORT"
  fi
  
  if [ -z "$KONG_ADMIN_PORT" ]; then
    export KONG_ADMIN_PORT="8001"
    set_env_cache "KONG_ADMIN_PORT" "8001"
    debug "Set default KONG_ADMIN_PORT=$KONG_ADMIN_PORT"
  fi
  
  if [ -z "$KONG_ADMIN_HTTPS_PORT" ]; then
    export KONG_ADMIN_HTTPS_PORT="9444"
    set_env_cache "KONG_ADMIN_HTTPS_PORT" "9444"
    debug "Set default KONG_ADMIN_HTTPS_PORT=$KONG_ADMIN_HTTPS_PORT"
  fi
  
  # Construct URLs from domains and ports
  export PUBLIC_FRONTEND_URL="https://${FRONTEND_DOMAIN}.${BASE_DOMAIN}:${FRONTEND_PORT}"
  export PUBLIC_API_URL="https://${API_DOMAIN}.${BASE_DOMAIN}:${API_PORT}"
  export PUBLIC_KEYCLOAK_URL="https://${KEYCLOAK_DOMAIN}.${BASE_DOMAIN}:${KEYCLOAK_PORT}"
  export PUBLIC_KONG_URL="https://${KONG_DOMAIN}.${BASE_DOMAIN}:${KONG_PORT}"
  
  # Internal URLs for service-to-service communication
  export INTERNAL_FRONTEND_URL="http://frontend:3000"
  export INTERNAL_API_URL="http://api:3000"
  export INTERNAL_KEYCLOAK_URL="http://keycloak:8080"
  export INTERNAL_KONG_URL="http://kong:8000"
  
  # Default Keycloak settings
  if [ -z "$KEYCLOAK_REALM" ]; then
    export KEYCLOAK_REALM="dive25"
    set_env_cache "KEYCLOAK_REALM" "dive25"
    debug "Set default KEYCLOAK_REALM=$KEYCLOAK_REALM"
  fi
  
  if [ -z "$KEYCLOAK_CLIENT_ID_FRONTEND" ]; then
    export KEYCLOAK_CLIENT_ID_FRONTEND="dive25-frontend"
    set_env_cache "KEYCLOAK_CLIENT_ID_FRONTEND" "dive25-frontend"
    debug "Set default KEYCLOAK_CLIENT_ID_FRONTEND=$KEYCLOAK_CLIENT_ID_FRONTEND"
  fi
  
  if [ -z "$KEYCLOAK_CLIENT_ID_API" ]; then
    export KEYCLOAK_CLIENT_ID_API="dive25-api"
    set_env_cache "KEYCLOAK_CLIENT_ID_API" "dive25-api"
    debug "Set default KEYCLOAK_CLIENT_ID_API=$KEYCLOAK_CLIENT_ID_API"
  fi
  
  success "Default variables set successfully"
  return $E_SUCCESS
}

# Function to check existing deployment and prompt for cleanup
check_existing_deployment() {
  print_step "Checking for existing deployment"
  
  local container_count=$(docker ps -a --format '{{.Names}}' | grep -c "dive25")
  
  if [ "$container_count" -gt 0 ]; then
    warning "Found $container_count existing dive25 containers"
    
    # Show running containers
    show_progress "Showing running containers..."
    docker ps | grep "dive25" | head -10
    
    if [ "$container_count" -gt 10 ]; then
      info "... and $(($container_count - 10)) more"
    fi
    
    # Prompt for cleanup
    echo -e "\n${BOLD}${WHITE}========== USER INPUT REQUIRED ===========${RESET}"
    echo -en "${BOLD}${CYAN}>>> Do you want to clean up existing deployment before continuing? (y/n)${RESET} [y]: "
    read -r RESPONSE
    
    # Default to yes if empty
    if [ -z "$RESPONSE" ]; then
      RESPONSE="y"
    fi
    
    if [[ "$RESPONSE" != "n" && "$RESPONSE" != "N" ]]; then
      # Run cleanup script
      if [ -f "$SCRIPT_DIR/../docker/cleanup.sh" ]; then
        bash "$SCRIPT_DIR/../docker/cleanup.sh"
        success "Cleanup completed"
      else
        warning "Cleanup script not found at $SCRIPT_DIR/../docker/cleanup.sh"
      fi
    else
      info "Skipping cleanup as per user request"
    fi
  else
    info "No existing deployment found"
  fi
  
  return $E_SUCCESS
}

# Main function for testing
main() {
  # Load environment variables from .env file
  if [ -f "$ROOT_DIR/.env" ]; then
    load_env_file "$ROOT_DIR/.env"
  else
    warning ".env file not found, using default values"
  fi
  
  # Set default variables
  set_default_variables
  
  # Print current configuration
  print_header "Current Configuration"
  echo "BASE_DOMAIN: $BASE_DOMAIN"
  echo "FRONTEND_DOMAIN: $FRONTEND_DOMAIN"
  echo "API_DOMAIN: $API_DOMAIN"
  echo "KEYCLOAK_DOMAIN: $KEYCLOAK_DOMAIN"
  echo "KONG_DOMAIN: $KONG_DOMAIN"
  echo
  echo "PUBLIC_FRONTEND_URL: $PUBLIC_FRONTEND_URL"
  echo "PUBLIC_API_URL: $PUBLIC_API_URL"
  echo "PUBLIC_KEYCLOAK_URL: $PUBLIC_KEYCLOAK_URL"
  echo "PUBLIC_KONG_URL: $PUBLIC_KONG_URL"
  echo
  echo "INTERNAL_FRONTEND_URL: $INTERNAL_FRONTEND_URL"
  echo "INTERNAL_API_URL: $INTERNAL_API_URL"
  echo "INTERNAL_KEYCLOAK_URL: $INTERNAL_KEYCLOAK_URL"
  echo "INTERNAL_KONG_URL: $INTERNAL_KONG_URL"
  
  return $E_SUCCESS
}

# Execute main function if script is run directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi 