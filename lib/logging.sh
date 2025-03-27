#!/bin/bash
# DIVE25 - Logging library
# Contains logging-related functions only

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

# Emoji aliases for visual cues
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
log_debug() {
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
log_info() {
  # Ensure LOG_LEVEL is a number
  if ! [[ "$LOG_LEVEL" =~ ^[0-6]$ ]]; then
    LOG_LEVEL=$LOG_LEVEL_INFO
  fi
  
  if [[ "$LOG_LEVEL" -le "$LOG_LEVEL_INFO" ]]; then
    echo -e "${BLUE}${EMOJI_INFO} ${1}${RESET}"
    write_to_log "INFO" "$1"
  fi
}

# Function to print a success message
log_success() {
  # Ensure LOG_LEVEL is a number
  if ! [[ "$LOG_LEVEL" =~ ^[0-6]$ ]]; then
    LOG_LEVEL=$LOG_LEVEL_INFO
  fi
  
  if [[ "$LOG_LEVEL" -le "$LOG_LEVEL_SUCCESS" ]]; then
    echo -e "${GREEN}${EMOJI_CHECK} ${1}${RESET}"
    write_to_log "SUCCESS" "$1"
  fi
}

# Function to print a warning message
log_warning() {
  # Ensure LOG_LEVEL is a number
  if ! [[ "$LOG_LEVEL" =~ ^[0-6]$ ]]; then
    LOG_LEVEL=$LOG_LEVEL_INFO
  fi
  
  if [[ "$LOG_LEVEL" -le "$LOG_LEVEL_WARNING" ]]; then
    echo -e "${YELLOW}${EMOJI_WARNING} WARNING: ${1}${RESET}"
    write_to_log "WARNING" "$1"
  fi
}

# Function to print an error message
log_error() {
  # Ensure LOG_LEVEL is a number
  if ! [[ "$LOG_LEVEL" =~ ^[0-6]$ ]]; then
    LOG_LEVEL=$LOG_LEVEL_INFO
  fi
  
  if [[ "$LOG_LEVEL" -le "$LOG_LEVEL_ERROR" ]]; then
    echo -e "${RED}${EMOJI_ERROR} ERROR: ${1}${RESET}"
    write_to_log "ERROR" "$1"
  fi
}

# Function to print a critical error message
log_critical() {
  # Ensure LOG_LEVEL is a number
  if ! [[ "$LOG_LEVEL" =~ ^[0-6]$ ]]; then
    LOG_LEVEL=$LOG_LEVEL_INFO
  fi
  
  if [[ "$LOG_LEVEL" -le "$LOG_LEVEL_CRITICAL" ]]; then
    echo -e "${RED}${BOLD}${EMOJI_CRITICAL} CRITICAL: ${1}${RESET}"
    write_to_log "CRITICAL" "$1"
  fi
}

# Function to print a section header
log_header() {
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
log_step() {
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
log_progress() {
  local message="$1"
  
  echo -e "${MAGENTA}${EMOJI_HOURGLASS} ${message}${RESET}"
  write_to_log "PROGRESS" "$message"
}

# Function to show user input prompt
log_prompt() {
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
log_divider() {
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
log_command_output() {
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
          log_warning "Unknown log level: $log_level, defaulting to INFO"
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
  
  log_debug "Logging initialized with level $LOG_LEVEL"
  if [ -n "$LOG_FILE" ]; then
    log_debug "Logging to file: $LOG_FILE"
  fi
}

# Export all functions to make them available to sourcing scripts
export -f get_timestamp
export -f write_to_log
export -f log_debug
export -f log_info
export -f log_success
export -f log_warning
export -f log_error
export -f log_critical
export -f log_header
export -f log_step
export -f log_progress
export -f log_prompt
export -f log_divider
export -f log_command_output
export -f init_logging 