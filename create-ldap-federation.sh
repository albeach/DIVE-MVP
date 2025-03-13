#!/bin/bash
set -e

echo "Adding custom mappers to existing LDAP federation in Keycloak..."

# Get admin token
TOKEN=$(curl -s -X POST "http://dive25-staging-keycloak:8080/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=admin" \
  -d "password=admin" \
  -d "grant_type=password" \
  -d "client_id=admin-cli" | grep -o '"access_token":"[^"]*"' | cut -d':' -f2 | tr -d '"')

if [ -z "$TOKEN" ]; then
  echo "Failed to get admin token"
  exit 1
fi

echo "Admin token acquired: ${TOKEN:0:10}..."

# Use the existing component ID
COMPONENT_ID="c43200c5-2949-478d-9e7b-1bd04d0ebd6b"
echo "Using existing LDAP component ID: $COMPONENT_ID"

# First, let's check if the component exists
echo "Verifying component exists..."
COMPONENT_CHECK=$(curl -s -X GET "http://dive25-staging-keycloak:8080/admin/realms/dive25/components/$COMPONENT_ID" \
  -H "Authorization: Bearer $TOKEN")

if [[ "$COMPONENT_CHECK" == *"error"* ]]; then
  echo "Error checking component. Response: $COMPONENT_CHECK"
  exit 1
fi

echo "Component exists. Adding custom attribute mappers..."

# Create displayName mapper
MAPPER_DISPLAYNAME_CONFIG='{
  "name": "display name",
  "providerId": "user-attribute-ldap-mapper",
  "providerType": "org.keycloak.storage.ldap.mappers.LDAPStorageMapper",
  "parentId": "'$COMPONENT_ID'",
  "config": {
    "ldap.attribute": ["displayName"],
    "is.mandatory.in.ldap": ["false"],
    "always.read.value.from.ldap": ["true"],
    "read.only": ["true"],
    "user.model.attribute": ["displayName"]
  }
}'

echo "Creating displayName mapper..."
RESPONSE=$(curl -s -X POST "http://dive25-staging-keycloak:8080/admin/realms/dive25/components" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "$MAPPER_DISPLAYNAME_CONFIG")
echo "Response: $RESPONSE"

# Create description mapper
MAPPER_DESCRIPTION_CONFIG='{
  "name": "description",
  "providerId": "user-attribute-ldap-mapper",
  "providerType": "org.keycloak.storage.ldap.mappers.LDAPStorageMapper",
  "parentId": "'$COMPONENT_ID'",
  "config": {
    "ldap.attribute": ["description"],
    "is.mandatory.in.ldap": ["false"],
    "always.read.value.from.ldap": ["true"],
    "read.only": ["true"],
    "user.model.attribute": ["description"]
  }
}'

echo "Creating description mapper..."
RESPONSE=$(curl -s -X POST "http://dive25-staging-keycloak:8080/admin/realms/dive25/components" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "$MAPPER_DESCRIPTION_CONFIG")
echo "Response: $RESPONSE"

# Create clearance mapper
MAPPER_CLEARANCE_CONFIG='{
  "name": "clearance",
  "providerId": "user-attribute-ldap-mapper",
  "providerType": "org.keycloak.storage.ldap.mappers.LDAPStorageMapper",
  "parentId": "'$COMPONENT_ID'",
  "config": {
    "ldap.attribute": ["clearanceLevel"],
    "is.mandatory.in.ldap": ["false"],
    "always.read.value.from.ldap": ["true"],
    "read.only": ["true"],
    "user.model.attribute": ["clearance"]
  }
}'

echo "Creating clearance mapper..."
RESPONSE=$(curl -s -X POST "http://dive25-staging-keycloak:8080/admin/realms/dive25/components" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "$MAPPER_CLEARANCE_CONFIG")
echo "Response: $RESPONSE"

# Create country of affiliation mapper
MAPPER_COUNTRY_CONFIG='{
  "name": "countryOfAffiliation",
  "providerId": "user-attribute-ldap-mapper",
  "providerType": "org.keycloak.storage.ldap.mappers.LDAPStorageMapper",
  "parentId": "'$COMPONENT_ID'",
  "config": {
    "ldap.attribute": ["countryCode"],
    "is.mandatory.in.ldap": ["false"],
    "always.read.value.from.ldap": ["true"],
    "read.only": ["true"],
    "user.model.attribute": ["countryOfAffiliation"]
  }
}'

echo "Creating countryOfAffiliation mapper..."
RESPONSE=$(curl -s -X POST "http://dive25-staging-keycloak:8080/admin/realms/dive25/components" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "$MAPPER_COUNTRY_CONFIG")
echo "Response: $RESPONSE"

# Create coi mapper
MAPPER_COI_CONFIG='{
  "name": "coi",
  "providerId": "user-attribute-ldap-mapper",
  "providerType": "org.keycloak.storage.ldap.mappers.LDAPStorageMapper",
  "parentId": "'$COMPONENT_ID'",
  "config": {
    "ldap.attribute": ["coi"],
    "is.mandatory.in.ldap": ["false"],
    "always.read.value.from.ldap": ["true"],
    "read.only": ["true"],
    "user.model.attribute": ["coi"]
  }
}'

echo "Creating coi mapper..."
RESPONSE=$(curl -s -X POST "http://dive25-staging-keycloak:8080/admin/realms/dive25/components" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "$MAPPER_COI_CONFIG")
echo "Response: $RESPONSE"

# Create caveats mapper
MAPPER_CAVEATS_CONFIG='{
  "name": "caveats",
  "providerId": "user-attribute-ldap-mapper",
  "providerType": "org.keycloak.storage.ldap.mappers.LDAPStorageMapper",
  "parentId": "'$COMPONENT_ID'",
  "config": {
    "ldap.attribute": ["caveats"],
    "is.mandatory.in.ldap": ["false"],
    "always.read.value.from.ldap": ["true"],
    "read.only": ["true"],
    "user.model.attribute": ["caveats"]
  }
}'

echo "Creating caveats mapper..."
RESPONSE=$(curl -s -X POST "http://dive25-staging-keycloak:8080/admin/realms/dive25/components" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "$MAPPER_CAVEATS_CONFIG")
echo "Response: $RESPONSE"

# Create role mapper
MAPPER_ROLE_CONFIG='{
  "name": "dive25Role",
  "providerId": "user-attribute-ldap-mapper",
  "providerType": "org.keycloak.storage.ldap.mappers.LDAPStorageMapper",
  "parentId": "'$COMPONENT_ID'",
  "config": {
    "ldap.attribute": ["dive25Role"],
    "is.mandatory.in.ldap": ["false"],
    "always.read.value.from.ldap": ["true"],
    "read.only": ["true"],
    "user.model.attribute": ["dive25Role"]
  }
}'

echo "Creating dive25Role mapper..."
RESPONSE=$(curl -s -X POST "http://dive25-staging-keycloak:8080/admin/realms/dive25/components" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "$MAPPER_ROLE_CONFIG")
echo "Response: $RESPONSE"

# Create LDAP group mapper
MAPPER_CONFIG='{
  "name": "DIVE25 groups",
  "providerId": "group-ldap-mapper",
  "providerType": "org.keycloak.storage.ldap.mappers.LDAPStorageMapper",
  "parentId": "'$COMPONENT_ID'",
  "config": {
    "groups.dn": ["ou=groups,dc=dive25,dc=local"],
    "group.name.ldap.attribute": ["cn"],
    "group.object.classes": ["groupOfNames"],
    "preserve.group.inheritance": ["true"],
    "membership.ldap.attribute": ["member"],
    "membership.attribute.type": ["DN"],
    "membership.user.ldap.attribute": ["uid"],
    "groups.path": ["/"],
    "mode": ["READ_ONLY"],
    "user.roles.retrieve.strategy": ["LOAD_GROUPS_BY_MEMBER_ATTRIBUTE"],
    "mapped.group.attributes": [""]
  }
}'

echo "Creating LDAP group mapper..."
RESPONSE=$(curl -s -X POST "http://dive25-staging-keycloak:8080/admin/realms/dive25/components" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "$MAPPER_CONFIG")
echo "Response: $RESPONSE"

# Give the system a moment to process
echo "Waiting for changes to process..."
sleep 5

# Trigger sync
echo "Triggering LDAP sync..."
SYNC_RESPONSE=$(curl -s -X POST "http://dive25-staging-keycloak:8080/admin/realms/dive25/user-storage/$COMPONENT_ID/sync?action=triggerFullSync" \
  -H "Authorization: Bearer $TOKEN")

echo "Sync Response: $SYNC_RESPONSE"

# Check users after sync
echo "Checking for users after sync..."
USERS_RESPONSE=$(curl -s -X GET "http://dive25-staging-keycloak:8080/admin/realms/dive25/users" \
  -H "Authorization: Bearer $TOKEN")

echo "Users after sync: $USERS_RESPONSE"

echo "Custom LDAP mappers setup completed"
exit 0 