#!/bin/bash
set -e

echo "=============================================="
echo "DIVE25 - Simplified Setup Script"
echo "=============================================="

# Export environment variables from keycloak.env
export $(grep -v '^#' keycloak.env | xargs)

# Stop any running containers
echo "Stopping any running containers..."
docker-compose down

# Start containers with the new configuration
echo "Starting containers..."
docker-compose up -d

# Wait for Keycloak to be available
echo "Waiting for Keycloak to start..."
MAX_RETRIES=30
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
  if docker ps | grep -q "keycloak" && [ "$(docker inspect --format='{{.State.Health.Status}}' dive25-staging-keycloak 2>/dev/null)" = "healthy" ]; then
    echo "✅ Keycloak is up and running!"
    break
  fi
  
  echo "Waiting for Keycloak to be ready... ($(($RETRY_COUNT+1))/$MAX_RETRIES)"
  sleep 10
  RETRY_COUNT=$((RETRY_COUNT+1))
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
  echo "❌ Timed out waiting for Keycloak. Continuing anyway..."
fi

# Apply IdP fixes
echo "Applying identity provider fixes..."
if [ -f "keycloak/fix-idps.sh" ]; then
  bash keycloak/fix-idps.sh
  echo "✅ IdP fixes applied successfully!"
else
  echo "❌ keycloak/fix-idps.sh not found!"
fi

# Verify configuration
echo "Verifying IdP configuration..."
./test-idp-fix.sh

echo "=============================================="
echo "Setup completed! Docker containers are running."
echo "You can now access the application at https://dive25.local:8443"
echo "==============================================" 