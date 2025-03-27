#!/bin/bash
# DIVE25 - Main setup script
# Unified entry point for DIVE25 deployment

# Set strict error handling
set -o pipefail

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
  # Source the common library first, which will load logging and system
  if [ -f "$LIB_DIR/common.sh" ]; then
    source "$LIB_DIR/common.sh"
  else
    echo "Error: Required libraries not found. Run setup-libs.sh first."
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
  log_header "DIVE25 - Authentication Workflow Setup"
  log_info "Environment: $ENVIRONMENT"
  log_info "Mode: $DEPLOYMENT_MODE"
  log_info "Debug: $DEBUG"
  
  # Ensure directories exist
  mkdir -p "$CERTS_DIR"
  
  # Clean up if requested
  if [ "$CLEAN_FIRST" = "true" ]; then
    log_step "Cleaning up existing deployment"
    source "$LIB_DIR/docker.sh"
    cleanup_docker_environment
  fi
  
  # Run appropriate deployment steps based on mode
  case $DEPLOYMENT_MODE in
    full)
      source "$LIB_DIR/cert.sh"
      source "$LIB_DIR/docker.sh"
      source "$LIB_DIR/kong.sh"
      source "$LIB_DIR/keycloak.sh"
      
      setup_environment
      setup_certificates
      start_docker_services
      configure_kong
      configure_keycloak
      verify_deployment
      ;;
    certs)
      source "$LIB_DIR/cert.sh"
      setup_certificates
      ;;
    kong)
      source "$LIB_DIR/kong.sh"
      configure_kong
      ;;
    keycloak)
      source "$LIB_DIR/keycloak.sh"
      configure_keycloak
      ;;
    verify)
      source "$LIB_DIR/system.sh"
      verify_deployment
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
  
  if [ -f "$ENV_FILE" ]; then
    log_info "Loading environment config from $ENV_FILE"
    cp "$ENV_FILE" "$ROOT_DIR/.env"
  else
    log_warning "Environment file not found: $ENV_FILE"
    log_info "Using default environment settings"
    
    # Create a minimal environment file
    cat > "$ROOT_DIR/.env" << EOF
# DIVE25 Environment Configuration
ENVIRONMENT=$ENVIRONMENT
BASE_DOMAIN=dive25.local
FRONTEND_DOMAIN=frontend
API_DOMAIN=api
KEYCLOAK_DOMAIN=keycloak
KONG_DOMAIN=kong
EOF
  fi
  
  # Set container name variables based on environment
  if [ "$ENVIRONMENT" = "staging" ]; then
    log_info "Using staging container names"
    # Set container names with staging prefix
    cat >> "$ROOT_DIR/.env" << EOF

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
EOF
  else
    # For dev or other environments
    log_info "Using default container names"
    cat >> "$ROOT_DIR/.env" << EOF

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
EOF
  fi
  
  log_success "Environment setup complete"
}

# Execute main function
main "$@"
exit $? 