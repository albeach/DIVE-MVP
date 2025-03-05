#!/bin/bash

# Script to test Kong routing for wildcard domains
echo "Testing Kong routing for *.dive25.local domains..."

# Test with different subdomains
DOMAINS=(
  "test.dive25.local"
  "api.dive25.local"
  "frontend.dive25.local"
  "random-subdomain.dive25.local"
)

# Check if curl is installed
if ! command -v curl &> /dev/null; then
  echo "curl is required but not installed. Please install curl first."
  exit 1
fi

echo "Running Kong configuration test..."
# Check if Kong admin API is accessible
KONG_ADMIN="http://localhost:8001"
if ! curl -s -o /dev/null -w "%{http_code}" $KONG_ADMIN > /dev/null; then
  echo "❌ Cannot connect to Kong Admin API at $KONG_ADMIN"
  echo "Make sure Kong is running!"
  exit 1
fi

echo "✅ Kong Admin API is accessible"

# Fetch and display routes from Kong
echo "Retrieving configured routes from Kong:"
curl -s $KONG_ADMIN/routes | grep -E 'name|hosts' | sed 's/^[ \t]*//'

echo -e "\nTesting domain routing:"
for DOMAIN in "${DOMAINS[@]}"; do
  echo -e "\nTesting domain: $DOMAIN"
  # HTTP test
  HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -H "Host: $DOMAIN" http://localhost:80)
  if [ "$HTTP_STATUS" -eq 404 ] || [ "$HTTP_STATUS" -eq 000 ]; then
    echo "❌ HTTP: Got status $HTTP_STATUS for $DOMAIN - Route not matched"
  else
    echo "✅ HTTP: Got status $HTTP_STATUS for $DOMAIN - Route matched"
  fi
  
  # HTTPS test (with -k to ignore certificate validation)
  HTTPS_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -k -H "Host: $DOMAIN" https://localhost:443)
  if [ "$HTTPS_STATUS" -eq 404 ] || [ "$HTTPS_STATUS" -eq 000 ]; then
    echo "❌ HTTPS: Got status $HTTPS_STATUS for $DOMAIN - Route not matched"
  else
    echo "✅ HTTPS: Got status $HTTPS_STATUS for $DOMAIN - Route matched"
  fi
done

echo -e "\nChecking Kong logs for routing issues:"
echo "Run the following command to view recent logs:"
echo "docker logs dive25-kong | grep -E 'no Route matched|debug.router'" 