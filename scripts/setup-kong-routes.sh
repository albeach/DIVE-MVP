#!/bin/bash

# Script to programmatically set up Kong routes
echo "Setting up Kong routes..."

# Kong Admin API URL
KONG_ADMIN="http://localhost:8001"

# Check if Kong admin API is accessible
if ! curl -s -o /dev/null -w "%{http_code}" $KONG_ADMIN > /dev/null; then
  echo "❌ Cannot connect to Kong Admin API at $KONG_ADMIN"
  echo "Make sure Kong is running!"
  exit 1
fi

echo "✅ Kong Admin API is accessible"

# Create wildcard service
echo "Creating wildcard service..."
curl -s -X PUT $KONG_ADMIN/services/wildcard-service \
  -d name=wildcard-service \
  -d url=http://frontend:3000

# Create wildcard route
echo "Creating wildcard route..."
curl -s -X POST $KONG_ADMIN/services/wildcard-service/routes \
  -d name=wildcard-route \
  -d 'hosts[]=*.dive25.local' \
  -d 'protocols[]=http' \
  -d 'protocols[]=https'

# Create frontend service
echo "Creating frontend service..."
curl -s -X PUT $KONG_ADMIN/services/frontend-service \
  -d name=frontend-service \
  -d url=http://frontend:3000

# Create frontend route
echo "Creating frontend route..."
curl -s -X POST $KONG_ADMIN/services/frontend-service/routes \
  -d name=frontend-route \
  -d 'hosts[]=dive25.local' \
  -d 'hosts[]=frontend.dive25.local' \
  -d 'protocols[]=http' \
  -d 'protocols[]=https'

# Create API service
echo "Creating API service..."
curl -s -X PUT $KONG_ADMIN/services/api-service \
  -d name=api-service \
  -d url=http://api:3000

# Create API route
echo "Creating API route..."
curl -s -X POST $KONG_ADMIN/services/api-service/routes \
  -d name=api-route \
  -d 'hosts[]=api.dive25.local' \
  -d 'protocols[]=http' \
  -d 'protocols[]=https'

echo "Kong routes setup complete."
echo "Run the following command to test the routes:"
echo "./scripts/test-kong-routing.sh" 