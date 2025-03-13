#!/bin/bash
# keycloak/configure-ldap-federation.sh
# Script to configure LDAP User Federation in Keycloak

set -e

echo "=============================================="
echo "DIVE25 - Keycloak LDAP Federation Configuration"
echo "=============================================="

# Default values for environment variables
KEYCLOAK_URL=${KEYCLOAK_URL:-"http://keycloak:8080"}
KEYCLOAK_REALM=${KEYCLOAK_REALM:-"dive25"}
KEYCLOAK_ADMIN=${KEYCLOAK_ADMIN:-"admin"}
KEYCLOAK_ADMIN_PASSWORD=${KEYCLOAK_ADMIN_PASSWORD:-"admin"}
LDAP_HOST=${LDAP_HOST:-"openldap"}
LDAP_PORT=${LDAP_PORT:-"389"}
LDAP_BIND_DN=${LDAP_BIND_DN:-"cn=admin,dc=dive25,dc=local"}
LDAP_BIND_CREDENTIAL=${LDAP_BIND_CREDENTIAL:-"admin_password"}
LDAP_BASE_DN=${LDAP_BASE_DN:-"dc=dive25,dc=local"}
LDAP_USER_DN=${LDAP_USER_DN:-"ou=users,dc=dive25,dc=local"}
LDAP_GROUP_DN=${LDAP_GROUP_DN:-"ou=groups,dc=dive25,dc=local"}

echo "Using the following configuration:"
echo "- Keycloak URL: $KEYCLOAK_URL"
echo "- Keycloak Realm: $KEYCLOAK_REALM"
echo "- LDAP Host: $LDAP_HOST"
echo "- LDAP Port: $LDAP_PORT"
echo "- LDAP Bind DN: $LDAP_BIND_DN"
echo "- LDAP Base DN: $LDAP_BASE_DN"
echo "- LDAP User DN: $LDAP_USER_DN"
echo "- LDAP Group DN: $LDAP_GROUP_DN"
echo

# Function to get admin token
get_admin_token() {
  echo "Getting admin token..."
  local token=$(curl -s -X POST "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "username=${KEYCLOAK_ADMIN}" \
    -d "password=${KEYCLOAK_ADMIN_PASSWORD}" \
    -d "grant_type=password" \
    -d "client_id=admin-cli" | grep -o '"access_token":"[^"]*"' | cut -d':' -f2 | tr -d '"')
    
  if [ -z "$token" ]; then
    echo "❌ Failed to get admin token"
    return 1
  fi
  
  echo "✅ Admin token acquired"
  echo "$token"
}

# Function to create LDAP user federation
create_ldap_federation() {
  local token=$1
  
  echo "Creating LDAP user federation component..."
  
  # Check if LDAP federation already exists
  local existing=$(curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/components?parent=${KEYCLOAK_REALM}&type=org.keycloak.storage.UserStorageProvider" \
    -H "Authorization: Bearer $token" | grep -o '"name":"DIVE25 LDAP"' || echo "")
  
  if [ -n "$existing" ]; then
    echo "LDAP federation already exists, updating configuration..."
    
    # Find the component ID
    local component_id=$(curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/components?parent=${KEYCLOAK_REALM}&type=org.keycloak.storage.UserStorageProvider" \
      -H "Authorization: Bearer $token" | grep -o '"id":"[^"]*"' | head -1 | cut -d':' -f2 | tr -d '"')
    
    # Update the component
    curl -s -X PUT "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/components/${component_id}" \
      -H "Authorization: Bearer $token" \
      -H "Content-Type: application/json" \
      -d '{
        "name": "DIVE25 LDAP",
        "providerId": "ldap",
        "providerType": "org.keycloak.storage.UserStorageProvider",
        "parentId": "'${KEYCLOAK_REALM}'",
        "config": {
          "enabled": ["true"],
          "priority": ["0"],
          "fullSyncPeriod": ["-1"],
          "changedSyncPeriod": ["-1"],
          "cachePolicy": ["DEFAULT"],
          "batchSizeForSync": ["1000"],
          "editMode": ["READ_ONLY"],
          "importEnabled": ["true"],
          "syncRegistrations": ["false"],
          "vendor": ["other"],
          "usernameLDAPAttribute": ["uid"],
          "rdnLDAPAttribute": ["uid"],
          "uuidLDAPAttribute": ["entryUUID"],
          "userObjectClasses": ["inetOrgPerson, organizationalPerson"],
          "connectionUrl": ["ldap://'${LDAP_HOST}':'${LDAP_PORT}'"],
          "usersDn": ["'${LDAP_USER_DN}'"],
          "authType": ["simple"],
          "bindDn": ["'${LDAP_BIND_DN}'"],
          "bindCredential": ["'${LDAP_BIND_CREDENTIAL}'"],
          "searchScope": ["1"],
          "useTruststoreSpi": ["ldapsOnly"],
          "connectionPooling": ["true"],
          "pagination": ["true"],
          "allowKerberosAuthentication": ["false"],
          "useKerberosForPasswordAuthentication": ["false"],
          "debug": ["false"],
          "validatePasswordPolicy": ["false"],
          "trustEmail": ["false"],
          "firstNameLDAPAttribute": ["givenName"],
          "lastNameLDAPAttribute": ["sn"],
          "emailLDAPAttribute": ["mail"]
        }
      }'
  else
    # Create new LDAP federation
    curl -s -X POST "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/components" \
      -H "Authorization: Bearer $token" \
      -H "Content-Type: application/json" \
      -d '{
        "name": "DIVE25 LDAP",
        "providerId": "ldap",
        "providerType": "org.keycloak.storage.UserStorageProvider",
        "parentId": "'${KEYCLOAK_REALM}'",
        "config": {
          "enabled": ["true"],
          "priority": ["0"],
          "fullSyncPeriod": ["-1"],
          "changedSyncPeriod": ["-1"],
          "cachePolicy": ["DEFAULT"],
          "batchSizeForSync": ["1000"],
          "editMode": ["READ_ONLY"],
          "importEnabled": ["true"],
          "syncRegistrations": ["false"],
          "vendor": ["other"],
          "usernameLDAPAttribute": ["uid"],
          "rdnLDAPAttribute": ["uid"],
          "uuidLDAPAttribute": ["entryUUID"],
          "userObjectClasses": ["inetOrgPerson, organizationalPerson"],
          "connectionUrl": ["ldap://'${LDAP_HOST}':'${LDAP_PORT}'"],
          "usersDn": ["'${LDAP_USER_DN}'"],
          "authType": ["simple"],
          "bindDn": ["'${LDAP_BIND_DN}'"],
          "bindCredential": ["'${LDAP_BIND_CREDENTIAL}'"],
          "searchScope": ["1"],
          "useTruststoreSpi": ["ldapsOnly"],
          "connectionPooling": ["true"],
          "pagination": ["true"],
          "allowKerberosAuthentication": ["false"],
          "useKerberosForPasswordAuthentication": ["false"],
          "debug": ["false"],
          "validatePasswordPolicy": ["false"],
          "trustEmail": ["false"],
          "firstNameLDAPAttribute": ["givenName"],
          "lastNameLDAPAttribute": ["sn"],
          "emailLDAPAttribute": ["mail"]
        }
      }'
  fi
  
  echo "✅ LDAP user federation configured successfully"
}

# Function to create LDAP role mappers
create_ldap_role_mappers() {
  local token=$1
  
  echo "Configuring LDAP role mappers..."
  
  # Get the LDAP component ID
  local ldap_component_id=$(curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/components?parent=${KEYCLOAK_REALM}&type=org.keycloak.storage.UserStorageProvider" \
    -H "Authorization: Bearer $token" | grep -o '"id":"[^"]*"' | head -1 | cut -d':' -f2 | tr -d '"')
  
  if [ -z "$ldap_component_id" ]; then
    echo "❌ LDAP component not found. Role mapper configuration skipped."
    return 1
  fi
  
  # Create group mapper
  echo "Creating LDAP group mapper..."
  curl -s -X POST "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/components" \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: application/json" \
    -d '{
      "name": "DIVE25 role groups",
      "providerId": "group-ldap-mapper",
      "providerType": "org.keycloak.storage.ldap.mappers.LDAPStorageMapper",
      "parentId": "'${ldap_component_id}'",
      "config": {
        "groups.dn": ["'${LDAP_GROUP_DN}'"],
        "group.name.ldap.attribute": ["cn"],
        "group.object.classes": ["groupOfNames"],
        "preserve.group.inheritance": ["true"],
        "membership.ldap.attribute": ["member"],
        "membership.attribute.type": ["DN"],
        "membership.user.ldap.attribute": ["uid"],
        "mode": ["READ_ONLY"],
        "user.roles.retrieve.strategy": ["LOAD_GROUPS_BY_MEMBER_ATTRIBUTE"],
        "mapped.group.attributes": [""]
      }
    }'
  
  echo "✅ LDAP role mappers configured successfully"
}

# Function to trigger LDAP sync
trigger_ldap_sync() {
  local token=$1
  
  echo "Triggering LDAP user synchronization..."
  
  # Get the LDAP component ID
  local ldap_component_id=$(curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/components?parent=${KEYCLOAK_REALM}&type=org.keycloak.storage.UserStorageProvider" \
    -H "Authorization: Bearer $token" | grep -o '"id":"[^"]*"' | head -1 | cut -d':' -f2 | tr -d '"')
  
  if [ -z "$ldap_component_id" ]; then
    echo "❌ LDAP component not found. Sync skipped."
    return 1
  fi
  
  # Trigger user sync
  curl -s -X POST "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/user-storage/${ldap_component_id}/sync?action=triggerFullSync" \
    -H "Authorization: Bearer $token"
  
  echo "✅ LDAP synchronization triggered"
}

# Main execution
# Get admin token
TOKEN=$(get_admin_token)
if [ -z "$TOKEN" ]; then
  echo "❌ Failed to get admin token. Exiting."
  exit 1
fi

# Create LDAP user federation
create_ldap_federation "$TOKEN"
if [ $? -ne 0 ]; then
  echo "❌ Failed to configure LDAP user federation. Exiting."
  exit 1
fi

# Create LDAP role mappers
create_ldap_role_mappers "$TOKEN"
if [ $? -ne 0 ]; then
  echo "❌ Warning: Failed to configure LDAP role mappers."
fi

# Trigger LDAP sync
trigger_ldap_sync "$TOKEN"
if [ $? -ne 0 ]; then
  echo "❌ Warning: Failed to trigger LDAP synchronization."
fi

echo "✅ LDAP federation setup completed successfully!"
exit 0 