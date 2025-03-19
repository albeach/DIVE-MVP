#!/bin/bash
# Script to set up protocol mappers in Keycloak

# Configure mappers for clearance, caveats, coi, etc.
echo "Getting frontend client ID..."
docker exec -it dive25-staging-keycloak /bin/bash -c "
cd /opt/keycloak && 
/opt/keycloak/bin/kcadm.sh config credentials --server http://localhost:8080 --realm master --user admin --password admin && 
CLIENT_ID=\$(/opt/keycloak/bin/kcadm.sh get clients -r dive25 --fields id,clientId | grep -A1 dive25-frontend | grep id | cut -d '\\\"' -f4) && 
echo \"Frontend client ID: \$CLIENT_ID\" &&

echo 'Creating clearance mapper...' &&
/opt/keycloak/bin/kcadm.sh create clients/\$CLIENT_ID/protocol-mappers/models -r dive25 -s name=clearance-mapper -s protocol=openid-connect -s protocolMapper=oidc-usermodel-attribute-mapper -s 'config={\"userinfo.token.claim\":\"true\",\"user.attribute\":\"clearance\",\"id.token.claim\":\"true\",\"access.token.claim\":\"true\",\"claim.name\":\"clearance\",\"jsonType.label\":\"String\"}' &&

echo 'Creating caveats mapper...' &&
/opt/keycloak/bin/kcadm.sh create clients/\$CLIENT_ID/protocol-mappers/models -r dive25 -s name=caveats-mapper -s protocol=openid-connect -s protocolMapper=oidc-usermodel-attribute-mapper -s 'config={\"userinfo.token.claim\":\"true\",\"user.attribute\":\"caveats\",\"id.token.claim\":\"true\",\"access.token.claim\":\"true\",\"claim.name\":\"caveats\",\"jsonType.label\":\"JSON\"}' &&

echo 'Creating coi mapper...' &&
/opt/keycloak/bin/kcadm.sh create clients/\$CLIENT_ID/protocol-mappers/models -r dive25 -s name=coi-mapper -s protocol=openid-connect -s protocolMapper=oidc-usermodel-attribute-mapper -s 'config={\"userinfo.token.claim\":\"true\",\"user.attribute\":\"coi\",\"id.token.claim\":\"true\",\"access.token.claim\":\"true\",\"claim.name\":\"coi\",\"jsonType.label\":\"JSON\"}' &&

echo 'Creating organization mapper...' &&
/opt/keycloak/bin/kcadm.sh create clients/\$CLIENT_ID/protocol-mappers/models -r dive25 -s name=organization-mapper -s protocol=openid-connect -s protocolMapper=oidc-usermodel-attribute-mapper -s 'config={\"userinfo.token.claim\":\"true\",\"user.attribute\":\"organization\",\"id.token.claim\":\"true\",\"access.token.claim\":\"true\",\"claim.name\":\"organization\",\"jsonType.label\":\"String\"}' &&

echo 'Creating country mapper...' &&
/opt/keycloak/bin/kcadm.sh create clients/\$CLIENT_ID/protocol-mappers/models -r dive25 -s name=country-mapper -s protocol=openid-connect -s protocolMapper=oidc-usermodel-attribute-mapper -s 'config={\"userinfo.token.claim\":\"true\",\"user.attribute\":\"countryOfAffiliation\",\"id.token.claim\":\"true\",\"access.token.claim\":\"true\",\"claim.name\":\"countryOfAffiliation\",\"jsonType.label\":\"String\"}'
"

# Fix translations by copying them to the right location
echo "Copying translation files to the correct location..."
docker exec -it dive25-staging-frontend /bin/bash -c "
if [ -d /app/src/public/locales ]; then
  mkdir -p /app/public/locales
  cp -rf /app/src/public/locales/* /app/public/locales/
  echo 'Translation files copied successfully'
else
  echo 'Translation files not found in src/public/locales'
fi
"

echo "Setup complete!" 