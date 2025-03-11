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
if ! docker-compose ps | grep -q "dive25-api.*Up"; then
  echo "Error: The DIVE25 API container is not running"
  echo "Please start the application with: docker-compose up -d"
  exit 1
fi

echo "Installing script dependencies..."
docker-compose exec api sh -c "cd /app/scripts && npm install"

echo "Generating $NUM_DOCS documents..."
docker-compose exec api sh -c "cd /app/scripts && DOCUMENT_COUNT=$NUM_DOCS node generate-sample-documents.js"

echo "Done!" 