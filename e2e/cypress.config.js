const { defineConfig } = require('cypress')
const dotenv = require('dotenv')

// Load environment variables from root .env file
dotenv.config({ path: '../.env' })

// Extract environment-specific URLs
const KEYCLOAK_URL = process.env.PUBLIC_KEYCLOAK_URL || 'http://localhost:8080'
const API_URL = process.env.PUBLIC_API_URL || 'http://localhost:3000'
const FRONTEND_URL = process.env.PUBLIC_FRONTEND_URL || 'http://localhost:3000'

module.exports = defineConfig({
    e2e: {
        baseUrl: FRONTEND_URL,
        setupNodeEvents(on, config) {
            return require('./cypress/plugins/index.js')(on, config)
        },
        specPattern: 'cypress/e2e/**/*.{js,jsx,ts,tsx}',
    },
    env: {
        apiUrl: `${API_URL}/api/v1`,
        keycloakUrl: KEYCLOAK_URL,
        keycloakRealm: process.env.KEYCLOAK_REALM || 'dive25',
        keycloakClientId: process.env.KEYCLOAK_CLIENT_ID_FRONTEND || 'dive25-frontend',
        testUsername: 'alice',
        testPassword: 'password123',
    },
})