#!/bin/bash
set -e

# Script to setup SSL for Kong using existing certificate infrastructure

# Check if we're running from the correct directory
if [ ! -d "kong" ] && [ ! -d "../kong" ]; then
  echo "❌ Error: This script should be run from the project root or the kong directory"
  echo "Please cd to the correct directory and try again"
  exit 1
fi

echo "Setting up SSL certificates for Kong..."

# Determine the base directory
BASE_DIR="."
if [ ! -d "kong" ]; then
  BASE_DIR=".."
fi

# Create SSL directory structure
mkdir -p ${BASE_DIR}/kong/ssl

# Check if certs directory exists with certificates
if [ -d "${BASE_DIR}/kong/certs" ] && [ -f "${BASE_DIR}/kong/certs/dive25-cert.pem" ] && [ -f "${BASE_DIR}/kong/certs/dive25-key.pem" ]; then
  echo "✅ Found existing certificates in ${BASE_DIR}/kong/certs"
  
  # Copy certificates to Kong SSL directory
  echo "Copying certificates to ${BASE_DIR}/kong/ssl..."
  cp ${BASE_DIR}/kong/certs/dive25-cert.pem ${BASE_DIR}/kong/ssl/kong.crt
  cp ${BASE_DIR}/kong/certs/dive25-key.pem ${BASE_DIR}/kong/ssl/kong.key
  
  # Create CA certificates file
  if [ -f "/etc/ssl/certs/ca-certificates.crt" ]; then
    echo "Using system CA certificates"
    cp /etc/ssl/certs/ca-certificates.crt ${BASE_DIR}/kong/ssl/ca-certificates.crt
  elif [ "$(uname)" == "Darwin" ] && [ -f "/usr/local/etc/ca-certificates/cert.pem" ]; then
    echo "Using macOS CA certificates"
    cp /usr/local/etc/ca-certificates/cert.pem ${BASE_DIR}/kong/ssl/ca-certificates.crt
  else
    echo "⚠️ Warning: Could not find system CA certificates"
    echo "Creating an empty CA certificates file (may cause SSL verification issues)"
    touch ${BASE_DIR}/kong/ssl/ca-certificates.crt
  fi
  
else
  echo "No existing certificates found. Running certificate setup script..."
  
  # Check if the certificate setup script exists
  if [ -f "${BASE_DIR}/scripts/setup-local-ssl.sh" ]; then
    # Run the setup script to generate certificates
    cd ${BASE_DIR}
    bash ./scripts/setup-local-ssl.sh
    
    # Now copy the certificates to the kong/ssl directory
    mkdir -p ${BASE_DIR}/kong/ssl
    cp ${BASE_DIR}/kong/certs/dive25-cert.pem ${BASE_DIR}/kong/ssl/kong.crt
    cp ${BASE_DIR}/kong/certs/dive25-key.pem ${BASE_DIR}/kong/ssl/kong.key
    
    # Create CA certificates file
    if [ -f "/etc/ssl/certs/ca-certificates.crt" ]; then
      echo "Using system CA certificates"
      cp /etc/ssl/certs/ca-certificates.crt ${BASE_DIR}/kong/ssl/ca-certificates.crt
    elif [ "$(uname)" == "Darwin" ] && [ -f "/usr/local/etc/ca-certificates/cert.pem" ]; then
      echo "Using macOS CA certificates"
      cp /usr/local/etc/ca-certificates/cert.pem ${BASE_DIR}/kong/ssl/ca-certificates.crt
    else
      echo "⚠️ Warning: Could not find system CA certificates"
      echo "Creating an empty CA certificates file (may cause SSL verification issues)"
      touch ${BASE_DIR}/kong/ssl/ca-certificates.crt
    fi
  else
    echo "❌ Error: Certificate setup script not found at ${BASE_DIR}/scripts/setup-local-ssl.sh"
    echo "Please run the setup-local-dev-certs.sh or setup-local-ssl.sh script first"
    exit 1
  fi
fi

echo "✅ SSL setup complete for Kong!"
echo "Note: You may need to restart Kong for the changes to take effect"
echo "Command: docker-compose restart kong" 