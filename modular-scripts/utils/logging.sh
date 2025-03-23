#!/bin/bash
# Enhanced logging utility functions

# Color codes for prettier output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
RESET='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

# Emoji aliases for visual cues - important for user experience
EMOJI_CHECK="✅ "
EMOJI_WARNING="⚠️  "
EMOJI_ERROR="❌ "
EMOJI_INFO="ℹ️  "
EMOJI_ROCKET="🚀 "
EMOJI_GEAR="⚙️  "
EMOJI_HOURGLASS="⏳ "
EMOJI_CLOCK="🕒 "
EMOJI_SPARKLES="✨ "
EMOJI_DEBUG="🔍 "
EMOJI_CRITICAL="🚨 "

# Log levels - only declare them if they haven't been declared yet
if [[ -z "${LOG_LEVEL_DEBUG+x}" ]]; then
  declare -r LOG_LEVEL_DEBUG=0
  declare -r LOG_LEVEL_INFO=1
  declare -r LOG_LEVEL_SUCCESS=2
  declare -r LOG_LEVEL_WARNING=3
  declare -r LOG_LEVEL_ERROR=4
  declare -r LOG_LEVEL_CRITICAL=5
  declare -r LOG_LEVEL_SILENT=6
fi

# Default log level (can be overridden by setting LOG_LEVEL)
LOG_LEVEL=${LOG_LEVEL:-$LOG_LEVEL_INFO}

# Error code definitions from system.sh (duplicated for independence)
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

# Log file configuration
LOG_FILE=${LOG_FILE:-""}
LOG_TIMESTAMPS=${LOG_TIMESTAMPS:-true}

# Function to get current timestamp
get_timestamp() {
  date "+%Y-%m-%d %H:%M:%S"
}

# Function to write to log file if configured
write_to_log() {
  local level="$1"
  local message="$2"
  
  if [ -n "$LOG_FILE" ]; then
    local timestamp=""
    if [ "$LOG_TIMESTAMPS" = "true" ]; then
      timestamp="$(get_timestamp) "
    fi
    
    echo "${timestamp}[${level}] ${message}" >> "$LOG_FILE"
  fi
}

# Function to print a debug message (only if DEBUG=true)
debug() {
  # Ensure LOG_LEVEL is a number
  if ! [[ "$LOG_LEVEL" =~ ^[0-6]$ ]]; then
    LOG_LEVEL=$LOG_LEVEL_INFO
  fi
  
  if [[ "$LOG_LEVEL" -le "$LOG_LEVEL_DEBUG" ]] || [ "$DEBUG" = "true" ]; then
    echo -e "${DIM}${CYAN}${EMOJI_DEBUG} DEBUG: ${1}${RESET}"
    write_to_log "DEBUG" "$1"
  fi
}

# Function to print an info message
info() {
  # Ensure LOG_LEVEL is a number
  if ! [[ "$LOG_LEVEL" =~ ^[0-6]$ ]]; then
    LOG_LEVEL=$LOG_LEVEL_INFO
  fi
  
  if [[ "$LOG_LEVEL" -le "$LOG_LEVEL_INFO" ]]; then
    echo -e "${BLUE}${EMOJI_INFO}${1}${RESET}"
    write_to_log "INFO" "$1"
  fi
}

# Function to print a success message
success() {
  # Ensure LOG_LEVEL is a number
  if ! [[ "$LOG_LEVEL" =~ ^[0-6]$ ]]; then
    LOG_LEVEL=$LOG_LEVEL_INFO
  fi
  
  if [[ "$LOG_LEVEL" -le "$LOG_LEVEL_SUCCESS" ]]; then
    echo -e "${GREEN}${EMOJI_CHECK}${1}${RESET}"
    write_to_log "SUCCESS" "$1"
  fi
}

# Function to print a warning message
warning() {
  # Ensure LOG_LEVEL is a number
  if ! [[ "$LOG_LEVEL" =~ ^[0-6]$ ]]; then
    LOG_LEVEL=$LOG_LEVEL_INFO
  fi
  
  if [[ "$LOG_LEVEL" -le "$LOG_LEVEL_WARNING" ]]; then
    echo -e "${YELLOW}${EMOJI_WARNING}WARNING: ${1}${RESET}"
    write_to_log "WARNING" "$1"
  fi
}

# Function to print an error message
error() {
  # Ensure LOG_LEVEL is a number
  if ! [[ "$LOG_LEVEL" =~ ^[0-6]$ ]]; then
    LOG_LEVEL=$LOG_LEVEL_INFO
  fi
  
  if [[ "$LOG_LEVEL" -le "$LOG_LEVEL_ERROR" ]]; then
    echo -e "${RED}${EMOJI_ERROR}ERROR: ${1}${RESET}"
    write_to_log "ERROR" "$1"
  fi
}

# Function to print a critical error message
critical() {
  # Ensure LOG_LEVEL is a number
  if ! [[ "$LOG_LEVEL" =~ ^[0-6]$ ]]; then
    LOG_LEVEL=$LOG_LEVEL_INFO
  fi
  
  if [[ "$LOG_LEVEL" -le "$LOG_LEVEL_CRITICAL" ]]; then
    echo -e "${RED}${BOLD}${EMOJI_CRITICAL}CRITICAL: ${1}${RESET}"
    write_to_log "CRITICAL" "$1"
  fi
}

# Standardized error handling function
handle_error() {
  local error_code="$1"
  local error_message="$2"
  local exit_on_error="${3:-false}"
  
  case "$error_code" in
    $E_SUCCESS)
      # Not an error, just log success
      success "$error_message"
      ;;
    $E_GENERAL_ERROR)
      error "$error_message"
      ;;
    $E_INVALID_ARGS)
      error "Invalid argument: $error_message"
      ;;
    $E_RESOURCE_NOT_FOUND)
      error "Resource not found: $error_message"
      ;;
    $E_NETWORK_ERROR)
      error "Network error: $error_message"
      ;;
    $E_PERMISSION_DENIED)
      error "Permission denied: $error_message"
      ;;
    $E_TIMEOUT)
      error "Operation timed out: $error_message"
      ;;
    $E_DEPENDENCY_MISSING)
      error "Missing dependency: $error_message"
      ;;
    $E_CONFIG_ERROR)
      error "Configuration error: $error_message"
      ;;
    *)
      error "Unknown error ($error_code): $error_message"
      ;;
  esac
  
  # Exit if requested and not a success
  if [ "$exit_on_error" = "true" ] && [ "$error_code" -ne "$E_SUCCESS" ]; then
    if [ "$CONTINUE_ON_ERROR" != "true" ]; then
      critical "Exiting due to error..."
      exit "$error_code"
    else
      warning "Error encountered but continuing due to CONTINUE_ON_ERROR=true"
    fi
  fi
  
  return "$error_code"
}

# Function to print a section header
print_header() {
  local title="$1"
  local width=60
  local divider=""
  
  # Build the header divider manually
  for ((i=0; i<$width; i++)); do
    divider="${divider}="
  done
  
  echo
  echo -e "${BLUE}${BOLD}${EMOJI_ROCKET} ${title} ${EMOJI_ROCKET}${RESET}"
  echo -e "${BLUE}${BOLD}${divider}${RESET}"
  write_to_log "HEADER" "$title"
}

# Function to print a step header
print_step() {
  local step="$1"
  local width=50
  local divider=""
  
  # Build the step divider manually
  for ((i=0; i<$width; i++)); do
    divider="${divider}-"
  done
  
  echo
  echo -e "${CYAN}${BOLD}${EMOJI_GEAR} ${step}...${RESET}"
  echo -e "${CYAN}${divider}${RESET}"
  write_to_log "STEP" "$step"
}

# Function to print progress indicator
show_progress() {
  local message="$1"
  
  echo -e "${MAGENTA}${EMOJI_HOURGLASS} ${message}${RESET}"
  write_to_log "PROGRESS" "$message"
}

# Function to show user input prompt
show_prompt() {
  local prompt="$1"
  local default="$2"
  
  if [ -n "$default" ]; then
    echo -e "\n${BOLD}${WHITE}========== USER INPUT REQUIRED ===========${RESET}"
    echo -en "${BOLD}${CYAN}>>> ${prompt}${RESET} [${default}]: "
  else
    echo -e "\n${BOLD}${WHITE}========== USER INPUT REQUIRED ===========${RESET}"
    echo -en "${BOLD}${CYAN}>>> ${prompt}${RESET}: "
  fi
  write_to_log "PROMPT" "$prompt [default: $default]"
}

# Function to print a divider line
print_divider() {
  local width=80
  local char="-"
  local divider=""
  
  # Build the divider manually instead of using printf sequence
  for ((i=0; i<$width; i++)); do
    divider="${divider}${char}"
  done
  
  echo -e "${DIM}${divider}${RESET}"
  write_to_log "DIVIDER" "----------------------------------------"
}

# Function to print command output with formatting
print_command_output() {
  local command_output="$1"
  local prefix="${2:-  }"
  
  if [ -n "$command_output" ]; then
    echo -e "${DIM}$prefix$command_output${RESET}" | sed "s/^/$prefix/"
    write_to_log "CMD_OUTPUT" "$command_output"
  fi
}

# Function to initialize logging
init_logging() {
  local log_file="${1:-}"
  local log_level="${2:-}"
  
  if [ -n "$log_file" ]; then
    LOG_FILE="$log_file"
    
    # Create log directory if it doesn't exist
    local log_dir=$(dirname "$LOG_FILE")
    if [ ! -d "$log_dir" ]; then
      mkdir -p "$log_dir"
    fi
    
    # Initialize log file
    echo "Log started at $(get_timestamp)" > "$LOG_FILE"
    echo "=================================" >> "$LOG_FILE"
  fi
  
  if [ -n "$log_level" ]; then
    case "$log_level" in
      debug) LOG_LEVEL=$LOG_LEVEL_DEBUG ;;
      info) LOG_LEVEL=$LOG_LEVEL_INFO ;;
      success) LOG_LEVEL=$LOG_LEVEL_SUCCESS ;;
      warning) LOG_LEVEL=$LOG_LEVEL_WARNING ;;
      error) LOG_LEVEL=$LOG_LEVEL_ERROR ;;
      critical) LOG_LEVEL=$LOG_LEVEL_CRITICAL ;;
      silent) LOG_LEVEL=$LOG_LEVEL_SILENT ;;
      *) 
        # If log_level is a number between 0-6, use it directly
        if [[ "$log_level" =~ ^[0-6]$ ]]; then
          LOG_LEVEL=$log_level
        else
          LOG_LEVEL=$LOG_LEVEL_INFO
          warning "Unknown log level: $log_level, defaulting to INFO"
        fi
        ;;
    esac
  fi
  
  # Set up log level based on DEBUG flag for backwards compatibility
  if [ "$DEBUG" = "true" ] && [ -n "$LOG_LEVEL" ] && [ "$LOG_LEVEL" -gt "$LOG_LEVEL_DEBUG" ]; then
    LOG_LEVEL=$LOG_LEVEL_DEBUG
  fi
  
  # Ensure LOG_LEVEL is a number
  if ! [[ "$LOG_LEVEL" =~ ^[0-6]$ ]]; then
    LOG_LEVEL=$LOG_LEVEL_INFO
  fi
  
  debug "Logging initialized with level $LOG_LEVEL"
  if [ -n "$LOG_FILE" ]; then
    debug "Logging to file: $LOG_FILE"
  fi
}

# Main function to test the logging functions
main() {
  init_logging "/tmp/logging-test.log" "debug"
  
  # Test all logging functions
  print_header "Testing Logging Functions"
  print_step "Testing Basic Logging"
  
  debug "This is a debug message"
  info "This is an info message"
  success "This is a success message"
  warning "This is a warning message"
  error "This is an error message"
  critical "This is a critical error message"
  
  print_step "Testing Error Handling"
  
  handle_error $E_SUCCESS "Operation completed successfully"
  handle_error $E_GENERAL_ERROR "Something went wrong"
  handle_error $E_INVALID_ARGS "Missing required parameters"
  handle_error $E_RESOURCE_NOT_FOUND "The file does not exist"
  
  print_step "Testing Progress Indicators"
  
  show_progress "Working on something important..."
  
  print_step "Testing User Prompts"
  
  show_prompt "Enter your name" "User"
  
  success "All logging functions tested successfully"
  
  # Show log file content
  if [ -n "$LOG_FILE" ]; then
    print_header "Log File Content"
    cat "$LOG_FILE"
  fi
  
  return $E_SUCCESS
}

# Execute main function if script is run directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi 