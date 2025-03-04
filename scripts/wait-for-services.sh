#!/bin/bash
set -e

# Maximum number of attempts
MAX_ATTEMPTS=30
# Delay between attempts in seconds
DELAY=5

# Function to check if a service is ready
check_service() {
  local service_name=$1
  local url=$2
  local attempt=1

  echo "Checking if $service_name is ready..."
  
  while [ $attempt -le $MAX_ATTEMPTS ]; do
    echo "Attempt $attempt of $MAX_ATTEMPTS..."
    
    if curl -s --head --request GET $url | grep "200\|301\|302\|307\|308" > /dev/null; then
      echo "$service_name is ready!"
      return 0
    fi
    
    echo "$service_name is not ready yet. Waiting $DELAY seconds..."
    sleep $DELAY
    attempt=$((attempt+1))
  done
  
  echo "Failed to connect to $service_name after $MAX_ATTEMPTS attempts."
  return 1
}

# Wait for the API service
check_service "API Service" "http://localhost:3000/api/health" || exit 1

# Wait for the Frontend service
check_service "Frontend Service" "http://localhost:8080/health" || exit 1

# All services are ready
echo "All services are up and running!"
exit 0