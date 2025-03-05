/**
 * API Configuration
 * 
 * This file follows a "hardcoded defaults with environment override" approach:
 * - Default values are hardcoded for clarity and reliability
 * - Environment variables can override these values when needed
 * - This provides the best balance of flexibility and simplicity
 */
require('dotenv').config();
const path = require('path');

/**
 * Default configuration values
 * These are used when environment variables are not set
 */
const defaults = {
    // Server configuration
    env: 'development',
    port: 3000,
    logLevel: 'info',

    // URLs and domains
    frontendUrl: 'https://dive25.local',
    apiUrl: 'https://api.dive25.local',
    keycloakUrl: 'https://keycloak.dive25.local/auth',

    // Storage paths
    storagePath: path.join(__dirname, '../../storage'),
    tempPath: path.join(__dirname, '../../temp'),

    // Database
    mongodb: {
        uri: 'mongodb://localhost:27017/dive25',
        options: {
            useNewUrlParser: true,
            useUnifiedTopology: true,
        }
    },

    // Keycloak
    keycloak: {
        realm: 'dive25',
        authServerUrl: 'https://keycloak.dive25.local/auth',
        clientId: 'dive25-api',
    },

    // OPA
    opa: {
        url: 'http://localhost:8181/v1/data',
        policyPath: 'dive25/partner_policies/allow',
        timeout: 5000,
    },

    // LDAP
    ldap: {
        url: 'ldap://localhost:389',
        bindDN: 'cn=admin,dc=example,dc=com',
        bindCredentials: 'admin',
        searchBase: 'dc=example,dc=com',
        userSearchFilter: '(uid={{username}})',
        userSearchAttributes: ['uid', 'cn', 'mail', 'givenName', 'sn', 'o', 'countryOfAffiliation', 'clearance', 'caveats', 'coi'],
        groupSearchBase: 'ou=groups,dc=example,dc=com',
        groupSearchFilter: '(member={{dn}})',
        groupSearchAttributes: ['cn', 'description'],
    },

    // CORS
    cors: {
        allowedOrigins: ['https://dive25.local', 'https://api.dive25.local']
    },

    // JWT
    jwt: {
        expiresIn: '1h',
    },
};

/**
 * Export configuration with environment variable overrides
 */
module.exports = {
    env: process.env.NODE_ENV || defaults.env,
    port: parseInt(process.env.PORT, 10) || defaults.port,
    logLevel: process.env.LOG_LEVEL || defaults.logLevel,

    // Add references to the default object to show what values are used
    defaultConfig: defaults,

    storage: {
        basePath: process.env.STORAGE_PATH || defaults.storagePath,
        tempPath: process.env.TEMP_STORAGE_PATH || defaults.tempPath
    },

    mongodb: {
        uri: process.env.MONGODB_URI || defaults.mongodb.uri,
        options: defaults.mongodb.options
    },

    keycloak: {
        realm: process.env.KEYCLOAK_REALM || defaults.keycloak.realm,
        authServerUrl: process.env.KEYCLOAK_AUTH_SERVER_URL || defaults.keycloak.authServerUrl,
        clientId: process.env.KEYCLOAK_CLIENT_ID || defaults.keycloak.clientId,
        clientSecret: process.env.KEYCLOAK_CLIENT_SECRET,
        publicKey: process.env.KEYCLOAK_PUBLIC_KEY,
    },

    opa: {
        url: process.env.OPA_URL || defaults.opa.url,
        policyPath: process.env.OPA_POLICY_PATH || defaults.opa.policyPath,
        timeout: parseInt(process.env.OPA_TIMEOUT, 10) || defaults.opa.timeout,
    },

    ldap: {
        url: process.env.LDAP_URL || defaults.ldap.url,
        bindDN: process.env.LDAP_BIND_DN || defaults.ldap.bindDN,
        bindCredentials: process.env.LDAP_BIND_CREDENTIALS || defaults.ldap.bindCredentials,
        searchBase: process.env.LDAP_SEARCH_BASE || defaults.ldap.searchBase,
        userSearchFilter: process.env.LDAP_USER_SEARCH_FILTER || defaults.ldap.userSearchFilter,
        userSearchAttributes: process.env.LDAP_USER_SEARCH_ATTRIBUTES ?
            process.env.LDAP_USER_SEARCH_ATTRIBUTES.split(',') :
            defaults.ldap.userSearchAttributes,
        groupSearchBase: process.env.LDAP_GROUP_SEARCH_BASE || defaults.ldap.groupSearchBase,
        groupSearchFilter: process.env.LDAP_GROUP_SEARCH_FILTER || defaults.ldap.groupSearchFilter,
        groupSearchAttributes: process.env.LDAP_GROUP_SEARCH_ATTRIBUTES ?
            process.env.LDAP_GROUP_SEARCH_ATTRIBUTES.split(',') :
            defaults.ldap.groupSearchAttributes,
    },

    cors: {
        allowedOrigins: process.env.CORS_ALLOWED_ORIGINS
            ? process.env.CORS_ALLOWED_ORIGINS.split(',')
            : defaults.cors.allowedOrigins
    },

    jwt: {
        jwtSecret: process.env.JWT_SECRET,
        expiresIn: process.env.JWT_EXPIRES_IN || defaults.jwt.expiresIn,
    },
};
