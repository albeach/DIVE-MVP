#!/bin/sh
set -e

# This script is a placeholder for any additional Kong setup 
# that might be needed beyond what's in the docker-compose.override.yml
# The main route configuration is defined in docker-compose.override.yml

echo "Kong routes setup script starting..."

# Wait for Kong Admin API to be available
echo "Waiting for Kong Admin API to be available..."
while ! curl -s http://kong:8001/status > /dev/null; do
  echo "Kong Admin API not ready yet. Sleeping for 5 seconds..."
  sleep 5
done

echo "Kong Admin API is available. Setting up routes..."

# Create the API service if it doesn't exist
if ! curl -s http://kong:8001/services/api-service | grep -q 'id'; then
  echo "Creating API service..."
  curl -s -X POST http://kong:8001/services \
    -d "name=api-service" \
    -d "url=http://api:3000" \
    -d "connect_timeout=60000" \
    -d "read_timeout=60000" \
    -d "write_timeout=60000" \
    -d "retries=3"
  
  if [ $? -eq 0 ]; then
    echo "✅ API service created successfully!"
  else
    echo "❌ Failed to create API service"
    exit 1
  fi
else
  echo "API service already exists."
fi

# Create the main domain route for API
if ! curl -s http://kong:8001/routes/api-main-domain-route | grep -q 'id'; then
  echo "Creating API main domain route..."
  curl -s -X POST http://kong:8001/services/api-service/routes \
    -d "name=api-main-domain-route" \
    -d "hosts[]=dive25.local" \
    -d "paths[]=/api/v1" \
    -d "protocols[]=http" \
    -d "protocols[]=https" \
    -d "strip_path=false" \
    -d "preserve_host=false"
  
  if [ $? -eq 0 ]; then
    echo "✅ API main domain route created successfully!"
  else
    echo "❌ Failed to create API main domain route"
    exit 1
  fi
else
  echo "API main domain route already exists."
fi

echo "Kong routes setup completed successfully!"
exit 0 