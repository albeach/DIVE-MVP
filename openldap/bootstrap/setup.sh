#!/bin/bash
# This script is executed during the bootstrap process of OpenLDAP

# Import custom schema
echo "Importing DIVE25 custom schema..."
ldapadd -Y EXTERNAL -H ldapi:/// -f /container/service/slapd/assets/config/bootstrap/schema/dive25.schema.ldif

# Import base structure
echo "Importing base LDAP structure..."
ldapadd -x -D "cn=admin,dc=dive25,dc=local" -w ${LDAP_ADMIN_PASSWORD} -f /container/service/slapd/assets/config/bootstrap/ldif/01-dive25-structure.ldif

# Import security groups
echo "Importing security groups..."
ldapadd -x -D "cn=admin,dc=dive25,dc=local" -w ${LDAP_ADMIN_PASSWORD} -f /container/service/slapd/assets/config/bootstrap/ldif/02-dive25-security.ldif

# Import user data
echo "Importing user data..."
ldapadd -x -D "cn=admin,dc=dive25,dc=local" -w ${LDAP_ADMIN_PASSWORD} -f /container/service/slapd/assets/config/bootstrap/ldif/03-dive25-users.ldif

echo "Bootstrap process completed!"