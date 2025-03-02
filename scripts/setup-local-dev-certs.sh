#!/bin/bash
set -e

# This script sets up local development environment with:
# 1. Local hostname "dive25.local" with container-based subdomains
# 2. Self-signed certificates using mkcert for HTTPS without browser warnings
# 3. Kong configuration for SSL termination

# Check for required tools
command -v mkcert >/dev/null 2>&1 || { 
  echo "mkcert is required but not installed. Installing..." 
  
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    brew install mkcert nss
  elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux
    if command -v apt-get >/dev/null 2>&1; then
      sudo apt-get update
      sudo apt-get install -y libnss3-tools
      # Download mkcert binary for Linux
      curl -L https://github.com/FiloSottile/mkcert/releases/download/v1.4.3/mkcert-v1.4.3-linux-amd64 -o mkcert
      chmod +x mkcert
      sudo mv mkcert /usr/local/bin/
    elif command -v yum >/dev/null 2>&1; then
      sudo yum install nss-tools
      curl -L https://github.com/FiloSottile/mkcert/releases/download/v1.4.3/mkcert-v1.4.3-linux-amd64 -o mkcert
      chmod +x mkcert
      sudo mv mkcert /usr/local/bin/
    else
      echo "Unsupported Linux distribution. Please install mkcert manually."
      exit 1
    fi
  else
    echo "Unsupported OS. Please install mkcert manually."
    exit 1
  fi
}

echo "Setting up local development environment with dive25.local and SSL certificates"

# Create certs directory if it doesn't exist
mkdir -p ./certs

# Install mkcert CA
mkcert -install

# Create certificates for dive25.local and subdomains
echo "Creating certificates for dive25.local and subdomains..."
mkcert -cert-file ./certs/dive25-cert.pem -key-file ./certs/dive25-key.pem \
  "dive25.local" "*.dive25.local" \
  "api.dive25.local" "frontend.dive25.local" "keycloak.dive25.local" \
  "mongo-express.dive25.local" "grafana.dive25.local" "konga.dive25.local" \
  "prometheus.dive25.local" "phpldapadmin.dive25.local" "kong.dive25.local"

# Set up /etc/hosts entries
echo "Setting up /etc/hosts entries..."
HOSTS_ENTRY="127.0.0.1 dive25.local api.dive25.local frontend.dive25.local keycloak.dive25.local mongo-express.dive25.local grafana.dive25.local konga.dive25.local prometheus.dive25.local phpldapadmin.dive25.local kong.dive25.local"

if grep -q "dive25.local" /etc/hosts; then
  echo "Hosts entries already exist. Skipping."
else
  echo "Adding hosts entries to /etc/hosts"
  echo "You may be prompted for sudo password to modify /etc/hosts file"
  echo "$HOSTS_ENTRY" | sudo tee -a /etc/hosts
fi

# Create Kong configuration directory for certificates
mkdir -p ./kong/certs

# Copy certificates to Kong directory
cp ./certs/dive25-cert.pem ./kong/certs/
cp ./certs/dive25-key.pem ./kong/certs/

# Create Kong declarative configuration with routes for each subdomain
mkdir -p ./kong

cat > ./kong/kong.yml << 'EOF'
_format_version: "2.1"
_transform: true

services:
  # Frontend Service
  - name: frontend-service
    url: http://frontend:3000
    routes:
      - name: frontend-route
        hosts:
          - dive25.local
          - frontend.dive25.local
        protocols:
          - http
          - https
  
  # API Service
  - name: api-service
    url: http://api:3000
    routes:
      - name: api-route
        hosts:
          - api.dive25.local
        protocols:
          - http
          - https
  
  # Keycloak Service
  - name: keycloak-service
    url: http://keycloak:8080
    routes:
      - name: keycloak-route
        hosts:
          - keycloak.dive25.local
        protocols:
          - http
          - https
  
  # MongoDB Express Service
  - name: mongo-express-service
    url: http://mongo-express:8081
    routes:
      - name: mongo-express-route
        hosts:
          - mongo-express.dive25.local
        protocols:
          - http
          - https
  
  # Grafana Service
  - name: grafana-service
    url: http://grafana:3000
    routes:
      - name: grafana-route
        hosts:
          - grafana.dive25.local
        protocols:
          - http
          - https
  
  # Prometheus Service
  - name: prometheus-service
    url: http://prometheus:9090
    routes:
      - name: prometheus-route
        hosts:
          - prometheus.dive25.local
        protocols:
          - http
          - https
  
  # phpLDAPadmin Service
  - name: phpldapadmin-service
    url: http://phpldapadmin:80
    routes:
      - name: phpldapadmin-route
        hosts:
          - phpldapadmin.dive25.local
        protocols:
          - http
          - https
  
  # Kong Admin Service (exposed via subdomain)
  - name: kong-admin-service
    url: http://kong:8001
    routes:
      - name: kong-admin-route
        hosts:
          - kong.dive25.local
        protocols:
          - http
          - https
  
  # Konga Service
  - name: konga-service
    url: http://konga:1337
    routes:
      - name: konga-route
        hosts:
          - konga.dive25.local
        protocols:
          - http
          - https

# Redirects from HTTP to HTTPS
plugins:
  - name: redirect
    config:
      status_code: 301
      https_port: 8443
    enabled: true
    protocols:
      - http
EOF

# Now, let's update the docker-compose.yml to use SSL certificates with Kong
echo "Setup complete!"
echo "Next steps:"
echo "1. Update docker-compose.yml to mount SSL certificates in Kong"
echo "   (Use the update-docker-compose.sh script for this)"

# Create script to update docker-compose.yml for Kong
cat > ./scripts/update-kong-config.sh << 'EOF'
#!/bin/bash
set -e

echo "Updating docker-compose.yml to configure Kong for SSL termination..."

# Use a temporary file
TMP_FILE=$(mktemp)

# Update the Kong service to use SSL certificates
# This works by modifying the Kong service entry in docker-compose.yml
awk '
/kong:/ {
  inKong=1
}

/environment:/ && inKong {
  print $0
  print "      KONG_SSL_CERT: /etc/kong/certs/dive25-cert.pem"
  print "      KONG_SSL_CERT_KEY: /etc/kong/certs/dive25-key.pem"
  inEnvironment=1
  next
}

/volumes:/ && inKong {
  print $0
  print "      - ./kong/certs:/etc/kong/certs:ro"
  inVolumes=1
  next
}

/^  [^[:space:]]/ && inKong {
  inKong=0
}

{print}
' docker-compose.yml > "$TMP_FILE"

# Replace original file
mv "$TMP_FILE" docker-compose.yml

echo "Docker Compose file updated successfully!"
echo "Now you can run 'docker-compose up -d' to start all services with SSL"
EOF

# Make the update script executable
chmod +x ./scripts/update-kong-config.sh

echo "Done! Now run './scripts/update-kong-config.sh' to update the docker-compose.yml file." 