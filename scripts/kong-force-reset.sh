#!/bin/bash
# kong-force-reset.sh
# Script to force kill nginx inside Kong container and clean up volumes if needed

set -e
echo "=== DIVE25 Kong Force Reset Tool ==="

if [[ "$1" == "--help" ]]; then
  echo "Usage: ./scripts/kong-force-reset.sh [--with-volumes]"
  echo ""
  echo "Options:"
  echo "  --with-volumes    Also prune volumes associated with Kong"
  echo ""
  exit 0
fi

echo "Stopping Kong container..."
docker-compose stop kong || echo "Kong already stopped"

echo "Removing Kong container..."
docker-compose rm -f kong || echo "Kong container already removed"

# Check if we should prune volumes
if [[ "$1" == "--with-volumes" ]]; then
  echo "Pruning volumes associated with Kong..."
  docker volume prune -f --filter label=com.docker.compose.project=dive25-staging
  echo "Volumes pruned."
fi

echo "Starting Kong with clean state..."
docker-compose up -d kong

echo "Waiting for Kong to initialize..."
sleep 5

# Check if Kong started successfully
echo "Checking Kong status..."
KONG_STATUS=$(docker-compose ps kong | grep "Up" || echo "Not running")

if [[ "$KONG_STATUS" == *"Up"* ]]; then
  echo "✅ Kong restarted successfully!"
else
  echo "❌ Kong restart failed. Container is not running."
  echo "Recent logs:"
  docker-compose logs kong --tail 20
fi

echo ""
echo "For debugging purposes, you can run:"
echo "docker-compose exec kong sh -c 'cat /usr/local/kong/logs/error.log'"
echo ""
echo "Done!" 