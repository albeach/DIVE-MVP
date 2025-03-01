// keycloak/configure-keycloak.js
const axios = require('axios');
const fs = require('fs');
const path = require('path');

// Configuration
const KEYCLOAK_URL = process.env.KEYCLOAK_URL || 'http://localhost:8080';
const KEYCLOAK_ADMIN = process.env.KEYCLOAK_ADMIN || 'admin';
const KEYCLOAK_ADMIN_PASSWORD = process.env.KEYCLOAK_ADMIN_PASSWORD || 'admin';
const REALM_NAME = 'dive25';

// Main function to configure Keycloak
async function configureKeycloak() {
    try {
        console.log('Starting Keycloak configuration...');

        // Get admin token
        const tokenResponse = await getAdminToken();
        const token = tokenResponse.data.access_token;

        // Create headers with authorization token
        const headers = {
            'Authorization': `Bearer ${token}`,
            'Content-Type': 'application/json'
        };

        // Check if realm already exists
        const realms = await axios.get(`${KEYCLOAK_URL}/admin/realms`, { headers });
        const realmExists = realms.data.some(realm => realm.realm === REALM_NAME);

        if (realmExists) {
            console.log(`Realm '${REALM_NAME}' already exists. Updating configuration...`);
            // Here you could implement logic to update the realm instead of recreating it
        } else {
            console.log(`Creating realm '${REALM_NAME}'...`);
            // Create new realm
            const realmConfig = JSON.parse(fs.readFileSync(path.join(__dirname, 'realm-export.json'), 'utf8'));
            await axios.post(`${KEYCLOAK_URL}/admin/realms`, realmConfig, { headers });
            console.log(`Realm '${REALM_NAME}' created successfully.`);
        }

        // Configure identity providers
        await configureIdentityProviders(headers);

        // Configure client
        await configureClients(headers);

        // Configure user federation (LDAP)
        await configureLdapUserFederation(headers);

        // Import test users (only for development)
        if (process.env.NODE_ENV !== 'production') {
            await importTestUsers(headers);
        }

        console.log('Keycloak configuration completed successfully!');
    } catch (error) {
        console.error('Error configuring Keycloak:', error.response?.data || error.message);
        process.exit(1);
    }
}

// Get admin token
async function getAdminToken() {
    try {
        return await axios.post(`${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token`,
            new URLSearchParams({
                'grant_type': 'password',
                'client_id': 'admin-cli',
                'username': KEYCLOAK_ADMIN,
                'password': KEYCLOAK_ADMIN_PASSWORD
            }),
            {
                headers: {
                    'Content-Type': 'application/x-www-form-urlencoded'
                }
            }
        );
    } catch (error) {
        console.error('Error getting admin token:', error.response?.data || error.message);
        throw error;
    }
}

// Configure Identity Providers
async function configureIdentityProviders(headers) {
    try {
        console.log('Configuring identity providers...');

        // Configure SAML Identity Provider
        const samlConfig = JSON.parse(fs.readFileSync(path.join(__dirname, 'identity-providers/saml-idp-config.json'), 'utf8'));

        // Check if SAML IdP already exists
        const idps = await axios.get(`${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/identity-provider/instances`, { headers });
        const samlIdpExists = idps.data.some(idp => idp.alias === samlConfig.alias);

        if (samlIdpExists) {
            console.log(`SAML IdP '${samlConfig.alias}' already exists. Updating...`);
            await axios.put(
                `${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/identity-provider/instances/${samlConfig.alias}`,
                samlConfig,
                { headers }
            );
        } else {
            console.log(`Creating SAML IdP '${samlConfig.alias}'...`);
            await axios.post(
                `${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/identity-provider/instances`,
                samlConfig,
                { headers }
            );
        }

        // Configure OIDC Identity Provider
        const oidcConfig = JSON.parse(fs.readFileSync(path.join(__dirname, 'identity-providers/oidc-idp-config.json'), 'utf8'));

        // Check if OIDC IdP already exists
        const oidcIdpExists = idps.data.some(idp => idp.alias === oidcConfig.alias);

        if (oidcIdpExists) {
            console.log(`OIDC IdP '${oidcConfig.alias}' already exists. Updating...`);
            await axios.put(
                `${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/identity-provider/instances/${oidcConfig.alias}`,
                oidcConfig,
                { headers }
            );
        } else {
            console.log(`Creating OIDC IdP '${oidcConfig.alias}'...`);
            await axios.post(
                `${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/identity-provider/instances`,
                oidcConfig,
                { headers }
            );
        }

        // Configure attribute mappers for identity providers
        await configureIdpMappers(headers, samlConfig.alias, 'saml');
        await configureIdpMappers(headers, oidcConfig.alias, 'oidc');

        console.log('Identity providers configured successfully.');
    } catch (error) {
        console.error('Error configuring identity providers:', error.response?.data || error.message);
        throw error;
    }
}

// Configure Identity Provider Mappers
async function configureIdpMappers(headers, idpAlias, idpType) {
    try {
        console.log(`Configuring mappers for ${idpType} identity provider '${idpAlias}'...`);

        // Define mappers based on IdP type
        const mappers = [];

        if (idpType === 'saml') {
            // SAML attribute mappers
            mappers.push(
                // Username mapper
                {
                    name: 'username',
                    identityProviderAlias: idpAlias,
                    identityProviderMapper: 'saml-username-idp-mapper',
                    config: {
                        template: '${ATTRIBUTE.uid}',
                        'user.attribute': 'username'
                    }
                },
                // Email mapper
                {
                    name: 'email',
                    identityProviderAlias: idpAlias,
                    identityProviderMapper: 'saml-user-attribute-idp-mapper',
                    config: {
                        'attribute.name': 'email',
                        'user.attribute': 'email'
                    }
                },
                // First name mapper
                {
                    name: 'givenName',
                    identityProviderAlias: idpAlias,
                    identityProviderMapper: 'saml-user-attribute-idp-mapper',
                    config: {
                        'attribute.name': 'givenName',
                        'user.attribute': 'firstName'
                    }
                },
                // Last name mapper
                {
                    name: 'surname',
                    identityProviderAlias: idpAlias,
                    identityProviderMapper: 'saml-user-attribute-idp-mapper',
                    config: {
                        'attribute.name': 'sn',
                        'user.attribute': 'lastName'
                    }
                },
                // Country of affiliation mapper
                {
                    name: 'countryOfAffiliation',
                    identityProviderAlias: idpAlias,
                    identityProviderMapper: 'saml-user-attribute-idp-mapper',
                    config: {
                        'attribute.name': 'countryOfAffiliation',
                        'user.attribute': 'countryOfAffiliation'
                    }
                },
                // Clearance mapper
                {
                    name: 'clearance',
                    identityProviderAlias: idpAlias,
                    identityProviderMapper: 'saml-user-attribute-idp-mapper',
                    config: {
                        'attribute.name': 'clearance',
                        'user.attribute': 'clearance'
                    }
                },
                // Organization mapper
                {
                    name: 'organization',
                    identityProviderAlias: idpAlias,
                    identityProviderMapper: 'saml-user-attribute-idp-mapper',
                    config: {
                        'attribute.name': 'o',
                        'user.attribute': 'organization'
                    }
                },
                // Caveats mapper
                {
                    name: 'caveats',
                    identityProviderAlias: idpAlias,
                    identityProviderMapper: 'saml-user-attribute-idp-mapper',
                    config: {
                        'attribute.name': 'caveats',
                        'user.attribute': 'caveats'
                    }
                },
                // COI mapper
                {
                    name: 'coi',
                    identityProviderAlias: idpAlias,
                    identityProviderMapper: 'saml-user-attribute-idp-mapper',
                    config: {
                        'attribute.name': 'aCPCOI',
                        'user.attribute': 'coi'
                    }
                }
            );
        } else if (idpType === 'oidc') {
            // OIDC attribute mappers
            mappers.push(
                // Username mapper
                {
                    name: 'username',
                    identityProviderAlias: idpAlias,
                    identityProviderMapper: 'oidc-username-idp-mapper',
                    config: {
                        template: '${CLAIM.preferred_username}',
                        'user.attribute': 'username'
                    }
                },
                // Email mapper
                {
                    name: 'email',
                    identityProviderAlias: idpAlias,
                    identityProviderMapper: 'oidc-user-attribute-idp-mapper',
                    config: {
                        'claim': 'email',
                        'user.attribute': 'email'
                    }
                },
                // First name mapper
                {
                    name: 'givenName',
                    identityProviderAlias: idpAlias,
                    identityProviderMapper: 'oidc-user-attribute-idp-mapper',
                    config: {
                        'claim': 'given_name',
                        'user.attribute': 'firstName'
                    }
                },
                // Last name mapper
                {
                    name: 'surname',
                    identityProviderAlias: idpAlias,
                    identityProviderMapper: 'oidc-user-attribute-idp-mapper',
                    config: {
                        'claim': 'family_name',
                        'user.attribute': 'lastName'
                    }
                },
                // Country of affiliation mapper
                {
                    name: 'countryOfAffiliation',
                    identityProviderAlias: idpAlias,
                    identityProviderMapper: 'oidc-user-attribute-idp-mapper',
                    config: {
                        'claim': 'country_of_affiliation',
                        'user.attribute': 'countryOfAffiliation'
                    }
                },
                // Clearance mapper
                {
                    name: 'clearance',
                    identityProviderAlias: idpAlias,
                    identityProviderMapper: 'oidc-user-attribute-idp-mapper',
                    config: {
                        'claim': 'clearance',
                        'user.attribute': 'clearance'
                    }
                },
                // Organization mapper
                {
                    name: 'organization',
                    identityProviderAlias: idpAlias,
                    identityProviderMapper: 'oidc-user-attribute-idp-mapper',
                    config: {
                        'claim': 'organization',
                        'user.attribute': 'organization'
                    }
                },
                // Caveats mapper
                {
                    name: 'caveats',
                    identityProviderAlias: idpAlias,
                    identityProviderMapper: 'oidc-user-attribute-idp-mapper',
                    config: {
                        'claim': 'caveats',
                        'user.attribute': 'caveats'
                    }
                },
                // COI mapper
                {
                    name: 'coi',
                    identityProviderAlias: idpAlias,
                    identityProviderMapper: 'oidc-user-attribute-idp-mapper',
                    config: {
                        'claim': 'coi',
                        'user.attribute': 'coi'
                    }
                }
            );
        }

        // Create mappers
        for (const mapper of mappers) {
            try {
                await axios.post(
                    `${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/identity-provider/instances/${idpAlias}/mappers`,
                    mapper,
                    { headers }
                );
                console.log(`Created mapper '${mapper.name}' for IdP '${idpAlias}'`);
            } catch (error) {
                // If mapper already exists, update it
                if (error.response && error.response.status === 409) {
                    console.log(`Mapper '${mapper.name}' already exists for IdP '${idpAlias}'. Updating...`);

                    // Get existing mappers
                    const existingMappers = await axios.get(
                        `${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/identity-provider/instances/${idpAlias}/mappers`,
                        { headers }
                    );

                    // Find the ID of the existing mapper
                    const existingMapper = existingMappers.data.find(m => m.name === mapper.name);

                    if (existingMapper) {
                        await axios.put(
                            `${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/identity-provider/instances/${idpAlias}/mappers/${existingMapper.id}`,
                            mapper,
                            { headers }
                        );
                    }
                } else {
                    throw error;
                }
            }
        }

        console.log(`Mappers for ${idpType} identity provider '${idpAlias}' configured successfully.`);
    } catch (error) {
        console.error(`Error configuring mappers for IdP '${idpAlias}':`, error.response?.data || error.message);
        throw error;
    }
}

// Configure Clients
async function configureClients(headers) {
    try {
        console.log('Configuring clients...');

        // DIVE25 API Client
        const apiClientConfig = {
            clientId: 'dive25-api',
            name: 'DIVE25 API',
            description: 'DIVE25 Document Access System API',
            enabled: true,
            clientAuthenticatorType: 'client-secret',
            secret: process.env.API_CLIENT_SECRET || 'dive25-api-secret',
            redirectUris: [
                'http://localhost:3000/*',
                'https://api.dive25.com/*'
            ],
            webOrigins: [
                'http://localhost:3000',
                'https://api.dive25.com'
            ],
            publicClient: false,
            protocol: 'openid-connect',
            serviceAccountsEnabled: true,
            authorizationServicesEnabled: true,
            attributes: {
                'access.token.lifespan': '43200', // 12 hours
                'saml.force.post.binding': 'false',
                'saml.multivalued.roles': 'false',
                'oauth2.device.authorization.grant.enabled': 'false',
                'backchannel.logout.revoke.offline.tokens': 'false',
                'saml.server.signature': 'false',
                'saml.server.signature.keyinfo.ext': 'false',
                'use.refresh.tokens': 'true',
                'exclude.session.state.from.auth.response': 'false',
                'saml.artifact.binding': 'false',
                'backchannel.logout.session.required': 'true',
                'client_credentials.use_refresh_token': 'false',
                'saml_force_name_id_format': 'false',
                'tls.client.certificate.bound.access.tokens': 'false',
                'require.pushed.authorization.requests': 'false',
                'saml.client.signature': 'false',
                'id.token.as.detached.signature': 'false',
                'saml.assertion.signature': 'false',
                'saml.encrypt': 'false',
                'saml.authnstatement': 'false',
                'display.on.consent.screen': 'false',
                'saml.onetimeuse.condition': 'false'
            }
        };

        // Check if client already exists
        const clients = await axios.get(`${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/clients`, { headers });
        const apiClientExists = clients.data.some(client => client.clientId === apiClientConfig.clientId);

        if (apiClientExists) {
            console.log(`Client '${apiClientConfig.clientId}' already exists. Updating...`);

            // Get client ID
            const apiClient = clients.data.find(client => client.clientId === apiClientConfig.clientId);

            await axios.put(
                `${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/clients/${apiClient.id}`,
                apiClientConfig,
                { headers }
            );
        } else {
            console.log(`Creating client '${apiClientConfig.clientId}'...`);
            await axios.post(
                `${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/clients`,
                apiClientConfig,
                { headers }
            );
        }

        // Configure protocol mappers for the client
        await configureClientProtocolMappers(headers, apiClientConfig.clientId);

        console.log('Clients configured successfully.');
    } catch (error) {
        console.error('Error configuring clients:', error.response?.data || error.message);
        throw error;
    }
}

// Configure Client Protocol Mappers
async function configureClientProtocolMappers(headers, clientId) {
    try {
        console.log(`Configuring protocol mappers for client '${clientId}'...`);

        // Get client ID
        const clients = await axios.get(`${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/clients`, { headers });
        const client = clients.data.find(c => c.clientId === clientId);

        if (!client) {
            throw new Error(`Client '${clientId}' not found.`);
        }

        // Define protocol mappers
        const mappers = [
            // Unique ID mapper
            {
                name: 'uniqueId',
                protocol: 'openid-connect',
                protocolMapper: 'oidc-usermodel-attribute-mapper',
                config: {
                    'user.attribute': 'id',
                    'id.token.claim': 'true',
                    'access.token.claim': 'true',
                    'claim.name': 'sub',
                    'jsonType.label': 'String'
                }
            },
            // Country of Affiliation mapper
            {
                name: 'countryOfAffiliation',
                protocol: 'openid-connect',
                protocolMapper: 'oidc-usermodel-attribute-mapper',
                config: {
                    'user.attribute': 'countryOfAffiliation',
                    'id.token.claim': 'true',
                    'access.token.claim': 'true',
                    'claim.name': 'countryOfAffiliation',
                    'jsonType.label': 'String'
                }
            },
            // Clearance mapper
            {
                name: 'clearance',
                protocol: 'openid-connect',
                protocolMapper: 'oidc-usermodel-attribute-mapper',
                config: {
                    'user.attribute': 'clearance',
                    'id.token.claim': 'true',
                    'access.token.claim': 'true',
                    'claim.name': 'clearance',
                    'jsonType.label': 'String'
                }
            },
            // Organization mapper
            {
                name: 'organization',
                protocol: 'openid-connect',
                protocolMapper: 'oidc-usermodel-attribute-mapper',
                config: {
                    'user.attribute': 'organization',
                    'id.token.claim': 'true',
                    'access.token.claim': 'true',
                    'claim.name': 'organization',
                    'jsonType.label': 'String'
                }
            },
            // Caveats mapper
            {
                name: 'caveats',
                protocol: 'openid-connect',
                protocolMapper: 'oidc-usermodel-attribute-mapper',
                config: {
                    'user.attribute': 'caveats',
                    'id.token.claim': 'true',
                    'access.token.claim': 'true',
                    'claim.name': 'caveats',
                    'jsonType.label': 'String',
                    'multivalued': 'true'
                }
            },
            // COI mapper
            {
                name: 'coi',
                protocol: 'openid-connect',
                protocolMapper: 'oidc-usermodel-attribute-mapper',
                config: {
                    'user.attribute': 'coi',
                    'id.token.claim': 'true',
                    'access.token.claim': 'true',
                    'claim.name': 'coi',
                    'jsonType.label': 'String',
                    'multivalued': 'true'
                }
            },
            // Administrative Organization mapper
            {
                name: 'adminOrganization',
                protocol: 'openid-connect',
                protocolMapper: 'oidc-usermodel-attribute-mapper',
                config: {
                    'user.attribute': 'organization',
                    'id.token.claim': 'true',
                    'access.token.claim': 'true',
                    'claim.name': 'adminOrganization',
                    'jsonType.label': 'String'
                }
            },
            // NATO-specific mapper for ACPCOI
            {
                name: 'aCPCOI',
                protocol: 'openid-connect',
                protocolMapper: 'oidc-usermodel-attribute-mapper',
                config: {
                    'user.attribute': 'coi',
                    'id.token.claim': 'true',
                    'access.token.claim': 'true',
                    'claim.name': 'aCPCOI',
                    'jsonType.label': 'String',
                    'multivalued': 'true'
                }
            }
        ];

        // Create/update protocol mappers
        for (const mapper of mappers) {
            try {
                await axios.post(
                    `${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/clients/${client.id}/protocol-mappers/models`,
                    mapper,
                    { headers }
                );
                console.log(`Created protocol mapper '${mapper.name}' for client '${clientId}'`);
            } catch (error) {
                // If mapper already exists, update it
                if (error.response && error.response.status === 409) {
                    console.log(`Protocol mapper '${mapper.name}' already exists for client '${clientId}'. Updating...`);

                    // Get existing mappers
                    const existingMappers = await axios.get(
                        `${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/clients/${client.id}/protocol-mappers/models`,
                        { headers }
                    );

                    // Find the ID of the existing mapper
                    const existingMapper = existingMappers.data.find(m => m.name === mapper.name);

                    if (existingMapper) {
                        await axios.put(
                            `${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/clients/${client.id}/protocol-mappers/models/${existingMapper.id}`,
                            mapper,
                            { headers }
                        );
                    }
                } else {
                    throw error;
                }
            }
        }

        console.log(`Protocol mappers for client '${clientId}' configured successfully.`);
    } catch (error) {
        console.error(`Error configuring protocol mappers for client '${clientId}':`, error.response?.data || error.message);
        throw error;
    }
}

// Configure LDAP User Federation
async function configureLdapUserFederation(headers) {
    try {
        console.log('Configuring LDAP user federation...');

        // Define LDAP configuration
        const ldapConfig = {
            name: 'dive25-ldap',
            providerId: 'ldap',
            providerType: 'org.keycloak.storage.UserStorageProvider',
            parentId: REALM_NAME,
            config: {
                enabled: ['true'],
                priority: ['1'],
                editMode: ['READ_ONLY'],
                syncRegistrations: ['false'],
                vendor: ['other'],
                usernameLDAPAttribute: ['uid'],
                rdnLDAPAttribute: ['uid'],
                uuidLDAPAttribute: ['entryUUID'],
                userObjectClasses: ['inetOrgPerson, organizationalPerson'],
                connectionUrl: [process.env.LDAP_URL || 'ldap://openldap:389'],
                usersDn: [process.env.LDAP_USERS_DN || 'ou=users,dc=dive25,dc=local'],
                authType: ['simple'],
                bindDn: [process.env.LDAP_BIND_DN || 'cn=admin,dc=dive25,dc=local'],
                bindCredential: [process.env.LDAP_BIND_CREDENTIALS || 'admin'],
                searchScope: ['1'],
                validatePasswordPolicy: ['false'],
                trustEmail: ['true'],
                useTruststoreSpi: ['ldapsOnly'],
                connectionPooling: ['true'],
                pagination: ['true'],
                batchSizeForSync: ['1000'],
                fullSyncPeriod: ['604800'],
                changedSyncPeriod: ['86400'],
                cachePolicy: ['DEFAULT'],
                useKerberosForPasswordAuthentication: ['false']
            }
        };

        // Check if LDAP provider already exists
        const components = await axios.get(
            `${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/components?parent=${REALM_NAME}&type=org.keycloak.storage.UserStorageProvider`,
            { headers }
        );

        const ldapExists = components.data.some(component => component.name === ldapConfig.name);

        if (ldapExists) {
            console.log(`LDAP provider '${ldapConfig.name}' already exists. Updating...`);

            // Get LDAP provider ID
            const ldapProvider = components.data.find(component => component.name === ldapConfig.name);

            await axios.put(
                `${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/components/${ldapProvider.id}`,
                ldapConfig,
                { headers }
            );
        } else {
            console.log(`Creating LDAP provider '${ldapConfig.name}'...`);
            await axios.post(
                `${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/components`,
                ldapConfig,
                { headers }
            );
        }

        // Configure LDAP mappers
        await configureLdapMappers(headers);

        console.log('LDAP user federation configured successfully.');
    } catch (error) {
        console.error('Error configuring LDAP user federation:', error.response?.data || error.message);
        throw error;
    }
}

// Configure LDAP Mappers
async function configureLdapMappers(headers) {
    try {
        console.log('Configuring LDAP mappers...');

        // Get LDAP provider ID
        const components = await axios.get(
            `${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/components?parent=${REALM_NAME}&type=org.keycloak.storage.UserStorageProvider`,
            { headers }
        );

        const ldapProvider = components.data.find(component => component.name === 'dive25-ldap');

        if (!ldapProvider) {
            throw new Error('LDAP provider not found.');
        }

        // Define LDAP mappers
        const mappers = [
            // Username
            {
                name: 'username',
                providerId: 'user-attribute-ldap-mapper',
                providerType: 'org.keycloak.storage.ldap.mappers.LDAPStorageMapper',
                parentId: ldapProvider.id,
                config: {
                    'ldap.attribute': ['uid'],
                    'is.mandatory.in.ldap': ['true'],
                    'read.only': ['true'],
                    'always.read.value.from.ldap': ['true'],
                    'user.model.attribute': ['username']
                }
            },
            // Email
            {
                name: 'email',
                providerId: 'user-attribute-ldap-mapper',
                providerType: 'org.keycloak.storage.ldap.mappers.LDAPStorageMapper',
                parentId: ldapProvider.id,
                config: {
                    'ldap.attribute': ['mail'],
                    'is.mandatory.in.ldap': ['false'],
                    'read.only': ['true'],
                    'always.read.value.from.ldap': ['true'],
                    'user.model.attribute': ['email']
                }
            },
            // First name
            {
                name: 'first name',
                providerId: 'user-attribute-ldap-mapper',
                providerType: 'org.keycloak.storage.ldap.mappers.LDAPStorageMapper',
                parentId: ldapProvider.id,
                config: {
                    'ldap.attribute': ['givenName'],
                    'is.mandatory.in.ldap': ['true'],
                    'read.only': ['true'],
                    'always.read.value.from.ldap': ['true'],
                    'user.model.attribute': ['firstName']
                }
            },
            // Last name
            {
                name: 'last name',
                providerId: 'user-attribute-ldap-mapper',
                providerType: 'org.keycloak.storage.ldap.mappers.LDAPStorageMapper',
                parentId: ldapProvider.id,
                config: {
                    'ldap.attribute': ['sn'],
                    'is.mandatory.in.ldap': ['true'],
                    'read.only': ['true'],
                    'always.read.value.from.ldap': ['true'],
                    'user.model.attribute': ['lastName']
                }
            },
            // Country of affiliation
            {
                name: 'country of affiliation',
                providerId: 'user-attribute-ldap-mapper',
                providerType: 'org.keycloak.storage.ldap.mappers.LDAPStorageMapper',
                parentId: ldapProvider.id,
                config: {
                    'ldap.attribute': ['countryOfAffiliation'],
                    'is.mandatory.in.ldap': ['false'],
                    'read.only': ['true'],
                    'always.read.value.from.ldap': ['true'],
                    'user.model.attribute': ['countryOfAffiliation']
                }
            },
            // Clearance
            {
                name: 'clearance',
                providerId: 'user-attribute-ldap-mapper',
                providerType: 'org.keycloak.storage.ldap.mappers.LDAPStorageMapper',
                parentId: ldapProvider.id,
                config: {
                    'ldap.attribute': ['clearance'],
                    'is.mandatory.in.ldap': ['false'],
                    'read.only': ['true'],
                    'always.read.value.from.ldap': ['true'],
                    'user.model.attribute': ['clearance']
                }
            },
            // Organization
            {
                name: 'organization',
                providerId: 'user-attribute-ldap-mapper',
                providerType: 'org.keycloak.storage.ldap.mappers.LDAPStorageMapper',
                parentId: ldapProvider.id,
                config: {
                    'ldap.attribute': ['o'],
                    'is.mandatory.in.ldap': ['false'],
                    'read.only': ['true'],
                    'always.read.value.from.ldap': ['true'],
                    'user.model.attribute': ['organization']
                }
            },
            // Caveats
            {
                name: 'caveats',
                providerId: 'user-attribute-ldap-mapper',
                providerType: 'org.keycloak.storage.ldap.mappers.LDAPStorageMapper',
                parentId: ldapProvider.id,
                config: {
                    'ldap.attribute': ['caveats'],
                    'is.mandatory.in.ldap': ['false'],
                    'read.only': ['true'],
                    'always.read.value.from.ldap': ['true'],
                    'user.model.attribute': ['caveats'],
                    'is.binary.attribute': ['false'],
                    'is.multivalued.attribute': ['true']
                }
            },
            // COI
            {
                name: 'coi',
                providerId: 'user-attribute-ldap-mapper',
                providerType: 'org.keycloak.storage.ldap.mappers.LDAPStorageMapper',
                parentId: ldapProvider.id,
                config: {
                    'ldap.attribute': ['aCPCOI'],
                    'is.mandatory.in.ldap': ['false'],
                    'read.only': ['true'],
                    'always.read.value.from.ldap': ['true'],
                    'user.model.attribute': ['coi'],
                    'is.binary.attribute': ['false'],
                    'is.multivalued.attribute': ['true']
                }
            },
            // Creation date
            {
                name: 'creation date',
                providerId: 'user-attribute-ldap-mapper',
                providerType: 'org.keycloak.storage.ldap.mappers.LDAPStorageMapper',
                parentId: ldapProvider.id,
                config: {
                    'ldap.attribute': ['createTimestamp'],
                    'is.mandatory.in.ldap': ['false'],
                    'read.only': ['true'],
                    'always.read.value.from.ldap': ['true'],
                    'user.model.attribute': ['createdTimestamp']
                }
            },
            // Role mappings
            {
                name: 'role-mapper',
                providerId: 'role-ldap-mapper',
                providerType: 'org.keycloak.storage.ldap.mappers.LDAPStorageMapper',
                parentId: ldapProvider.id,
                config: {
                    'roles.dn': [process.env.LDAP_ROLES_DN || 'ou=roles,dc=dive25,dc=local'],
                    'role.name.ldap.attribute': ['cn'],
                    'role.object.classes': ['groupOfNames'],
                    'membership.ldap.attribute': ['member'],
                    'membership.attribute.type': ['DN'],
                    'membership.user.ldap.attribute': ['uid'],
                    'mode': ['READ_ONLY'],
                    'user.roles.retrieve.strategy': ['LOAD_ROLES_BY_MEMBER_ATTRIBUTE'],
                    'memberof.ldap.attribute': ['memberOf'],
                    'use.realm.roles.mapping': ['true'],
                    'client.id': ['']
                }
            }
        ];

        // Create/update LDAP mappers
        for (const mapper of mappers) {
            try {
                // Check if mapper already exists
                const existingMappers = await axios.get(
                    `${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/components?parent=${ldapProvider.id}&type=org.keycloak.storage.ldap.mappers.LDAPStorageMapper`,
                    { headers }
                );

                const mapperExists = existingMappers.data.some(m => m.name === mapper.name);

                if (mapperExists) {
                    console.log(`LDAP mapper '${mapper.name}' already exists. Updating...`);

                    // Get mapper ID
                    const existingMapper = existingMappers.data.find(m => m.name === mapper.name);

                    await axios.put(
                        `${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/components/${existingMapper.id}`,
                        mapper,
                        { headers }
                    );
                } else {
                    console.log(`Creating LDAP mapper '${mapper.name}'...`);
                    await axios.post(
                        `${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/components`,
                        mapper,
                        { headers }
                    );
                }
            } catch (error) {
                console.error(`Error configuring LDAP mapper '${mapper.name}':`, error.response?.data || error.message);
                throw error;
            }
        }

        console.log('LDAP mappers configured successfully.');
    } catch (error) {
        console.error('Error configuring LDAP mappers:', error.response?.data || error.message);
        throw error;
    }
}

// Import test users
async function importTestUsers(headers) {
    try {
        console.log('Importing test users...');

        // Read test users from file
        const testUsers = JSON.parse(fs.readFileSync(path.join(__dirname, 'test-users/sample-users.json'), 'utf8'));

        // Import each user
        for (const user of testUsers) {
            try {
                // Check if user already exists
                const existingUsers = await axios.get(
                    `${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/users?username=${user.username}`,
                    { headers }
                );

                if (existingUsers.data.length > 0) {
                    console.log(`User '${user.username}' already exists. Updating...`);

                    // Get user ID
                    const existingUser = existingUsers.data[0];

                    await axios.put(
                        `${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/users/${existingUser.id}`,
                        user,
                        { headers }
                    );

                    // Reset password if specified
                    if (user.credentials && user.credentials.length > 0) {
                        await axios.put(
                            `${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/users/${existingUser.id}/reset-password`,
                            user.credentials[0],
                            { headers }
                        );
                    }
                } else {
                    console.log(`Creating user '${user.username}'...`);

                    // Create user
                    const response = await axios.post(
                        `${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/users`,
                        {
                            username: user.username,
                            email: user.email,
                            firstName: user.firstName,
                            lastName: user.lastName,
                            enabled: user.enabled,
                            attributes: user.attributes
                        },
                        { headers }
                    );

                    // Get user ID
                    const users = await axios.get(
                        `${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/users?username=${user.username}`,
                        { headers }
                    );

                    const userId = users.data[0].id;

                    // Set password
                    if (user.credentials && user.credentials.length > 0) {
                        await axios.put(
                            `${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/users/${userId}/reset-password`,
                            user.credentials[0],
                            { headers }
                        );
                    }

                    // Set role mappings
                    if (user.realmRoles && user.realmRoles.length > 0) {
                        // Get available roles
                        const availableRoles = await axios.get(
                            `${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/roles`,
                            { headers }
                        );

                        // Filter roles that exist in the realm
                        const rolesToAdd = user.realmRoles
                            .map(roleName => availableRoles.data.find(role => role.name === roleName))
                            .filter(role => role !== undefined);

                        if (rolesToAdd.length > 0) {
                            await axios.post(
                                `${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/users/${userId}/role-mappings/realm`,
                                rolesToAdd,
                                { headers }
                            );
                        }
                    }
                }
            } catch (error) {
                console.error(`Error importing user '${user.username}':`, error.response?.data || error.message);
                throw error;
            }
        }

        console.log('Test users imported successfully.');
    } catch (error) {
        console.error('Error importing test users:', error.response?.data || error.message);
        throw error;
    }
}

// Execute the configuration
configureKeycloak().catch(error => {
    console.error('Keycloak configuration failed:', error);
    process.exit(1);
});
