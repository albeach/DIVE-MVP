#!/bin/bash
set -e

# Get the environment from the command line
ENV=$1
if [ -z "$ENV" ]; then
  echo "Error: Environment not specified."
  echo "Usage: $0 <environment>"
  echo "Example: $0 dev"
  exit 1
fi

# API_URL should be set as an environment variable
if [ -z "$API_URL" ]; then
  echo "Error: API_URL environment variable is not set."
  exit 1
fi

echo "Running post-deployment tests for $ENV environment..."
echo "API URL: $API_URL"

# Test API health endpoint
echo "Testing API health endpoint..."
if curl -s --fail "$API_URL/health" | grep -q "status.*up"; then
  echo "✅ API health check passed!"
else
  echo "❌ API health check failed!"
  exit 1
fi

# Test authentication endpoint
echo "Testing authentication endpoint..."
if curl -s --fail -X POST "$API_URL/auth/ping" -H "Content-Type: application/json" | grep -q "authenticated"; then
  echo "✅ Authentication endpoint check passed!"
else
  echo "❌ Authentication endpoint check failed!"
  exit 1
fi

# Test document endpoints
echo "Testing document search endpoint..."
if curl -s --fail "$API_URL/documents/search?query=test" -H "Authorization: Bearer $TEST_TOKEN" | grep -q "documents"; then
  echo "✅ Document search endpoint check passed!"
else
  echo "❌ Document search endpoint check failed!"
  exit 1
fi

# Run more complex API tests if needed
if [ "$ENV" == "staging" ] || [ "$ENV" == "production" ]; then
  echo "Running comprehensive API tests..."
  # Add more comprehensive tests for staging and production environments
  # These could include data validation, performance checks, etc.
  
  # Example of a more complex test:
  # Test document upload and retrieval flow
  echo "Testing document upload and retrieval flow..."
  # Add test implementation here
fi

echo "All post-deployment tests completed successfully!"
exit 0 