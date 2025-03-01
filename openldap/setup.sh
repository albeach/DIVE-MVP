#!/bin/bash

# Create certificates directory if it doesn't exist
mkdir -p certs

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

# Ensure bootstrap directory exists
mkdir -p bootstrap

# Generate password hashes for sample users
echo "Generating password hashes for sample users..."
HASH=$(./generate-passwords.sh password123 | grep "{SSHA}" | awk '{print $NF}')
sed -i "s/{SSHA}xxxxxxxxxxxxxxxxxxxxxxxx/$HASH/g" bootstrap/03-dive25-users.ldif

echo "Starting OpenLDAP containers..."
docker-compose up -d

echo "Waiting for OpenLDAP to start..."
sleep 10

echo "Setup complete! You can access phpLDAPadmin at http://localhost:8085"
echo "Login with:"
echo "  Login DN: cn=admin,dc=dive25,dc=local"
echo "  Password: admin_password"
