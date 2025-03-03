#!/bin/bash
set -e

# Create necessary directories
mkdir -p certs
mkdir -p bootstrap/ldif
mkdir -p bootstrap/schema
mkdir -p bootstrap/config
mkdir -p bootstrap/config/admin
mkdir -p bootstrap/config/replication

# Generate self-signed certificates for LDAP TLS
if [ ! -f certs/ca.crt ]; then
  echo "Generating CA certificate..."
  openssl req -new -x509 -days 3650 -nodes -out certs/ca.crt -keyout certs/ca.key \
    -subj "/C=US/ST=State/L=City/O=DIVE25/CN=dive25-ca"
fi

if [ ! -f certs/server.crt ]; then
  echo "Generating server certificate..."
  openssl req -new -nodes -out certs/server.csr -keyout certs/server.key \
    -subj "/C=US/ST=State/L=City/O=DIVE25/CN=openldap"
  
  openssl x509 -req -days 3650 -in certs/server.csr -CA certs/ca.crt \
    -CAkey certs/ca.key -CAcreateserial -out certs/server.crt
fi

# Make bootstrap scripts executable
chmod +x bootstrap/setup.sh

# Check if LDIF files exist, copy them if needed
if [ ! -f bootstrap/ldif/01-dive25-structure.ldif ] || [ ! -f bootstrap/ldif/02-dive25-values.ldif ] || [ ! -f bootstrap/ldif/03-dive25-users.ldif ]; then
  echo "Copying LDIF files to bootstrap directory..."
  cp -n ./bootstrap/ldif/*.ldif bootstrap/ldif/ 2>/dev/null || true
fi

# Copy schema files if needed
if [ ! -f bootstrap/schema/dive25.schema ]; then
  echo "Copying schema files to bootstrap directory..."
  cp -n ./bootstrap/schema/*.schema bootstrap/schema/ 2>/dev/null || true
fi

# Generate password hashes for sample users
echo "Generating password hashes for sample users..."
SAMPLE_PASSWORD=${SAMPLE_PASSWORD:-password123}
HASH=$(./generate-passwords.sh $SAMPLE_PASSWORD | grep "{SSHA}" | awk '{print $NF}')
sed -i "s/{SSHA}xxxxxxxxxxxxxxxxxxxxxxxx/$HASH/g" bootstrap/ldif/03-dive25-users.ldif

echo "Starting OpenLDAP containers..."
docker-compose up -d

echo "Waiting for OpenLDAP to start..."
sleep 10

echo "Setup complete! You can access phpLDAPadmin at http://localhost:8085"
echo "Login with:"
echo "  Login DN: cn=admin,dc=dive25,dc=local"
echo "  Password: ${LDAP_ADMIN_PASSWORD:-admin_password}"
echo ""
echo "Sample users:"
echo "  - admin@dive25.local / $SAMPLE_PASSWORD"
echo "  - user1@dive25.local / $SAMPLE_PASSWORD"
echo "  - user2@dive25.local / $SAMPLE_PASSWORD"
