#!/bin/bash
# Quick test script to bring up Docker containers without configuration

# Set script behavior
set -e

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Set these to avoid interactive prompts
export ACCEPT_ALL=true
export CONTINUE_ON_ERROR=true
export CI_MODE=true

echo "==================================================="
echo "  DIVE25 Quick Docker Test"
echo "==================================================="
echo

# Clean up any existing containers
echo "Cleaning up any existing containers..."
if [ -f "$SCRIPT_DIR/modular-scripts/docker/cleanup.sh" ]; then
  bash "$SCRIPT_DIR/modular-scripts/docker/cleanup.sh" --force
else
  echo "Cleanup script not found, using docker-compose down"
  docker-compose down --volumes --remove-orphans || true
fi

# Set up just the Docker containers
echo "Starting Docker containers..."
docker-compose up -d

# Wait a moment
echo "Waiting for containers to start..."
sleep 5

# Show container status
echo "Container status:"
docker ps

echo
echo "Docker containers are now running."
echo "You can test if they're working with: docker-compose ps"
echo "To stop them, use: docker-compose down"
echo 