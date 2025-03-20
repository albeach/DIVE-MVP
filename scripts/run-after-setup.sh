#!/bin/bash
# Run additional steps after setup-and-test-fixed.sh
# This script ensures our changes persist across deployments

# Get the API container ID
API_CONTAINER=$(docker ps | grep "api" | awk '{print $1}')

if [ -z "$API_CONTAINER" ]; then
    echo "Error: API container not found"
    exit 1
fi

echo "Found API container: $API_CONTAINER"

# Copy the updated seed script to the container
echo "Copying seed script to API container..."
docker cp scripts/seed-alice-documents.js $API_CONTAINER:/app/scripts/seed-documents.js

# Execute the seed script to create test documents
echo "Running seed script to create test documents for all users..."
docker exec $API_CONTAINER node /app/scripts/seed-documents.js

# Print success message
echo "✅ Setup complete: Test documents have been created for all users"
echo "You can now test access control with various user accounts" 