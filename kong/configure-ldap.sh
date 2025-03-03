#!/bin/bash
set -e

KONG_ADMIN_URL=${KONG_ADMIN_URL:-http://localhost:8001}

echo "Configuring Kong with LDAP authentication..."

# Wait for Kong Admin API to be available
until curl -s $KONG_ADMIN_URL > /dev/null; do
  echo "Waiting for Kong Admin API to become available..."
  sleep 3
done

# Check if LDAP Auth plugin is installed
if ! curl -s $KONG_ADMIN_URL/plugins/enabled | grep -q ldap-auth; then
  echo "Error: ldap-auth plugin is not enabled in Kong"
  echo "Please ensure the plugin is properly installed"
  exit 1
fi

# Apply Kong LDAP configuration
echo "Applying LDAP configuration to Kong..."
curl -s -X POST $KONG_ADMIN_URL/config \
  -H "Content-Type: application/json" \
  -d @- << EOF
$(cat /etc/kong/ldap/kong.ldap.yml)
EOF

if [ $? -eq 0 ]; then
  echo "Kong LDAP configuration applied successfully"
else
  echo "Failed to apply Kong LDAP configuration"
  exit 1
fi

echo "Kong LDAP authentication setup complete" 