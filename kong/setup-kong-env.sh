#!/bin/bash
# setup-kong-env.sh

# Default to test environment if not specified
ENV_TYPE=${ENVIRONMENT:-test}

echo "Setting up Kong for environment: $ENV_TYPE"

# Select the appropriate environment file
if [ "$ENV_TYPE" = "dev" ]; then
  ENV_FILE=".env.dev"
elif [ "$ENV_TYPE" = "test" ]; then
  ENV_FILE=".env.test"
elif [ "$ENV_TYPE" = "prod" ]; then
  ENV_FILE=".env.prod"
else
  echo "Unknown environment type: $ENV_TYPE, defaulting to test"
  ENV_FILE=".env.test"
fi

# Copy the selected environment file to the active .env file
cp "$ENV_FILE" .env

echo "Environment configuration has been set to $ENV_TYPE using $ENV_FILE"

# Load the environment variables
set -a
source .env
set +a

echo "Loaded environment variables:"
echo "BASE_DOMAIN: $BASE_DOMAIN"
echo "PUBLIC_KEYCLOAK_URL: $PUBLIC_KEYCLOAK_URL"
echo "ENVIRONMENT: $ENVIRONMENT"

# Process the Kong configuration with environment variables
if [ -f "./process-config.sh" ]; then
  chmod +x ./process-config.sh
  ./process-config.sh
  echo "Kong configuration has been processed for $ENV_TYPE environment"
else
  echo "Warning: process-config.sh not found in current directory"
  echo "Kong configuration was not processed"
fi 