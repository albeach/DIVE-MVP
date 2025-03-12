#!/bin/bash
# run-setup.sh - A script to run the setup with the right options

set -e

echo "=== Running Setup with Optimized Keycloak Checks ==="

# First, fix the Keycloak health checks
if [ -f "keycloak/fix-keycloak-checks.sh" ]; then
  echo "Running fix-keycloak-checks.sh..."
  bash keycloak/fix-keycloak-checks.sh
else
  echo "Warning: fix-keycloak-checks.sh not found. Continuing anyway."
fi

# Run the setup script with the right options
echo "Running setup-and-test.sh with optimized options..."
FAST_SETUP=true SKIP_KEYCLOAK_CHECKS=true bash scripts/setup-and-test.sh

echo "=== Setup Complete ===" 