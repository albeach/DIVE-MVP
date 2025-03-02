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
