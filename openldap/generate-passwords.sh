#!/bin/bash

# Generate hashed password for LDAP users
# Usage: ./generate-passwords.sh <password>

PASSWORD=${1:-password123}

# Generate SSHA hash for OpenLDAP
SALT=$(openssl rand -base64 4)
SHA1=$(printf "%s%s" "$PASSWORD" "$SALT" | openssl dgst -binary -sha1)
HASH=$(printf "%s%s" "$SHA1" "$SALT" | base64)
SSHA_HASH="{SSHA}$HASH"

echo "Generated SSHA hash for password '$PASSWORD': $SSHA_HASH"
echo ""
echo "Update the userPassword attribute in 03-dive25-users.ldif with this hash"
