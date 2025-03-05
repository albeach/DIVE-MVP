/**
 * Central environment configuration for E2E tests
 * 
 * This file follows a "hardcoded defaults with environment override" approach:
 * - Default values are hardcoded for clarity and reliability
 * - Environment variables can override these values when needed
 * - This provides the best balance of flexibility and simplicity
 */
const path = require('path');
const dotenv = require('dotenv');
const fs = require('fs');

// Determine .env file location and load environment variables if available
let envPath = path.join(__dirname, '../../../.env');
if (!fs.existsSync(envPath)) {
    envPath = path.join(__dirname, '../../.env');
}
if (fs.existsSync(envPath)) {
    dotenv.config({ path: envPath });
    console.log('Environment variables loaded from', envPath);
}

/**
 * Environment constants for tests with hardcoded defaults
 */
const Environment = {
    // URLs - hardcoded defaults that can be overridden by environment variables
    FRONTEND_URL: process.env.PUBLIC_FRONTEND_URL || 'https://dive25.local',
    API_URL: process.env.PUBLIC_API_URL || 'https://api.dive25.local',
    KEYCLOAK_URL: process.env.PUBLIC_KEYCLOAK_URL || 'https://keycloak.dive25.local',

    // Auth settings
    KEYCLOAK_REALM: process.env.KEYCLOAK_REALM || 'dive25',
    CLIENT_ID: process.env.KEYCLOAK_CLIENT_ID_FRONTEND || 'dive25-frontend',
    CLIENT_SECRET: process.env.KEYCLOAK_CLIENT_SECRET || '',

    // Test user credentials
    TEST_USERNAME: process.env.TEST_USERNAME || 'alice',
    TEST_PASSWORD: process.env.TEST_PASSWORD || 'password123',

    // API endpoints - these are hardcoded since they are part of the API structure
    API_ENDPOINTS: {
        USERS: '/api/v1/users',
        DOCUMENTS: '/api/v1/documents',
        AUTH: '/api/v1/auth',
        HEALTH: '/health'
    },

    // Timeouts
    STANDARD_TIMEOUT: parseInt(process.env.TEST_TIMEOUT, 10) || 10000,
    LONG_TIMEOUT: parseInt(process.env.TEST_LONG_TIMEOUT, 10) || 30000,

    /**
     * Get full URL for a frontend path
     * @param {string} path - Path to append to frontend URL
     * @returns {string} Full URL
     */
    getPageUrl(path = '') {
        if (path.startsWith('http')) return path; // Already a full URL
        const base = this.FRONTEND_URL.endsWith('/') ? this.FRONTEND_URL.slice(0, -1) : this.FRONTEND_URL;
        const pathWithSlash = path.startsWith('/') ? path : `/${path}`;
        return `${base}${pathWithSlash}`;
    },

    /**
     * Get full URL for an API endpoint
     * @param {string} endpoint - API endpoint
     * @returns {string} Full API URL
     */
    getApiUrl(endpoint = '') {
        if (endpoint.startsWith('http')) return endpoint; // Already a full URL
        const base = this.API_URL.endsWith('/') ? this.API_URL.slice(0, -1) : this.API_URL;
        const endpointWithSlash = endpoint.startsWith('/') ? endpoint : `/${endpoint}`;
        return `${base}${endpointWithSlash}`;
    },

    /**
     * Get Keycloak URL for a specific path
     * @param {string} path - Path to append to Keycloak URL
     * @returns {string} Full Keycloak URL
     */
    getKeycloakUrl(path = '') {
        if (path.startsWith('http')) return path; // Already a full URL
        const base = this.KEYCLOAK_URL.endsWith('/') ? this.KEYCLOAK_URL.slice(0, -1) : this.KEYCLOAK_URL;
        const pathWithSlash = path.startsWith('/') ? path : `/${path}`;
        return `${base}${pathWithSlash}`;
    },

    /**
     * Get Keycloak realm URL 
     * @param {string} path - Path to append to realm URL
     * @returns {string} Full realm URL
     */
    getRealmUrl(path = '') {
        return this.getKeycloakUrl(`/auth/realms/${this.KEYCLOAK_REALM}${path}`);
    },

    /**
     * Get token endpoint URL
     * @returns {string} Token endpoint URL
     */
    getTokenUrl() {
        return this.getRealmUrl('/protocol/openid-connect/token');
    }
};

module.exports = Environment; 