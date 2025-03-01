const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const compression = require('compression');
const { createHttpTerminator } = require('http-terminator');
const { errorHandler } = require('./middleware/error.middleware');
const { loggingMiddleware } = require('./middleware/logging.middleware');
const routes = require('./routes');
const config = require('./config');
const logger = require('./utils/logger');
const { connectToMongoDB } = require('./config/mongodb.config');
const { setupPrometheusMetrics } = require('./utils/metrics');
const { checkHealth, checkLiveness } = require('./utils/healthcheck');

// Initialize express app
const app = express();

// Apply security middleware
app.use(helmet());
app.use(cors({
    origin: config.cors.allowedOrigins,
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
    credentials: true
}));

// Apply common middleware
app.use(compression());
app.use(express.json({ limit: '1mb' }));
app.use(express.urlencoded({ extended: true, limit: '1mb' }));
app.use(loggingMiddleware);

// Setup Prometheus metrics endpoint
setupPrometheusMetrics(app);

// Apply API routes
app.use('/api/v1', routes);

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
const server = app.listen(config.port, async () => {
    try {
        // Connect to MongoDB
        await connectToMongoDB();
        logger.info(`Server running on port ${config.port}`);
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
process.on('uncaughtException', (error) => {
    logger.error('Uncaught exception:', error);
    shutdown();
});

module.exports = { app, server };
