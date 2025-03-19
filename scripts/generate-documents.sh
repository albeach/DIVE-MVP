#!/bin/bash

# Script to run the document generator in the Docker environment

# Set the number of documents to generate (default: 300)
NUM_DOCS=${1:-300}

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
  echo "Error: Docker is not running or not accessible"
  exit 1
fi

# Check if the API container is running
if ! docker-compose ps | grep -q "dive25-staging-api.*Up"; then
  echo "Error: The DIVE25 API container is not running"
  echo "Please start the application with: docker-compose up -d"
  exit 1
fi

# Create a temporary package.json for the script
echo '{
  "dependencies": {
    "mongoose": "^7.0.0",
    "uuid": "^9.0.0",
    "faker": "^5.5.3",
    "dotenv": "^16.0.0"
  }
}' > scripts/temp-package.json

# Copy files to the container
echo "Copying files to container..."
docker cp scripts/generate-sample-documents.js dive25-staging-api:/app/scripts/
docker cp scripts/temp-package.json dive25-staging-api:/app/scripts/package.json

# Clean up temporary package.json
rm scripts/temp-package.json

echo "Installing script dependencies..."
docker-compose exec api sh -c "cd /app/scripts && npm install"

echo "Generating $NUM_DOCS documents..."
docker-compose exec api sh -c "cd /app/scripts && DOCUMENT_COUNT=$NUM_DOCS node generate-sample-documents.js"

echo "Done!" 