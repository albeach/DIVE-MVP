#!/bin/bash

# Function to print a success message
success() {
  echo "SUCCESS: $1"
}

# Function to print a warning message
warning() {
  echo "WARNING: $1"
}

# Function to print an error message
error() {
  echo "ERROR: $1"
}

# Function to print an info message
info() {
  echo "INFO: $1"
}

print_step() {
  echo "STEP: $1"
}

show_progress() {
  echo "PROGRESS: $1"
}

# Function to check Kong health specifically
check_kong_health() {
  print_step "Checking Kong Gateway Health"
  show_progress "Verifying Kong is properly configured and running..."
  
  # Get Kong container name - using a safer approach
  local kong_container=$(docker ps --format '{{.Names}}' | grep -E 'kong' 2>/dev/null | grep -v "config\|migrations" 2>/dev/null | head -n 1)
  
  if [ -z "$kong_container" ]; then
    error "Kong container not found. This is a critical error."
    return 1
  else
    success "Kong container is running: $kong_container"
  fi
  
  return 0
}

# Main script
echo "Testing Kong health check..."
check_kong_health
echo "Test complete!" 