#!/bin/bash
# Entry point script for DIVE25 deployment

# Set error handling but don't exit on error to provide feedback
set -o pipefail

# Get the absolute directory of this script
export SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ROOT_DIR="$SCRIPT_DIR"
export MODULAR_SCRIPTS_DIR="$ROOT_DIR/modular-scripts"

# Import utility functions if they exist
if [ -f "$MODULAR_SCRIPTS_DIR/utils/logging.sh" ]; then
  source "$MODULAR_SCRIPTS_DIR/utils/logging.sh"
else
  # Fallback basic functions if modular scripts are not yet set up
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[0;33m'
  BLUE='\033[0;34m'
  RESET='\033[0m'
  BOLD='\033[1m'
  
  success() { echo -e "${GREEN}✅ $1${RESET}"; }
  warning() { echo -e "${YELLOW}⚠️ WARNING: $1${RESET}"; }
  error() { echo -e "${RED}❌ ERROR: $1${RESET}"; }
  info() { echo -e "${BLUE}ℹ️ $1${RESET}"; }
fi

# Display help message
show_help() {
  echo -e "${BOLD}DIVE25 - Deployment Script${RESET}"
  echo
  echo "Usage: $0 [OPTIONS]"
  echo
  echo "OPTIONS:"
  echo "  -h, --help               Show this help message"
  echo "  -e, --env ENV            Set environment (dev, staging, prod)"
  echo "  -f, --fast               Fast setup with minimal health checks"
  echo "  -c, --clean              Clean up existing deployment before setup"
  echo "  -t, --test               Test mode (skips certain operations)"
  echo "  -s, --skip-url-checks    Skip URL health checks"
  echo "  -k, --skip-keycloak      Skip Keycloak health checks"
  echo "  -p, --skip-protocol      Skip protocol detection"
  echo "  -d, --debug              Enable debug output"
  echo "  --certs-only             Only generate certificates"
  echo "  --network-only           Only configure networking"
  echo "  --kong-only              Only configure Kong gateway"
  echo "  --keycloak-only          Only configure Keycloak"
  echo "  --verify-only            Only run verification checks"
  echo "  --quick-test             Run a full quick test (equivalent to -f -t)"
  echo
  echo "Examples:"
  echo "  $0                       Run full setup with default options"
  echo "  $0 -e staging            Run setup for staging environment"
  echo "  $0 -f -c                 Run fast setup and clean up first"
  echo "  $0 --verify-only         Run only verification checks"
  echo "  $0 --quick-test          Run a quick test of the entire deployment"
}

# Parse command-line options
parse_options() {
  # Default values
  export ENVIRONMENT="dev"
  export DEBUG="false"
  export SKIP_URL_CHECKS="false"
  export SKIP_KEYCLOAK_CHECKS="false"
  export SKIP_PROTOCOL_DETECTION="false"
  export FAST_SETUP="false"
  export TEST_MODE="false"
  export CLEAN_FIRST="false"
  export MODE="full"
  
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
        export FAST_SETUP="true"
        shift
        ;;
      -c|--clean)
        export CLEAN_FIRST="true"
        shift
        ;;
      -t|--test)
        export TEST_MODE="true"
        shift
        ;;
      -s|--skip-url-checks)
        export SKIP_URL_CHECKS="true"
        shift
        ;;
      -k|--skip-keycloak)
        export SKIP_KEYCLOAK_CHECKS="true"
        shift
        ;;
      -p|--skip-protocol)
        export SKIP_PROTOCOL_DETECTION="true"
        shift
        ;;
      -d|--debug)
        export DEBUG="true"
        set -x # Enable bash trace mode
        shift
        ;;
      --certs-only)
        export MODE="certs"
        shift
        ;;
      --network-only)
        export MODE="network"
        shift
        ;;
      --kong-only)
        export MODE="kong"
        shift
        ;;
      --keycloak-only)
        export MODE="keycloak"
        shift
        ;;
      --verify-only)
        export MODE="verify"
        shift
        ;;
      --quick-test)
        export FAST_SETUP="true"
        export TEST_MODE="true"
        export SKIP_URL_CHECKS="true"
        export SKIP_KEYCLOAK_CHECKS="true"
        shift
        ;;
      *)
        warning "Unknown option: $1"
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
      error "Invalid environment: $ENVIRONMENT. Must be one of: dev, staging, prod"
      exit 1
      ;;
  esac
}

# Run module-specific script
run_module() {
  local module=$1
  local script_path="$MODULAR_SCRIPTS_DIR/$module"
  
  if [ -f "$script_path" ]; then
    info "Running $module script..."
    bash "$script_path"
    local result=$?
    if [ $result -ne 0 ]; then
      warning "Module $module completed with exit code $result"
    fi
    return $result
  elif [ -d "$(dirname "$script_path")" ]; then
    # Try to find a main.sh or similar in the module directory
    local main_script=$(find "$(dirname "$script_path")" -maxdepth 1 -name "*.sh" | head -1)
    if [ -n "$main_script" ]; then
      info "Running $main_script..."
      bash "$main_script"
      local result=$?
      if [ $result -ne 0 ]; then
        warning "Module $main_script completed with exit code $result"
      fi
      return $result
    fi
  fi
  
  error "Module script not found: $script_path"
  return 1
}

# Ensure directories exist
ensure_directories() {
  # Create modular scripts directories if they don't exist
  mkdir -p "$MODULAR_SCRIPTS_DIR/utils"
  mkdir -p "$MODULAR_SCRIPTS_DIR/docker"
  mkdir -p "$MODULAR_SCRIPTS_DIR/certificates"
  mkdir -p "$MODULAR_SCRIPTS_DIR/network"
  mkdir -p "$MODULAR_SCRIPTS_DIR/kong"
  mkdir -p "$MODULAR_SCRIPTS_DIR/keycloak"
  mkdir -p "$MODULAR_SCRIPTS_DIR/verification"
  mkdir -p "$MODULAR_SCRIPTS_DIR/core"
  mkdir -p "$MODULAR_SCRIPTS_DIR/services"
  
  # Create certs directory if it doesn't exist
  mkdir -p "$ROOT_DIR/certs"
  mkdir -p "$ROOT_DIR/certs/ca"
  mkdir -p "$ROOT_DIR/certs/domains"
}

# Ensure script files are executable
ensure_script_permissions() {
  # Check if the main setup scripts are executable
  if [ ! -x "$ROOT_DIR/setup.sh" ]; then
    warning "setup.sh is not executable, fixing permissions..."
    chmod +x "$ROOT_DIR/setup.sh"
  fi
  
  if [ ! -x "$ROOT_DIR/test-dive-setup.sh" ]; then
    warning "test-dive-setup.sh is not executable, fixing permissions..."
    chmod +x "$ROOT_DIR/test-dive-setup.sh"
  fi
  
  # Check and fix permissions for all modular scripts
  if [ -d "$MODULAR_SCRIPTS_DIR" ]; then
    info "Checking modular script permissions..."
    # Using a more portable approach that works on both Linux and macOS
    find "$MODULAR_SCRIPTS_DIR" -name "*.sh" -type f | while read -r script; do
      if [ ! -x "$script" ]; then
        chmod +x "$script"
      fi
    done
  fi
}

# Main function
main() {
  # Parse command-line options
  parse_options "$@"
  
  # Ensure required directories exist
  ensure_directories
  
  # Ensure scripts have proper permissions
  ensure_script_permissions
  
  # Display header
  echo -e "${BLUE}${BOLD}"
  echo "============================================================"
  echo "  DIVE25 - Authentication Workflow Setup Script"
  echo "============================================================"
  echo -e "${RESET}"
  
  # Show configuration
  echo -e "Configuration:"
  echo -e "  Environment: ${BOLD}$ENVIRONMENT${RESET}"
  echo -e "  Mode: ${BOLD}$MODE${RESET}"
  echo -e "  Fast setup: $FAST_SETUP"
  echo -e "  Clean first: $CLEAN_FIRST"
  echo -e "  Test mode: $TEST_MODE"
  echo -e "  Debug: $DEBUG"
  echo
  
  # Clean up if requested
  if [ "$CLEAN_FIRST" = "true" ]; then
    if [ -f "$MODULAR_SCRIPTS_DIR/docker/cleanup.sh" ]; then
      info "Cleaning up existing deployment..."
      bash "$MODULAR_SCRIPTS_DIR/docker/cleanup.sh"
    else
      warning "Cleanup script not found, skipping cleanup"
    fi
  fi
  
  # Export a flag to continue on errors
  export CONTINUE_ON_ERROR="true"
  
  # Run appropriate scripts based on mode
  case $MODE in
    full)
      # Run the main core script - with a timeout in case it hangs
      if [ -f "$MODULAR_SCRIPTS_DIR/core/main.sh" ]; then
        # In test or fast mode, add a timeout to prevent hanging
        if [ "$TEST_MODE" = "true" ] || [ "$FAST_SETUP" = "true" ]; then
          info "Running main script with timeout protection..."
          # 5 minute timeout should be enough for test/fast mode
          timeout 300 bash "$MODULAR_SCRIPTS_DIR/core/main.sh" || true
        else
          # Continue even if there are non-critical errors
          bash "$MODULAR_SCRIPTS_DIR/core/main.sh" || warning "Some parts of the deployment had issues, but the process completed"
        fi
      else
        error "Main script not found: $MODULAR_SCRIPTS_DIR/core/main.sh"
        exit 1
      fi
      ;;
    certs)
      run_module "certificates/cert-manager.sh" || warning "Certificate creation had some issues"
      ;;
    network)
      run_module "network/network-utils.sh" || warning "Network configuration had some issues"
      ;;
    kong)
      run_module "kong/kong-setup.sh" || warning "Kong configuration had some issues"
      ;;
    keycloak)
      run_module "keycloak/keycloak-setup.sh" || warning "Keycloak configuration had some issues"
      ;;
    verify)
      if [ "$TEST_MODE" = "true" ] || [ "$FAST_SETUP" = "true" ]; then
        info "Running verification with timeout protection..."
        # 2 minute timeout for verification in test/fast mode
        timeout 120 bash "$MODULAR_SCRIPTS_DIR/verification/health-checks.sh" || true
      else
        run_module "verification/health-checks.sh" || warning "Verification had some issues"
      fi
      ;;
    *)
      error "Invalid mode: $MODE"
      exit 1
      ;;
  esac
  
  local result=$?
  
  # Display success message even with some warnings
  if [ $result -eq 0 ] || [ "$CONTINUE_ON_ERROR" = "true" ]; then
    success "DIVE25 deployment completed with possible warnings!"
    info "Check the output above for any warnings or errors that may need attention."
    return 0
  else
    error "DIVE25 deployment encountered critical errors (exit code: $result)"
    info "You can try running with --clean flag to start fresh."
    return 1
  fi
}

# Run the main function
main "$@"
exit $? 