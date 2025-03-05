#!/bin/sh
set -e

# Export all environment variables with defaults
export BASE_DOMAIN=${BASE_DOMAIN:-dive25.local}
export INTERNAL_FRONTEND_URL=${INTERNAL_FRONTEND_URL:-http://dive25-frontend:3000}
export INTERNAL_API_URL=${INTERNAL_API_URL:-http://dive25-backend:8000}
export INTERNAL_KEYCLOAK_URL=${INTERNAL_KEYCLOAK_URL:-http://keycloak:8080}
export PUBLIC_KEYCLOAK_URL=${PUBLIC_KEYCLOAK_URL:-https://keycloak.dive25.local}
export PUBLIC_FRONTEND_URL=${PUBLIC_FRONTEND_URL:-https://dive25.local}
export PUBLIC_API_URL=${PUBLIC_API_URL:-https://api.dive25.local}
export KEYCLOAK_REALM=${KEYCLOAK_REALM:-dive25}
export KEYCLOAK_CLIENT_ID=${KEYCLOAK_CLIENT_ID:-dive25-frontend}
export KEYCLOAK_CLIENT_SECRET=${KEYCLOAK_CLIENT_SECRET:-change-me-in-production}
export KEYCLOAK_CLIENT_ID_API=${KEYCLOAK_CLIENT_ID_API:-dive25-api}

echo "Kong configuration processing starting..."
echo "Using the following configuration variables:"
echo "BASE_DOMAIN: $BASE_DOMAIN"
echo "INTERNAL_FRONTEND_URL: $INTERNAL_FRONTEND_URL"
echo "INTERNAL_API_URL: $INTERNAL_API_URL"
echo "INTERNAL_KEYCLOAK_URL: $INTERNAL_KEYCLOAK_URL"
echo "PUBLIC_KEYCLOAK_URL: $PUBLIC_KEYCLOAK_URL"
echo "PUBLIC_FRONTEND_URL: $PUBLIC_FRONTEND_URL"
echo "PUBLIC_API_URL: $PUBLIC_API_URL"
echo "KEYCLOAK_REALM: $KEYCLOAK_REALM"
echo "KEYCLOAK_CLIENT_ID: $KEYCLOAK_CLIENT_ID"
echo "KEYCLOAK_CLIENT_ID_API: $KEYCLOAK_CLIENT_ID_API"

# Process the template file
TEMPLATE_FILE="/etc/kong/kong.yml.template"
CONFIG_FILE="/etc/kong/kong.yml"

if [ -f "$TEMPLATE_FILE" ]; then
  echo "Found template file at $TEMPLATE_FILE"
  
  # Check if envsubst is available
  if ! command -v envsubst >/dev/null 2>&1; then
    echo "Error: envsubst command not found. Make sure gettext-base is installed."
    exit 1
  fi
  
  # Create a backup of the template file
  cp "$TEMPLATE_FILE" "${TEMPLATE_FILE}.bak" || echo "Warning: Failed to create backup of template file"
  
  # Process the template with environment variable substitution
  echo "Processing template and writing to $CONFIG_FILE"
  envsubst < "$TEMPLATE_FILE" > "$CONFIG_FILE"
  
  # Verify the config file was created successfully
  if [ -f "$CONFIG_FILE" ]; then
    echo "✅ Template processing completed successfully"
    
    # Check file size to ensure it's not empty
    CONFIG_SIZE=$(wc -c < "$CONFIG_FILE")
    if [ "$CONFIG_SIZE" -lt 10 ]; then
      echo "⚠️ Warning: Config file is very small (${CONFIG_SIZE} bytes)."
      echo "This may indicate a problem with variable substitution."
      echo "Check template file for proper variable syntax (should use \${VARIABLE_NAME})."
    else
      echo "Config file size: ${CONFIG_SIZE} bytes (looks good)"
    fi
  else
    echo "❌ Error: Failed to create config file"
    exit 1
  fi
else
  echo "❌ Error: Template file $TEMPLATE_FILE not found"
  echo "🔍 Available files in /etc/kong/:"
  ls -la /etc/kong/
  
  # If we have a non-template config file, use that
  if [ -f "/etc/kong/kong.yml" ]; then
    echo "Found direct config file at /etc/kong/kong.yml. Using as-is."
  else
    echo "No config file found. Kong may use default configuration or fail."
  fi
fi

# Start Kong with the generated config
echo "Starting Kong..."

# Execute the original entrypoint with all arguments
exec /docker-entrypoint.sh "$@"
