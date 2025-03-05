#!/bin/bash

# Script to check SSL certificate coverage for Kong

CERT_FILE="./kong/certs/dive25-cert.pem"

if [ ! -f "$CERT_FILE" ]; then
  echo "Certificate file not found at $CERT_FILE"
  exit 1
fi

echo "Checking SSL certificate coverage for Kong..."
echo "Certificate file: $CERT_FILE"
echo ""

# Extract subject and SAN information
echo "Certificate details:"
openssl x509 -in "$CERT_FILE" -text -noout | grep -A1 "Subject:" 
echo ""
echo "Subject Alternative Names (SANs):"
openssl x509 -in "$CERT_FILE" -text -noout | grep -A1 "Subject Alternative Name:" 
echo ""

# Check if wildcard domain is covered
if openssl x509 -in "$CERT_FILE" -text -noout | grep -q "*.dive25.local"; then
  echo "✅ Certificate covers wildcard domain (*.dive25.local)"
else
  echo "❌ Certificate does NOT cover wildcard domain (*.dive25.local)"
  echo "You may need to regenerate your certificate to include wildcard domain support."
  echo ""
  echo "Example command to generate a new self-signed certificate with wildcard support:"
  echo "openssl req -x509 -nodes -days 365 -newkey rsa:2048 \\"
  echo "  -keyout ./kong/certs/dive25-key.pem \\"
  echo "  -out ./kong/certs/dive25-cert.pem \\"
  echo "  -subj '/CN=dive25.local' \\"
  echo "  -addext 'subjectAltName = DNS:dive25.local,DNS:*.dive25.local,DNS:localhost'"
fi

echo ""
echo "Remember to restart Kong after updating certificates:"
echo "docker-compose restart kong" 