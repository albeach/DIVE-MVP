#!/bin/bash
# Direct script to configure mock IdP

set -e

# Copy our configuration script to the curl-tools container
docker cp keycloak/configure-mock-idp.sh dive25-curl-tools:/configure-mock-idp.sh
docker exec dive25-curl-tools chmod +x /configure-mock-idp.sh

# Set up environment variables for execution
docker exec \
  -e KEYCLOAK_URL="http://keycloak:8080" \
  -e KEYCLOAK_ADMIN="admin" \
  -e KEYCLOAK_ADMIN_PASSWORD="admin" \
  -e CURL_TOOLS_CONTAINER="dive25-curl-tools" \
  dive25-curl-tools /bin/sh -c "/configure-mock-idp.sh"

echo "✅ Mock IdP configuration executed" 