#!/bin/bash
# kong-restart.sh
# Script to properly restart Kong by ensuring nginx is killed first

set -e
echo "=== DIVE25 Kong Restart Tool ==="
echo "Stopping Kong container..."
docker-compose stop kong || echo "Kong already stopped"

echo "Removing Kong container to ensure clean state..."
docker-compose rm -f kong || echo "Kong container already removed"

echo "Starting Kong with clean state..."
docker-compose up -d kong

echo "Waiting for Kong to initialize..."
sleep 5

echo "Checking Kong status..."
KONG_STATUS=$(docker-compose ps kong | grep "Up" || echo "Not running")

if [[ "$KONG_STATUS" == *"Up"* ]]; then
  echo "✅ Kong restarted successfully!"
else
  echo "❌ Kong restart failed. Container is not running."
  echo "Recent logs:"
  docker-compose logs kong --tail 20
  echo ""
  echo "To see more logs, run: docker-compose logs kong"
  
  echo ""
  echo "❗️ If Kong is stuck in a restart loop, try:"
  echo "1. docker-compose stop kong"
  echo "2. docker-compose rm kong"
  echo "3. docker volume prune -f --filter label=com.docker.compose.project=dive25-staging"
  echo "4. docker-compose up -d kong"
fi

echo "Done!" 