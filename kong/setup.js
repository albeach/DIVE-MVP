// kong/setup.js
const axios = require('axios');

const KONG_ADMIN_URL = process.env.KONG_ADMIN_URL || 'http://localhost:8001';
const API_URL = process.env.API_URL || 'http://dive25-api:3000';
const FRONTEND_URL = process.env.FRONTEND_URL || 'http://dive25-frontend:3000';
const KEYCLOAK_URL = process.env.KEYCLOAK_URL || 'http://keycloak:8080';

const setupKong = async () => {
    try {
        console.log('Setting up Kong gateway for DIVE25...');

        // Create services
        await createService('dive25-api', `${API_URL}`);
        await createService('dive25-frontend', `${FRONTEND_URL}`);

        // Create routes
        await createRoute('dive25-api', '/api');
        await createRoute('dive25-frontend', '/');

        // Add plugins to API routes
        await addPlugins('dive25-api');

        console.log('Kong setup completed successfully!');
    } catch (error) {
        console.error('Error setting up Kong:', error.response?.data || error.message);
        process.exit(1);
    }
};

// Create a Kong service
const createService = async (name, url) => {
    try {
        console.log(`Creating service: ${name}`);

        await axios.put(`${KONG_ADMIN_URL}/services/${name}`, {
            name,
            url
        });

        console.log(`Service ${name} created successfully.`);
    } catch (error) {
        console.error(`Error creating service ${name}:`, error.response?.data || error.message);
        throw error;
    }
};

// Create a Kong route
const createRoute = async (serviceName, path) => {
    try {
        console.log(`Creating route for service: ${serviceName}`);

        await axios.post(`${KONG_ADMIN_URL}/services/${serviceName}/routes`, {
            name: `${serviceName}-route`,
            paths: [path],
            strip_path: false,
            preserve_host: true
        });

        console.log(`Route for service ${serviceName} created successfully.`);
    } catch (error) {
        console.error(`Error creating route for service ${serviceName}:`, error.response?.data || error.message);
        throw error;
    }
};

// Add plugins to a service
const addPlugins = async (serviceName) => {
    try {
        console.log(`Adding plugins to service: ${serviceName}`);

        // CORS plugin
        await axios.put(`${KONG_ADMIN_URL}/services/${serviceName}/plugins`, {
            name: 'cors',
            config: {
                origins: ['*'],
                methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS', 'HEAD', 'PATCH'],
                headers: ['Accept', 'Accept-Version', 'Content-Length', 'Content-MD5', 'Content-Type', 'Date', 'X-Auth-Token', 'Authorization'],
                exposed_headers: ['X-Auth-Token'],
                max_age: 3600,
                credentials: true
            }
        });

        // Rate limiting plugin
        await axios.put(`${KONG_ADMIN_URL}/services/${serviceName}/plugins`, {
            name: 'rate-limiting',
            config: {
                minute: 100,
                hour: 1000,
                policy: 'local'
            }
        });

        // JWT plugin for authentication
        await axios.put(`${KONG_ADMIN_URL}/services/${serviceName}/plugins`, {
            name: 'jwt',
            config: {
                claims_to_verify: ['exp'],
                key_claim_name: 'kid',
                secret_is_base64: false,
                run_on_preflight: true
            }
        });

        // Request transformer plugin for headers
        await axios.put(`${KONG_ADMIN_URL}/services/${serviceName}/plugins`, {
            name: 'request-transformer',
            config: {
                add: {
                    headers: ['X-Forwarded-Proto:https']
                }
            }
        });

        // Logging plugin
        await axios.put(`${KONG_ADMIN_URL}/services/${serviceName}/plugins`, {
            name: 'http-log',
            config: {
                http_endpoint: 'http://dive25-api:3000/api/v1/audit/log',
                method: 'POST',
                timeout: 10000,
                keepalive: 60000,
                retry_count: 5,
                queue_size: 100,
                flush_timeout: 2
            }
        });

        console.log(`Plugins added to service ${serviceName} successfully.`);
    } catch (error) {
        console.error(`Error adding plugins to service ${serviceName}:`, error.response?.data || error.message);
        throw error;
    }
};

// Add a consumer
const addConsumer = async (username, jwt) => {
    try {
        console.log(`Adding consumer: ${username}`);

        // Create consumer
        await axios.put(`${KONG_ADMIN_URL}/consumers`, {
            username
        });

        // Add JWT credential
        await axios.post(`${KONG_ADMIN_URL}/consumers/${username}/jwt`, {
            key: jwt.key,
            secret: jwt.secret,
            algorithm: jwt.algorithm || 'HS256'
        });

        console.log(`Consumer ${username} added successfully.`);
    } catch (error) {
        console.error(`Error adding consumer ${username}:`, error.response?.data || error.message);
        throw error;
    }
};

// Run the setup
setupKong();
