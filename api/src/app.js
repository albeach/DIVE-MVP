const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const compression = require('compression');
const { createHttpTerminator } = require('http-terminator');
const fs = require('fs');
const http = require('http');
const https = require('https');
const { errorHandler } = require('./middleware/error.middleware');
const { loggingMiddleware } = require('./middleware/logging.middleware');
const { tokenExpirationCheck } = require('./middleware/token-refresh.middleware');
const routes = require('./routes');
const config = require('./config');
const logger = require('./utils/logger');
const { connectToMongoDB } = require('./config/mongodb.config');
const { setupPrometheusMetrics } = require('./utils/metrics');
const { checkHealth, checkLiveness } = require('./utils/healthcheck');
const swagger = require('./swagger');
const path = require('path');

// Import routes
const authRoutes = require('./routes/auth.routes');
const userRoutes = require('./routes/users.routes');
const documentRoutes = require('./routes/documents.routes');
const healthRoutes = require('./routes/health.routes');
const ldapRoutes = require('./routes/ldap.routes');

// Initialize express app
const app = express();

// Apply security middleware
app.use(helmet({
    contentSecurityPolicy: {
        directives: {
            defaultSrc: ["'self'"],
            scriptSrc: ["'self'", "'unsafe-inline'", "'unsafe-eval'"],
            styleSrc: ["'self'", "'unsafe-inline'"],
            imgSrc: ["'self'", "data:"]
        }
    }
}));

// Add headers before CORS to handle preflight requests
app.use((req, res, next) => {
    // For Swagger UI compatibility
    res.header('Access-Control-Allow-Origin', req.headers.origin || '*');
    res.header('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept, Authorization, X-Request-Start');
    res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
    res.header('Access-Control-Allow-Credentials', 'true');

    // Handle preflight
    if (req.method === 'OPTIONS') {
        return res.status(204).end();
    }

    next();
});

app.use(cors({
    origin: function (origin, callback) {
        const allowedOrigins = config.cors.allowedOrigins;
        // Allow requests with no origin (like mobile apps or curl requests)
        if (!origin || allowedOrigins.indexOf(origin) !== -1) {
            callback(null, true);
        } else {
            console.log(`CORS blocked for origin: ${origin}`);
            callback(null, true); // Temporarily allow all origins for debugging
        }
    },
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With', 'X-Request-Start'],
    credentials: true,
    maxAge: 86400 // 24 hours
}));

// Apply common middleware
app.use(compression());
app.use(express.json({ limit: '1mb' }));
app.use(express.urlencoded({ extended: true, limit: '1mb' }));
app.use(loggingMiddleware);

// Setup Prometheus metrics endpoint
setupPrometheusMetrics(app);

// Add token expiration check middleware (must be before routes)
app.use(tokenExpirationCheck);

// Add debug endpoint
app.get('/api/v1/debug/auth', (req, res) => {
    logger.info('Debug auth request received');
    res.status(200).json({ message: 'Debug auth endpoint', success: true });
});

// Add a new debug endpoint to log all headers and token information
app.get('/api/v1/debug/token-info', (req, res) => {
    const token = req.headers.authorization;
    const allHeaders = req.headers;

    logger.info('Token debug request received', {
        headers: allHeaders,
        token: token
    });

    // Try to decode the token if present
    let decodedToken = null;
    if (token && token.startsWith('Bearer ')) {
        try {
            const jwt = require('jsonwebtoken');
            decodedToken = jwt.decode(token.substring(7));
        } catch (error) {
            logger.error('Error decoding token:', error);
        }
    }

    res.status(200).json({
        message: 'Token debug information',
        headers: allHeaders,
        token: token,
        decodedToken: decodedToken
    });
});

// Add user creation debug endpoint
app.get('/api/v1/create-test-user', async (req, res) => {
    try {
        const { User } = require('./models/user.model');

        // Create a test user that matches the Keycloak user
        const testUser = await User.findOneAndUpdate(
            { uniqueId: '9ef2bfa0-4410-45d2-adea-ed4368df4727' }, // This should match the Keycloak user's sub
            {
                username: 'testuser',
                email: 'testuser@example.com',
                givenName: 'Test',
                surname: 'User',
                organization: 'DIVE25',
                countryOfAffiliation: 'US',
                clearance: 'UNCLASSIFIED',
                caveats: [],
                coi: [],
                lastLogin: new Date(),
                roles: ['user']
            },
            { upsert: true, new: true }
        );

        logger.info('Test user created or updated:', {
            userId: testUser.uniqueId,
            username: testUser.username
        });

        return res.json({
            success: true,
            message: 'Test user created or updated',
            user: testUser
        });
    } catch (error) {
        logger.error('Error creating test user:', error);
        return res.status(500).json({
            success: false,
            message: 'Error creating test user',
            error: error.message
        });
    }
});

// Add detailed token debug endpoint
app.get('/api/token-debug', (req, res) => {
    try {
        const authHeader = req.headers.authorization;
        if (!authHeader) {
            return res.status(400).json({
                message: 'No authorization header provided',
                headers: Object.keys(req.headers)
            });
        }

        // Extract token from Bearer format
        const token = authHeader.startsWith('Bearer ') ? authHeader.substring(7) : authHeader;

        // Decode token without verification
        const jwt = require('jsonwebtoken');
        const decodedToken = jwt.decode(token);

        // Get Kong headers
        const userInfoHeader = req.headers['x-userinfo'] || req.headers['x-user-info'];
        let userInfo = null;

        if (userInfoHeader) {
            try {
                userInfo = JSON.parse(Buffer.from(userInfoHeader, 'base64').toString('utf-8'));
            } catch (e) {
                userInfo = { error: 'Failed to parse user info header', message: e.message };
            }
        }

        return res.json({
            message: 'Token debug information',
            tokenDecoded: decodedToken,
            kongHeaders: {
                userInfo: userInfo,
                authConsumer: req.headers['x-consumer-id'],
                authUsername: req.headers['x-consumer-username'],
                customId: req.headers['x-consumer-custom-id'],
            },
            allHeaders: req.headers
        });
    } catch (error) {
        return res.status(500).json({
            message: 'Error processing token',
            error: error.message,
            stack: error.stack
        });
    }
});

// Add a public endpoint to test user retrieval without authentication
app.get('/api/v1/public/test-user', async (req, res) => {
    try {
        const { User } = require('./models/user.model');
        const user = await User.findOne({ username: 'testuser' });

        if (!user) {
            return res.status(404).json({
                success: false,
                message: 'Test user not found'
            });
        }

        return res.json({
            success: true,
            message: 'Test user retrieved successfully',
            user: {
                id: user._id,
                uniqueId: user.uniqueId,
                username: user.username,
                email: user.email,
                givenName: user.givenName,
                surname: user.surname,
                organization: user.organization,
                roles: user.roles
            }
        });
    } catch (error) {
        logger.error('Error retrieving test user:', error);
        return res.status(500).json({
            success: false,
            message: 'Error retrieving test user',
            error: error.message
        });
    }
});

// Add a public endpoint to create a test user
app.get('/api/v1/public/create-test-user', async (req, res) => {
    try {
        const { User } = require('./models/user.model');

        // Create a test user that matches the Keycloak user
        const testUser = await User.findOneAndUpdate(
            { uniqueId: '9ef2bfa0-4410-45d2-adea-ed4368df4727' }, // This should match the Keycloak user's sub
            {
                username: 'testuser',
                email: 'testuser@example.com',
                givenName: 'Test',
                surname: 'User',
                organization: 'DIVE25',
                countryOfAffiliation: 'US',
                clearance: 'UNCLASSIFIED',
                caveats: [],
                coi: [],
                lastLogin: new Date(),
                roles: ['user']
            },
            { upsert: true, new: true }
        );

        logger.info('Test user created or updated:', {
            userId: testUser.uniqueId,
            username: testUser.username
        });

        return res.json({
            success: true,
            message: 'Test user created or updated',
            user: testUser
        });
    } catch (error) {
        logger.error('Error creating test user:', error);
        return res.status(500).json({
            success: false,
            message: 'Error creating test user',
            error: error.message
        });
    }
});

// Register routes - only use one approach for route registration
// Using the combined router approach
app.use('/api/v1', routes);

// These are redundant and might cause issues, commenting them out
// app.use('/api/v1/auth', authRoutes);
// app.use('/api/v1/users', userRoutes);
// app.use('/api/v1/documents', documentRoutes);
app.use('/health', healthRoutes);  // Keep this as it's not part of /api/v1
// app.use('/api/v1/ldap', ldapRoutes);

// Serve Swagger UI
swagger.serve(app);

// Serve static files from the React app
if (process.env.NODE_ENV === 'production') {
    app.use(express.static(path.join(__dirname, '../../frontend/build')));
}

// Serve uploaded avatar files
app.use('/api/uploads/avatars', express.static(path.join(__dirname, '../uploads/avatars')));

// Apply error handler middleware
app.use(errorHandler);

// Health check endpoint
app.get('/health', (req, res) => {
    res.status(200).json({ status: 'ok' });
});

// Liveness check endpoint - simple check if the application is running
app.get('/health/live', (req, res) => {
    const healthInfo = checkLiveness();
    res.status(200).json(healthInfo);
});

// Readiness check endpoint - comprehensive check of all dependencies
app.get('/health/ready', async (req, res) => {
    try {
        const healthInfo = await checkHealth();
        const statusCode = healthInfo.status === 'ok' ? 200 : 503;
        res.status(statusCode).json(healthInfo);
    } catch (error) {
        logger.error('Health check error:', error);
        res.status(500).json({
            status: 'error',
            timestamp: new Date().toISOString(),
            error: 'Health check failed'
        });
    }
});

// Start the server
let server;

// Check if HTTPS is enabled
const useHttps = process.env.USE_HTTPS === 'true';
if (useHttps) {
    try {
        // Read SSL certificate files
        const sslCertPath = process.env.SSL_CERT_PATH || '/app/certs/tls.crt';
        const sslKeyPath = process.env.SSL_KEY_PATH || '/app/certs/tls.key';

        if (!fs.existsSync(sslCertPath) || !fs.existsSync(sslKeyPath)) {
            logger.error(`SSL certificate files not found at ${sslCertPath} or ${sslKeyPath}`);
            logger.warn('Falling back to HTTP server');
            server = http.createServer(app);
        } else {
            const options = {
                cert: fs.readFileSync(sslCertPath),
                key: fs.readFileSync(sslKeyPath)
            };

            logger.info('Starting HTTPS server with SSL certificates');
            server = https.createServer(options, app);
        }
    } catch (error) {
        logger.error('Error setting up HTTPS server:', error);
        logger.warn('Falling back to HTTP server');
        server = http.createServer(app);
    }
} else {
    logger.info('Starting HTTP server (HTTPS not enabled)');
    server = http.createServer(app);
}

server.listen(config.port, '0.0.0.0', async () => {
    try {
        // Connect to MongoDB if not in test mode
        if (process.env.SKIP_MONGODB !== 'true') {
            try {
                await connectToMongoDB();
                logger.info('MongoDB connected successfully');
            } catch (mongoError) {
                logger.error('MongoDB connection failed:', mongoError);
                logger.warn('Running without MongoDB connection. Some features may not work.');
            }
        } else {
            logger.info('Skipping MongoDB connection as SKIP_MONGODB=true');
        }

        logger.info(`Server running on port ${config.port} (${useHttps ? 'HTTPS' : 'HTTP'})`);
    } catch (error) {
        logger.error('Failed to start server:', error);
        process.exit(1);
    }
});

// Setup graceful shutdown
const httpTerminator = createHttpTerminator({ server });

const shutdown = async () => {
    logger.info('Shutting down server...');
    try {
        await httpTerminator.terminate();
        logger.info('Server terminated');
        process.exit(0);
    } catch (error) {
        logger.error('Error during shutdown:', error);
        process.exit(1);
    }
};

// Listen for termination signals
process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);
process.on('uncaughtException', (err) => {
    logger.error({
        msg: 'Uncaught exception',
        error: {
            message: err.message,
            stack: err.stack,
            name: err.name,
            code: err.code,
            details: err.toString()
        }
    });
    // Initiate shutdown after uncaught exception
    shutdown();
});

module.exports = { app, server };
