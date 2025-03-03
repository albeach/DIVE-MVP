#!/bin/bash
set -e

echo "Updating Kong configuration for SSL..."

# Check if the certificates exist
if [ ! -f ./kong/certs/dive25-cert.pem ] || [ ! -f ./kong/certs/dive25-key.pem ]; then
    echo "SSL certificates not found. Please run ./scripts/setup-local-ssl.sh first."
    exit 1
fi

# Create Kong configuration directory if it doesn't exist
mkdir -p ./kong/config

# Create Kong SSL configuration
cat > ./kong/config/kong.conf << EOF
# Kong configuration for SSL

# Database settings
database = postgres
pg_host = kong-database
pg_port = 5432
pg_user = kong
pg_password = ${KONG_PG_PASSWORD:-kongpassword}
pg_database = kong

# SSL configuration
ssl_cert = /etc/kong/certs/dive25-cert.pem
ssl_cert_key = /etc/kong/certs/dive25-key.pem
proxy_ssl_enabled = on
admin_ssl_enabled = on

# Proxy settings
proxy_listen = 0.0.0.0:80, 0.0.0.0:443 ssl
admin_listen = 0.0.0.0:8001, 0.0.0.0:8444 ssl

# Allow tracking statistics for dashboard
anonymous_reports = off
EOF

echo "Kong SSL configuration created successfully!"

# Check if we need to update the docker-compose file for Kong
if ! grep -q "kong/config/kong.conf:/etc/kong/kong.conf" docker-compose.yml; then
    echo "Updating docker-compose.yml for Kong SSL configuration..."
    
    # Making a backup of the original file
    cp docker-compose.yml docker-compose.yml.bak
    
    # Replace Kong service configuration
    sed -i.bak '/service: kong/,/restart: unless-stopped/c\
  kong:\
    image: kong:latest\
    container_name: dive25-kong\
    environment:\
      KONG_DATABASE: postgres\
      KONG_PG_HOST: kong-database\
      KONG_PG_USER: kong\
      KONG_PG_PASSWORD: ${KONG_PG_PASSWORD:-kongpassword}\
      KONG_PROXY_ACCESS_LOG: /dev/stdout\
      KONG_ADMIN_ACCESS_LOG: /dev/stdout\
      KONG_PROXY_ERROR_LOG: /dev/stderr\
      KONG_ADMIN_ERROR_LOG: /dev/stderr\
    volumes:\
      - ./kong/config/kong.conf:/etc/kong/kong.conf:ro\
      - ./kong/certs:/etc/kong/certs:ro\
    ports:\
      - "80:80"\
      - "443:443"\
      - "8001:8001"\
      - "8444:8444"\
    depends_on:\
      - kong-database\
      - kong-migration\
    restart: unless-stopped\
    networks:\
      - dive25-network' docker-compose.yml
    
    rm -f docker-compose.yml.bak
    
    echo "Docker Compose configuration updated successfully!"
else
    echo "Docker Compose already configured for Kong SSL."
fi

echo ""
echo "SSL setup complete! You can now start the system with:"
echo "docker-compose up -d"
