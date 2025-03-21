#!/bin/bash
set -e

echo "Applying Kong configuration from kong.yml..."

# Use curl_tools container to interact with Kong
CURL_TOOLS_CONTAINER="dive25-curl-tools"
KONG_ADMIN_URL="http://kong:8001"

# Ensure curl tools container is running
if ! docker ps | grep -q "$CURL_TOOLS_CONTAINER"; then
  echo "curl_tools container not running. Starting it now..."
  docker-compose up -d curl_tools
  sleep 5
fi

# First, let's check current services
echo "Current Kong services:"
docker exec $CURL_TOOLS_CONTAINER curl -s $KONG_ADMIN_URL/services | jq '.data[].name'

# Function to create a service from the kong.yml file
create_service() {
  local name=$1
  local url=$2
  
  echo "Creating service: $name with URL: $url"
  
  # Check if service already exists
  if docker exec $CURL_TOOLS_CONTAINER curl -s $KONG_ADMIN_URL/services/$name | grep -q "id"; then
    echo "Service $name already exists, updating..."
    docker exec $CURL_TOOLS_CONTAINER curl -s -X PATCH $KONG_ADMIN_URL/services/$name \
      -d name=$name -d url=$url
  else
    echo "Creating new service: $name"
    docker exec $CURL_TOOLS_CONTAINER curl -s -X POST $KONG_ADMIN_URL/services \
      -d name=$name -d url=$url
  fi
}

# Function to create a route for a service
create_route() {
  local service_name=$1
  local route_name=$2
  local hosts=$3
  local protocols=$4
  
  echo "Creating route: $route_name for service: $service_name"
  
  # Split hosts by comma
  IFS=',' read -ra HOST_ARRAY <<< "$hosts"
  
  # Build the hosts parameters
  local host_params=""
  for host in "${HOST_ARRAY[@]}"; do
    host_params="$host_params -d hosts[]=$host"
  done
  
  # Build the protocols parameters
  local protocol_params=""
  if [[ "$protocols" == *","* ]]; then
    IFS=',' read -ra PROTOCOL_ARRAY <<< "$protocols"
    for protocol in "${PROTOCOL_ARRAY[@]}"; do
      protocol_params="$protocol_params -d protocols[]=$protocol"
    done
  else
    protocol_params="-d protocols[]=$protocols"
  fi
  
  # Check if route already exists
  if docker exec $CURL_TOOLS_CONTAINER curl -s $KONG_ADMIN_URL/routes/$route_name | grep -q "id"; then
    echo "Route $route_name already exists, updating..."
    docker exec $CURL_TOOLS_CONTAINER sh -c "curl -s -X PATCH $KONG_ADMIN_URL/routes/$route_name \
      -d name=$route_name $host_params $protocol_params -d \"service.name=$service_name\""
  else
    echo "Creating new route: $route_name"
    docker exec $CURL_TOOLS_CONTAINER sh -c "curl -s -X POST $KONG_ADMIN_URL/services/$service_name/routes \
      -d name=$route_name $host_params $protocol_params"
  fi
}

# Function to create a global plugin
create_global_plugin() {
  local name=$1
  local config=$2
  local protocols=$3
  
  echo "Creating global plugin: $name"
  
  # Build the protocols parameters
  local protocol_params=""
  if [ -n "$protocols" ]; then
    if [[ "$protocols" == *","* ]]; then
      IFS=',' read -ra PROTOCOL_ARRAY <<< "$protocols"
      for protocol in "${PROTOCOL_ARRAY[@]}"; do
        protocol_params="$protocol_params -d protocols[]=$protocol"
      done
    else
      protocol_params="-d protocols[]=$protocols"
    fi
  fi
  
  # Get existing plugins of this type
  local existing_plugins=$(docker exec $CURL_TOOLS_CONTAINER curl -s $KONG_ADMIN_URL/plugins?name=$name)
  
  if echo "$existing_plugins" | jq -e '.data[0]' > /dev/null; then
    local plugin_id=$(echo "$existing_plugins" | jq -r '.data[0].id')
    echo "Plugin $name already exists with ID $plugin_id, updating..."
    docker exec $CURL_TOOLS_CONTAINER sh -c "curl -s -X PATCH $KONG_ADMIN_URL/plugins/$plugin_id \
      -d name=$name -d 'config=$config' $protocol_params"
  else
    echo "Creating new plugin: $name"
    # First check if the plugin is installed
    if docker exec $CURL_TOOLS_CONTAINER curl -s $KONG_ADMIN_URL/plugins/enabled | grep -q "\"$name\""; then
      docker exec $CURL_TOOLS_CONTAINER sh -c "curl -s -X POST $KONG_ADMIN_URL/plugins \
        -d name=$name -d 'config=$config' $protocol_params"
    else
      echo "Plugin $name is not enabled in Kong, skipping..."
    fi
  fi
}

# Create all services from our configuration
echo "Setting up Frontend Service"
create_service "frontend-service" "http://frontend:3000"
create_route "frontend-service" "frontend-route" "dive25.local,frontend.dive25.local" "http,https"

echo "Setting up API Service"
create_service "api-service" "http://api:3000"
create_route "api-service" "api-route" "api.dive25.local" "http,https"

echo "Setting up Keycloak Service"
create_service "keycloak-service" "http://keycloak:8080"
create_route "keycloak-service" "keycloak-route" "keycloak.dive25.local" "http,https"

echo "Setting up MongoDB Express Service"
create_service "mongo-express-service" "http://mongo-express:8081"
create_route "mongo-express-service" "mongo-express-route" "mongo-express.dive25.local" "http,https"

echo "Setting up Grafana Service"
create_service "grafana-service" "http://grafana:3000"
create_route "grafana-service" "grafana-route" "grafana.dive25.local" "http,https"

echo "Setting up Prometheus Service"
create_service "prometheus-service" "http://prometheus:9090"
create_route "prometheus-service" "prometheus-route" "prometheus.dive25.local" "http,https"

echo "Setting up phpLDAPadmin Service"
create_service "phpldapadmin-service" "http://phpldapadmin:80"
create_route "phpldapadmin-service" "phpldapadmin-route" "phpldapadmin.dive25.local" "http,https"

echo "Setting up Kong Admin Service"
create_service "kong-admin-service" "http://kong:8001"
create_route "kong-admin-service" "kong-admin-route" "kong.dive25.local" "http,https"

echo "Setting up Konga Service"
create_service "konga-service" "http://konga:1337"
create_route "konga-service" "konga-route" "konga.dive25.local" "http,https"

# Set up the HTTP to HTTPS redirect plugin
echo "Setting up HTTP to HTTPS redirect plugin"
create_global_plugin "redirect" '{"status_code":301,"https_port":8443}' "http"

echo "Kong configuration applied successfully!"

# Now list all services and routes to verify
echo -e "\nCurrent Kong services after configuration:"
docker exec $CURL_TOOLS_CONTAINER curl -s $KONG_ADMIN_URL/services | jq '.data[].name'

echo -e "\nCurrent Kong routes after configuration:"
docker exec $CURL_TOOLS_CONTAINER curl -s $KONG_ADMIN_URL/routes | jq '.data[].name'

echo -e "\nCurrent Kong plugins after configuration:"
docker exec $CURL_TOOLS_CONTAINER curl -s $KONG_ADMIN_URL/plugins | jq '.data[].name' 