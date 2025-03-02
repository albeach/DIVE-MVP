const { defineConfig } = require('cypress')

module.exports = defineConfig({
    e2e: {
        baseUrl: 'http://localhost:3000',
        setupNodeEvents(on, config) {
            return require('./cypress/plugins/index.js')(on, config)
        },
        specPattern: 'cypress/e2e/**/*.{js,jsx,ts,tsx}',
    },
    env: {
        apiUrl: 'http://localhost:3000/api/v1',
        keycloakUrl: 'http://localhost:8080',
        keycloakRealm: 'dive25',
        keycloakClientId: 'dive25-frontend',
        testUsername: 'alice',
        testPassword: 'password123',
    },
})