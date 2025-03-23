#!/bin/bash

# Set these to avoid interactive prompts
export ACCEPT_ALL=true
export CONTINUE_ON_ERROR=true
export CI_MODE=true

echo "Running DIVE25 setup in non-interactive mode..."
./setup.sh --clean --fast --test

# Check the result
if [ $? -eq 0 ]; then
  echo "Setup completed successfully!"
  
  echo "Testing Kong OIDC plugin configuration..."
  # Run specific verification of the Kong OIDC plugin
  ./setup.sh --kong-only --test
  
  if [ $? -eq 0 ]; then
    echo "Kong OIDC plugin verification completed successfully!"
    exit 0
  else
    echo "Kong OIDC plugin verification failed with exit code $?"
    exit 1
  fi
else
  echo "Setup failed with exit code $?"
  exit 1
fi 