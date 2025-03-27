#!/bin/bash

echo "=== DIVE25 Kong Diagnostics Script ==="
echo "This script helps diagnose Kong API Gateway routing issues"
echo

# Check Kong Status
echo "=== Kong Status Check ==="
KONG_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://kong:8000 || echo "Failed")
KONG_ADMIN_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://kong:8001 || echo "Failed")

if [[ "$KONG_STATUS" == "404" ]]; then
  echo "✅ Kong HTTP proxy is responding (status: $KONG_STATUS)"
else
  echo "❌ Kong HTTP proxy issue (status: $KONG_STATUS)"
fi

if [[ "$KONG_ADMIN_STATUS" == "200" ]]; then
  echo "✅ Kong Admin API is responding (status: $KONG_ADMIN_STATUS)"
else
  echo "❌ Kong Admin API issue (status: $KONG_ADMIN_STATUS)"
fi

# Check Services
echo -e "\n=== Kong Services ==="
SERVICES=$(curl -s http://kong:8001/services)
echo "$SERVICES" | jq -r '.data[] | "Service: \(.name) -> \(.protocol)://\(.host):\(.port)"'

# Check Routes
echo -e "\n=== Kong Routes ==="
ROUTES=$(curl -s http://kong:8001/routes)
echo "$ROUTES" | jq -r '.data[] | "Route: \(.name) \(.protocols) \(.paths // "no path") -> \(.hosts // "no hosts") (strip_path: \(.strip_path))"'

# Check Connectivity
echo -e "\n=== Connectivity Tests ==="
for SERVICE in $(echo "$SERVICES" | jq -r '.data[].name'); do
  SVC_INFO=$(echo "$SERVICES" | jq -r ".data[] | select(.name == \"$SERVICE\")")
  HOST=$(echo "$SVC_INFO" | jq -r '.host')
  PORT=$(echo "$SVC_INFO" | jq -r '.port')
  
  echo "Testing connectivity to $SERVICE ($HOST:$PORT)..."
  
  # TCP test with netcat
  if nc -z -w 2 $HOST $PORT; then
    echo "  ✅ TCP connection successful"
  else
    echo "  ❌ TCP connection failed"
  fi
  
  # HTTP test
  HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://$HOST:$PORT || echo "Failed")
  if [[ "$HTTP_STATUS" == "200" || "$HTTP_STATUS" == "301" || "$HTTP_STATUS" == "302" || "$HTTP_STATUS" == "307" || "$HTTP_STATUS" == "308" ]]; then
    echo "  ✅ HTTP test successful (status: $HTTP_STATUS)"
  else
    echo "  ⚠️ HTTP test response: $HTTP_STATUS"
  fi
done

# Check Host Resolution
echo -e "\n=== DNS Resolution ==="
for SERVICE in $(echo "$SERVICES" | jq -r '.data[].host'); do
  echo "$SERVICE: $(dig +short $SERVICE)"
done

# Get route hosts from Kong routes
echo -e "\n=== Virtual Host Tests ==="
for ROUTE_NAME in $(echo "$ROUTES" | jq -r '.data[].name'); do
  ROUTE_INFO=$(echo "$ROUTES" | jq -r ".data[] | select(.name == \"$ROUTE_NAME\")")
  SERVICE_ID=$(echo "$ROUTE_INFO" | jq -r '.service.id')
  SERVICE_NAME=$(echo "$SERVICES" | jq -r ".data[] | select(.id == \"$SERVICE_ID\") | .name")
  
  echo "Route $ROUTE_NAME -> Service $SERVICE_NAME:"
  
  # Test each host for this route
  HOSTS=$(echo "$ROUTE_INFO" | jq -r '.hosts[]? // empty')
  if [[ -n "$HOSTS" ]]; then
    while read -r HOST; do
      echo "  Testing host: $HOST"
      HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -H "Host: $HOST" http://kong:8000 || echo "Failed")
      echo "    Kong proxy with Host header: $HTTP_STATUS"
    done <<< "$HOSTS"
  else
    echo "  No hosts defined for this route"
  fi
done

echo -e "\n=== Kong Debug Log Entry Test ==="
# Make a request that will show in the logs
TIMESTAMP=$(date +%s)
curl -s -H "X-Debug-Test: $TIMESTAMP" http://kong:8000 > /dev/null
echo "Made debug request with timestamp $TIMESTAMP"
echo "Check logs with: docker logs dive25-staging-kong | grep $TIMESTAMP"

echo -e "\n=== Done ===" 