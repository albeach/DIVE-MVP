const jwksClient = require('jwks-rsa');
const config = require('./index');

// Create JWKS client for Keycloak token verification
const keycloakJwksClient = jwksClient({
    jwksUri: `${config.keycloak.authServerUrl}/realms/${config.keycloak.realm}/protocol/openid-connect/certs`,
    cache: true,
    rateLimit: true,
    jwksRequestsPerMinute: 5,
});

module.exports = {
    keycloakJwksClient,
    realm: config.keycloak.realm,
    authServerUrl: config.keycloak.authServerUrl,
    clientId: config.keycloak.clientId,
    clientSecret: config.keycloak.clientSecret,
};
