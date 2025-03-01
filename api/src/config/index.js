require('dotenv').config();

module.exports = {
    env: process.env.NODE_ENV || 'development',
    port: parseInt(process.env.PORT, 10) || 3000,
    logLevel: process.env.LOG_LEVEL || 'info',

    mongodb: {
        uri: process.env.MONGODB_URI || 'mongodb://localhost:27017/dive25',
        options: {
            useNewUrlParser: true,
            useUnifiedTopology: true,
        }
    },

    keycloak: {
        realm: process.env.KEYCLOAK_REALM || 'dive25',
        authServerUrl: process.env.KEYCLOAK_AUTH_SERVER_URL || 'http://localhost:8080/auth',
        clientId: process.env.KEYCLOAK_CLIENT_ID || 'dive25-api',
        clientSecret: process.env.KEYCLOAK_CLIENT_SECRET,
        publicKey: process.env.KEYCLOAK_PUBLIC_KEY,
    },

    opa: {
        url: process.env.OPA_URL || 'http://localhost:8181/v1/data',
        policyPath: process.env.OPA_POLICY_PATH || 'dive25/partner_policies/allow',
        timeout: parseInt(process.env.OPA_TIMEOUT, 10) || 5000,
    },

    ldap: {
        url: process.env.LDAP_URL || 'ldap://localhost:389',
        bindDN: process.env.LDAP_BIND_DN || 'cn=admin,dc=example,dc=com',
        bindCredentials: process.env.LDAP_BIND_CREDENTIALS || 'admin',
        searchBase: process.env.LDAP_SEARCH_BASE || 'dc=example,dc=com',
        userSearchFilter: process.env.LDAP_USER_SEARCH_FILTER || '(uid={{username}})',
    },

    cors: {
        allowedOrigins: process.env.CORS_ALLOWED_ORIGINS
            ? process.env.CORS_ALLOWED_ORIGINS.split(',')
            : ['http://localhost:3000']
    },

    jwt: {
        jwtSecret: process.env.JWT_SECRET,
        expiresIn: process.env.JWT_EXPIRES_IN || '1h',
    },
};
