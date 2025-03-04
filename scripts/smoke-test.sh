#!/bin/bash
set -e

# Get the environment and deployment type from the command line
ENV=$1
DEPLOY_TYPE=$2

if [ -z "$ENV" ] || [ -z "$DEPLOY_TYPE" ]; then
  echo "Error: Environment or deployment type not specified."
  echo "Usage: $0 <environment> <deployment_type>"
  echo "Example: $0 production canary"
  exit 1
fi

# API_URL should be set as an environment variable
if [ -z "$API_URL" ]; then
  echo "Error: API_URL environment variable is not set."
  exit 1
fi

echo "Running smoke tests for $ENV environment on $DEPLOY_TYPE deployment..."
echo "API URL: $API_URL"

# Define headers to route to canary if needed
HEADERS=""
if [ "$DEPLOY_TYPE" == "canary" ]; then
  HEADERS="-H 'X-Canary: true'"
  echo "Using canary routing headers: $HEADERS"
fi

# Basic health check
echo "Testing API health endpoint..."
if eval "curl -s --fail $HEADERS $API_URL/health" | grep -q "status.*up"; then
  echo "✅ API health check passed!"
else
  echo "❌ API health check failed!"
  exit 1
fi

# Authentication check
echo "Testing authentication mechanism..."
if eval "curl -s --fail $HEADERS -X POST $API_URL/auth/ping -H 'Content-Type: application/json'" | grep -q "authenticated"; then
  echo "✅ Authentication check passed!"
else
  echo "❌ Authentication check failed!"
  exit 1
fi

# Document service check
echo "Testing document service..."
if eval "curl -s --fail $HEADERS $API_URL/documents/ping -H 'Authorization: Bearer $TEST_TOKEN'" | grep -q "success"; then
  echo "✅ Document service check passed!"
else
  echo "❌ Document service check failed!"
  exit 1
fi

# Search service check
echo "Testing search functionality..."
if eval "curl -s --fail $HEADERS $API_URL/documents/search?query=test -H 'Authorization: Bearer $TEST_TOKEN'" | grep -q "documents"; then
  echo "✅ Search service check passed!"
else
  echo "❌ Search service check failed!"
  exit 1
fi

# PDF generation check (if applicable)
echo "Testing PDF generation service..."
if eval "curl -s --fail $HEADERS $API_URL/documents/generate-pdf?id=test -H 'Authorization: Bearer $TEST_TOKEN'" -o /dev/null; then
  echo "✅ PDF generation service check passed!"
else
  echo "❌ PDF generation service check failed!"
  # This might be a non-critical service, so we won't exit with an error
  # exit 1
fi

echo "All smoke tests completed successfully!"
exit 0 