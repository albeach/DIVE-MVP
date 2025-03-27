#!/bin/bash
# DIVE25 - Main setup script
# Unified entry point for DIVE25 deployment

# Set strict error handling
set -o pipefail

# Add error trapping
trap 'echo "Error occurred at line $LINENO"; exit 1' ERR

# Get absolute paths
export SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
export LIB_DIR="$ROOT_DIR/lib"
export CONFIG_DIR="$ROOT_DIR/config"
export CERTS_DIR="$ROOT_DIR/certs"

# Default configuration
export ENVIRONMENT="${ENVIRONMENT:-dev}"
export DEBUG="false"
export FAST_MODE="false"
export CLEAN_FIRST="false"
export DEPLOYMENT_MODE="full"
export SKIP_CHECKS="false"
export DRY_RUN="false"

# Display help information
show_help() {
  echo "DIVE25 - Deployment Script"
  echo
  echo "Usage: $0 [OPTIONS]"
  echo
  echo "OPTIONS:"
  echo "  -h, --help               Show this help message"
  echo "  -e, --env ENV            Set environment (dev, staging, prod)"
  echo "  -f, --fast               Fast setup with minimal checks"
  echo "  -c, --clean              Clean existing deployment before setup"
  echo "  -d, --debug              Enable debug output"
  echo "  --certs-only             Only generate certificates"
  echo "  --kong-only              Only configure Kong gateway"
  echo "  --keycloak-only          Only configure Keycloak"
  echo "  --verify-only            Only run verification checks"
  echo "  --skip-checks            Skip health and prerequisite checks"
  echo "  --dry-run                Show what would be done without making changes"
  echo
  echo "Examples:"
  echo "  $0                       Run full setup with default options"
  echo "  $0 -e staging            Run setup for staging environment"
  echo "  $0 -f -c                 Run fast setup and clean up first"
}

# Parse command line arguments
parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      -h|--help)
        show_help
        exit 0
        ;;
      -e|--env)
        export ENVIRONMENT="$2"
        shift 2
        ;;
      -f|--fast)
        export FAST_MODE="true"
        shift
        ;;
      -c|--clean)
        export CLEAN_FIRST="true"
        shift
        ;;
      -d|--debug)
        export DEBUG="true"
        set -x  # Enable bash trace mode
        shift
        ;;
      --certs-only)
        export DEPLOYMENT_MODE="certs"
        shift
        ;;
      --kong-only)
        export DEPLOYMENT_MODE="kong"
        shift
        ;;
      --keycloak-only)
        export DEPLOYMENT_MODE="keycloak"
        shift
        ;;
      --verify-only)
        export DEPLOYMENT_MODE="verify"
        shift
        ;;
      --skip-checks)
        export SKIP_CHECKS="true"
        shift
        ;;
      --dry-run)
        export DRY_RUN="true"
        shift
        ;;
      *)
        echo "Unknown option: $1"
        show_help
        exit 1
        ;;
    esac
  done
  
  # Validate environment
  case $ENVIRONMENT in
    dev|staging|prod)
      # Valid environment
      ;;
    *)
      echo "Invalid environment: $ENVIRONMENT. Must be one of: dev, staging, prod"
      exit 1
      ;;
  esac
}

# Load all required libraries
load_libraries() {
  # Validate required directories exist
  for dir in "$LIB_DIR" "$CONFIG_DIR"; do
    if [ ! -d "$dir" ]; then
      echo "Error: Required directory $dir does not exist"
      exit 1
    fi
  done

  # Source the common library first, which will load logging and system
  if [ -f "$LIB_DIR/common.sh" ]; then
    source "$LIB_DIR/common.sh"
  else
    echo "Error: Required libraries not found. Run setup-libs.sh first."
    exit 1
  fi
}

# Validate that environment variables are set and valid
validate_environment() {
  log_step "Validating environment configuration"
  
  # Load the environment file if it exists
  ENV_FILE="$CONFIG_DIR/env/$ENVIRONMENT.env"
  if [ ! -f "$ENV_FILE" ]; then
    log_error "Environment file not found: $ENV_FILE"
    return $E_RESOURCE_NOT_FOUND
  fi

  # Check for required variables
  local required_vars=("BASE_DOMAIN" "FRONTEND_DOMAIN" "API_DOMAIN" "KEYCLOAK_DOMAIN" "KONG_DOMAIN")
  local missing_vars=()
  
  for var in "${required_vars[@]}"; do
    if [ -z "$(get_env_value $var $ENV_FILE)" ]; then
      missing_vars+=("$var")
    fi
  done
  
  if [ ${#missing_vars[@]} -gt 0 ]; then
    log_error "Missing required variables in $ENV_FILE: ${missing_vars[*]}"
    return $E_CONFIG_ERROR
  fi
  
  log_success "Environment validation completed"
  return $E_SUCCESS
}

# Verify Docker network exists or create it
verify_docker_network() {
  log_step "Verifying Docker network"
  
  local network_name="dive25-network"
  if ! docker network inspect $network_name &>/dev/null; then
    log_warning "Docker network '$network_name' does not exist, creating it"
    if [ "$DRY_RUN" != "true" ]; then
      docker network create $network_name
      if [ $? -ne 0 ]; then
        log_error "Failed to create Docker network: $network_name"
        return $E_GENERAL_ERROR
      fi
    else
      log_info "[DRY RUN] Would create Docker network: $network_name"
    fi
  else
    log_info "Docker network '$network_name' already exists"
  fi
  
  log_success "Docker network verification completed"
  return $E_SUCCESS
}

# Main execution function
main() {
  # Parse command line arguments
  parse_arguments "$@"
  
  # Load libraries
  load_libraries
  
  # Display header
  log_header "DIVE25 - Authentication Workflow Setup"
  log_info "Environment: $ENVIRONMENT"
  log_info "Mode: $DEPLOYMENT_MODE"
  log_info "Debug: $DEBUG"
  log_info "Dry Run: $DRY_RUN"
  
  # Create required directories if they don't exist
  if [ ! -d "$CERTS_DIR" ]; then
    log_info "Creating certificates directory: $CERTS_DIR"
    if [ "$DRY_RUN" != "true" ]; then
      mkdir -p "$CERTS_DIR"
    else
      log_info "[DRY RUN] Would create directory: $CERTS_DIR"
    fi
  fi
  
  # Run pre-flight checks
  if [ "$SKIP_CHECKS" != "true" ]; then
    log_step "Running pre-flight checks"
    
    # Validate environment configuration
    validate_environment
    if [ $? -ne 0 ]; then
      log_error "Environment validation failed"
      exit $E_CONFIG_ERROR
    fi
    
    # Run system sanity checks
    sanity_check
    if [ $? -ne 0 ]; then
      log_error "Sanity checks failed"
      exit $E_GENERAL_ERROR
    fi
    
    # Verify Docker network
    verify_docker_network
    if [ $? -ne 0 ]; then
      log_error "Docker network verification failed"
      exit $E_GENERAL_ERROR
    fi
  else
    log_warning "Skipping pre-flight checks as requested"
  fi
  
  # Clean up if requested
  if [ "$CLEAN_FIRST" = "true" ]; then
    log_step "Cleaning up existing deployment"
    if [ "$DRY_RUN" != "true" ]; then
      source "$LIB_DIR/docker.sh"
      cleanup_docker_environment
      if [ $? -ne 0 ]; then
        log_warning "Cleanup encountered some issues but continuing"
      fi
    else
      log_info "[DRY RUN] Would clean up existing deployment"
    fi
  fi
  
  # Run appropriate deployment steps based on mode
  case $DEPLOYMENT_MODE in
    full)
      source "$LIB_DIR/cert.sh"
      source "$LIB_DIR/docker.sh"
      source "$LIB_DIR/kong.sh"
      source "$LIB_DIR/keycloak.sh"
      
      setup_environment
      if [ $? -ne 0 ]; then
        log_error "Environment setup failed"
        exit $E_GENERAL_ERROR
      fi
      
      setup_certificates
      if [ $? -ne 0 ]; then
        log_error "Certificate setup failed"
        exit $E_GENERAL_ERROR
      fi
      
      start_docker_services
      if [ $? -ne 0 ]; then
        log_error "Docker services startup failed"
        exit $E_GENERAL_ERROR
      fi
      
      configure_kong
      if [ $? -ne 0 ]; then
        log_error "Kong configuration failed"
        exit $E_GENERAL_ERROR
      fi
      
      configure_keycloak
      if [ $? -ne 0 ]; then
        log_error "Keycloak configuration failed"
        exit $E_GENERAL_ERROR
      fi
      
      verify_deployment
      if [ $? -ne 0 ]; then
        log_warning "Deployment verification found issues"
      fi
      ;;
    certs)
      source "$LIB_DIR/cert.sh"
      setup_certificates
      if [ $? -ne 0 ]; then
        log_error "Certificate setup failed"
        exit $E_GENERAL_ERROR
      fi
      ;;
    kong)
      source "$LIB_DIR/kong.sh"
      configure_kong
      if [ $? -ne 0 ]; then
        log_error "Kong configuration failed"
        exit $E_GENERAL_ERROR
      fi
      ;;
    keycloak)
      source "$LIB_DIR/keycloak.sh"
      configure_keycloak
      if [ $? -ne 0 ]; then
        log_error "Keycloak configuration failed"
        exit $E_GENERAL_ERROR
      fi
      ;;
    verify)
      source "$LIB_DIR/system.sh"
      verify_deployment
      if [ $? -ne 0 ]; then
        log_warning "Deployment verification found issues"
        exit $E_GENERAL_ERROR
      fi
      ;;
    *)
      log_error "Invalid mode: $DEPLOYMENT_MODE"
      exit 1
      ;;
  esac
  
  log_success "DIVE25 deployment completed!"
  echo "✅ DIVE25 $ENVIRONMENT environment ready! Access at https://dive25.local:$KONG_HTTPS_PORT"
  echo "   Keycloak: https://keycloak.dive25.local:$KEYCLOAK_HTTPS_PORT"
  echo "   Frontend: https://frontend.dive25.local:$FRONTEND_PORT"
  echo "   API: https://api.dive25.local:$API_PORT"
  echo ""
  echo "🔍 Network debugging tools available in the dive25-$ENVIRONMENT-netdebug container:"
  echo "   Run connectivity tests: docker exec -it dive25-$ENVIRONMENT-netdebug /scripts/test-connectivity.sh"
  echo "   Diagnose Kong issues:   docker exec -it dive25-$ENVIRONMENT-netdebug /scripts/diagnose-kong.sh"
  echo "   Interactive shell:      docker exec -it dive25-$ENVIRONMENT-netdebug bash"
  return 0
}

# Set up environment for the deployment
setup_environment() {
  log_step "Setting up environment"
  
  # Load environment-specific configuration
  ENV_FILE="$CONFIG_DIR/env/$ENVIRONMENT.env"
  local env_file_backup=""
  
  if [ -f "$ROOT_DIR/.env" ]; then
    log_debug "Backing up existing .env file"
    if [ "$DRY_RUN" != "true" ]; then
      env_file_backup=$(backup_file "$ROOT_DIR/.env")
      if [ $? -ne 0 ]; then
        log_warning "Failed to backup .env file, continuing without backup"
      fi
    else
      log_info "[DRY RUN] Would backup existing .env file"
    fi
  fi
  
  if [ -f "$ENV_FILE" ]; then
    log_info "Loading environment config from $ENV_FILE"
    if [ "$DRY_RUN" != "true" ]; then
      run_with_rollback "cp \"$ENV_FILE\" \"$ROOT_DIR/.env\"" \
                        "[ -n \"$env_file_backup\" ] && cp \"$env_file_backup\" \"$ROOT_DIR/.env\""
      
      if [ $? -ne 0 ]; then
        log_error "Failed to copy environment file"
        return $E_GENERAL_ERROR
      fi
    else
      log_info "[DRY RUN] Would copy $ENV_FILE to $ROOT_DIR/.env"
    fi
  else
    log_warning "Environment file not found: $ENV_FILE"
    log_info "Using default environment settings"
    
    # Create a minimal environment file
    if [ "$DRY_RUN" != "true" ]; then
      run_with_rollback "cat > \"$ROOT_DIR/.env\" << EOF
# DIVE25 Environment Configuration
ENVIRONMENT=$ENVIRONMENT
BASE_DOMAIN=dive25.local
FRONTEND_DOMAIN=frontend
API_DOMAIN=api
KEYCLOAK_DOMAIN=keycloak
KONG_DOMAIN=kong
EOF" \
                        "[ -n \"$env_file_backup\" ] && cp \"$env_file_backup\" \"$ROOT_DIR/.env\""
      
      if [ $? -ne 0 ]; then
        log_error "Failed to create default environment file"
        return $E_GENERAL_ERROR
      fi
    else
      log_info "[DRY RUN] Would create default .env file with basic settings"
    fi
  fi
  
  # Set container name variables based on environment
  if [ "$ENVIRONMENT" = "staging" ]; then
    log_info "Using staging container names"
    # Set container names with staging prefix
    if [ "$DRY_RUN" != "true" ]; then
      run_with_rollback "cat >> \"$ROOT_DIR/.env\" << EOF

# Container names for staging environment
KONG_CONTAINER=dive25-staging-kong
KEYCLOAK_CONTAINER=dive25-staging-keycloak
FRONTEND_CONTAINER=dive25-staging-frontend
API_CONTAINER=dive25-staging-api
KONGA_CONTAINER=dive25-staging-konga
POSTGRES_CONTAINER=dive25-staging-postgres
KONG_DATABASE_CONTAINER=dive25-staging-kong-database
MONGODB_CONTAINER=dive25-staging-mongodb
OPA_CONTAINER=dive25-staging-opa
EOF" \
                        "[ -n \"$env_file_backup\" ] && cp \"$env_file_backup\" \"$ROOT_DIR/.env\""
      
      if [ $? -ne 0 ]; then
        log_error "Failed to append staging container names to environment file"
        return $E_GENERAL_ERROR
      fi
    else
      log_info "[DRY RUN] Would append staging container names to .env file"
    fi
  else
    # For dev or other environments
    log_info "Using default container names"
    if [ "$DRY_RUN" != "true" ]; then
      run_with_rollback "cat >> \"$ROOT_DIR/.env\" << EOF

# Container names for development environment
KONG_CONTAINER=dive25-kong
KEYCLOAK_CONTAINER=dive25-keycloak
FRONTEND_CONTAINER=dive25-frontend
API_CONTAINER=dive25-api
KONGA_CONTAINER=dive25-konga
POSTGRES_CONTAINER=dive25-postgres
KONG_DATABASE_CONTAINER=dive25-kong-database
MONGODB_CONTAINER=dive25-mongodb
OPA_CONTAINER=dive25-opa
EOF" \
                        "[ -n \"$env_file_backup\" ] && cp \"$env_file_backup\" \"$ROOT_DIR/.env\""
      
      if [ $? -ne 0 ]; then
        log_error "Failed to append default container names to environment file"
        return $E_GENERAL_ERROR
      fi
    else
      log_info "[DRY RUN] Would append default container names to .env file"
    fi
  fi
  
  # Load the environment variables we just wrote
  if [ "$DRY_RUN" != "true" ]; then
    load_env_file "$ROOT_DIR/.env"
    if [ $? -ne 0 ]; then
      log_error "Failed to load environment variables from generated .env file"
      return $E_GENERAL_ERROR
    fi
  else
    log_info "[DRY RUN] Would load variables from .env file"
  fi
  
  # Verify ports are not in use
  local required_ports=()
  
  if [ -n "$KONG_HTTP_PORT" ]; then required_ports+=($KONG_HTTP_PORT); fi
  if [ -n "$KONG_HTTPS_PORT" ]; then required_ports+=($KONG_HTTPS_PORT); fi
  if [ -n "$KEYCLOAK_HTTP_PORT" ]; then required_ports+=($KEYCLOAK_HTTP_PORT); fi
  if [ -n "$KEYCLOAK_HTTPS_PORT" ]; then required_ports+=($KEYCLOAK_HTTPS_PORT); fi
  if [ -n "$FRONTEND_PORT" ]; then required_ports+=($FRONTEND_PORT); fi
  if [ -n "$API_PORT" ]; then required_ports+=($API_PORT); fi
  
  log_info "Checking that required ports are available"
  
  for port in "${required_ports[@]}"; do
    if [ "$DRY_RUN" != "true" ] && is_port_in_use "$port"; then
      log_error "Port $port is already in use, please free this port before continuing"
      return $E_RESOURCE_NOT_FOUND
    else
      log_debug "Port $port is available"
    fi
  done
  
  log_success "Environment setup complete"
  return $E_SUCCESS
}

# Execute main function
main "$@"
exit $? 