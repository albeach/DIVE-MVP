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
    const authHeader = req.headers.authorization;
    logger.info('Debug auth request received', {
        authHeader: authHeader ? 'Present' : 'Missing',
        authHeaderPrefix: authHeader ? authHeader.substring(0, 15) + '...' : 'N/A',
        path: req.path,
        method: req.method,
        url: req.url,
        origin: req.headers.origin,
        referer: req.headers.referer
    });

    res.json({
        auth: !!authHeader,
        message: 'Auth debug endpoint',
        timestamp: new Date().toISOString()
    });
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

server.listen(config.port, async () => {
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
