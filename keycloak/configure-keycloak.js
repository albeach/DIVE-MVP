// keycloak/configure-keycloak.js
const axios = require('axios');
const fs = require('fs');
const path = require('path');

// Configuration
const KEYCLOAK_URL = process.env.KEYCLOAK_URL || 'http://localhost:8080';
const ADMIN_USER = process.env.KEYCLOAK_ADMIN || 'admin';
const ADMIN_PASSWORD = process.env.KEYCLOAK_ADMIN_PASSWORD || 'admin';
const REALM_NAME = 'dive25';

// Authentication token
let authToken;

// Get admin token
const getToken = async () => {
    try {
        const response = await axios.post(`${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token`,
            'grant_type=password&client_id=admin-cli&username=' + ADMIN_USER + '&password=' + ADMIN_PASSWORD,
            {
                headers: {
                    'Content-Type': 'application/x-www-form-urlencoded'
                }
            }
        );

        return response.data.access_token;
    } catch (error) {
        console.error('Failed to get admin token:', error.response?.data || error.message);
        throw error;
    }
};

// Create realm
const createRealm = async () => {
    try {
        console.log('Creating realm...');

        // Load realm config
        const realmConfig = JSON.parse(fs.readFileSync(path.join(__dirname, 'realm-export.json'), 'utf8'));

        // Check if realm exists
        try {
            await axios.get(`${KEYCLOAK_URL}/admin/realms/${REALM_NAME}`, {
                headers: {
                    Authorization: `Bearer ${authToken}`
                }
            });
            console.log(`Realm ${REALM_NAME} already exists.`);
            return;
        } catch (error) {
            // Realm doesn't exist, continue with creation
            if (error.response?.status !== 404) {
                throw error;
            }
        }

        // Create realm
        await axios.post(`${KEYCLOAK_URL}/admin/realms`, realmConfig, {
            headers: {
                Authorization: `Bearer ${authToken}`,
                'Content-Type': 'application/json'
            }
        });

        console.log(`Realm ${REALM_NAME} created successfully.`);
    } catch (error) {
        console.error('Failed to create realm:', error.response?.data || error.message);
        throw error;
    }
};

// Create clients
const createClients = async () => {
    try {
        console.log('Creating clients...');

        // Load client configs
        const clientsDir = path.join(__dirname, 'clients');
        const clientFiles = fs.readdirSync(clientsDir).filter(file => file.endsWith('.json'));

        for (const file of clientFiles) {
            const clientConfig = JSON.parse(fs.readFileSync(path.join(clientsDir, file), 'utf8'));
            const clientId = clientConfig.clientId;

            // Check if client exists
            try {
                const response = await axios.get(`${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/clients`, {
                    params: {
                        clientId
                    },
                    headers: {
                        Authorization: `Bearer ${authToken}`
                    }
                });

                if (response.data.length > 0) {
                    const existingClient = response.data[0];
                    console.log(`Client ${clientId} already exists. Updating...`);

                    // Update existing client
                    await axios.put(`${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/clients/${existingClient.id}`, clientConfig, {
                        headers: {
                            Authorization: `Bearer ${authToken}`,
                            'Content-Type': 'application/json'
                        }
                    });

                    console.log(`Client ${clientId} updated successfully.`);
                    continue;
                }
            } catch (error) {
                console.error(`Error checking client ${clientId}:`, error.response?.data || error.message);
                // Continue with creation attempt
            }

            // Create client
            await axios.post(`${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/clients`, clientConfig, {
                headers: {
                    Authorization: `Bearer ${authToken}`,
                    'Content-Type': 'application/json'
                }
            });

            console.log(`Client ${clientId} created successfully.`);
        }
    } catch (error) {
        console.error('Failed to create clients:', error.response?.data || error.message);
        throw error;
    }
};

// Create identity providers
const createIdentityProviders = async () => {
    try {
        console.log('Creating identity providers...');

        // Load identity provider configs
        const idpDir = path.join(__dirname, 'identity-providers');
        const idpFiles = fs.readdirSync(idpDir).filter(file => file.endsWith('.json'));

        for (const file of idpFiles) {
            const idpConfig = JSON.parse(fs.readFileSync(path.join(idpDir, file), 'utf8'));
            const alias = idpConfig.alias;

            // Check if identity provider exists
            try {
                await axios.get(`${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/identity-provider/instances/${alias}`, {
                    headers: {
                        Authorization: `Bearer ${authToken}`
                    }
                });

                console.log(`Identity provider ${alias} already exists. Updating...`);

                // Update existing identity provider
                await axios.put(`${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/identity-provider/instances/${alias}`, idpConfig, {
                    headers: {
                        Authorization: `Bearer ${authToken}`,
                        'Content-Type': 'application/json'
                    }
                });

                console.log(`Identity provider ${alias} updated successfully.`);
                continue;
            } catch (error) {
                if (error.response?.status !== 404) {
                    console.error(`Error checking identity provider ${alias}:`, error.response?.data || error.message);
                    // Continue with creation attempt
                }
            }

            // Create identity provider
            await axios.post(`${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/identity-provider/instances`, idpConfig, {
                headers: {
                    Authorization: `Bearer ${authToken}`,
                    'Content-Type': 'application/json'
                }
            });

            console.log(`Identity provider ${alias} created successfully.`);
        }
    } catch (error) {
        console.error('Failed to create identity providers:', error.response?.data || error.message);
        throw error;
    }
};

// Create test users
const createTestUsers = async () => {
    try {
        console.log('Creating test users...');

        // Load test user configs
        const usersConfig = JSON.parse(fs.readFileSync(path.join(__dirname, 'test-users/sample-users.json'), 'utf8'));

        for (const userConfig of usersConfig) {
            const username = userConfig.username;

            // Check if user exists
            try {
                const response = await axios.get(`${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/users`, {
                    params: {
                        username
                    },
                    headers: {
                        Authorization: `Bearer ${authToken}`
                    }
                });

                if (response.data.length > 0) {
                    const existingUser = response.data[0];
                    console.log(`User ${username} already exists. Updating...`);

                    // Update existing user
                    await axios.put(`${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/users/${existingUser.id}`, userConfig, {
                        headers: {
                            Authorization: `Bearer ${authToken}`,
                            'Content-Type': 'application/json'
                        }
                    });

                    console.log(`User ${username} updated successfully.`);
                    continue;
                }
            } catch (error) {
                console.error(`Error checking user ${username}:`, error.response?.data || error.message);
                // Continue with creation attempt
            }

            // Create user
            await axios.post(`${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/users`, userConfig, {
                headers: {
                    Authorization: `Bearer ${authToken}`,
                    'Content-Type': 'application/json'
                }
            });

            console.log(`User ${username} created successfully.`);
        }
    } catch (error) {
        console.error('Failed to create test users:', error.response?.data || error.message);
        throw error;
    }
};

// Main function
const configure = async () => {
    try {
        console.log('Starting Keycloak configuration...');

        // Get admin token
        authToken = await getToken();

        // Create realm
        await createRealm();

        // Create clients
        await createClients();

        // Create identity providers
        await createIdentityProviders();

        // Create test users
        await createTestUsers();

        console.log('Keycloak configuration completed successfully!');
    } catch (error) {
        console.error('Keycloak configuration failed:', error);
        process.exit(1);
    }
};

// Wait for Keycloak to be ready
const waitForKeycloak = async () => {
    console.log('Waiting for Keycloak to be ready...');
    let ready = false;
    let attempts = 0;
    const maxAttempts = 30;

    while (!ready && attempts < maxAttempts) {
        try {
            await axios.get(`${KEYCLOAK_URL}/health/ready`);
            ready = true;
        } catch (error) {
            attempts++;
            console.log(`Attempt ${attempts}/${maxAttempts}: Keycloak not ready yet. Retrying in 5 seconds...`);
            await new Promise(resolve => setTimeout(resolve, 5000));
        }
    }

    if (!ready) {
        console.error('Keycloak failed to become ready in time.');
        process.exit(1);
    }

    console.log('Keycloak is ready!');
};

// Run configuration
waitForKeycloak()
    .then(configure)
    .catch(error => {
        console.error('Error:', error);
        process.exit(1);
    });
