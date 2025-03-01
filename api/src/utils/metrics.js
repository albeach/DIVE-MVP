const promClient = require('prom-client');
const logger = require('./logger');

// Create a Registry to register metrics
const register = new promClient.Registry();

// Add default metrics
promClient.collectDefaultMetrics({ register });

// Custom HTTP request duration metric
const httpRequestDurationMicroseconds = new promClient.Histogram({
    name: 'http_request_duration_ms',
    help: 'Duration of HTTP requests in ms',
    labelNames: ['method', 'route', 'status_code'],
    buckets: [5, 10, 25, 50, 100, 250, 500, 1000, 2500, 5000, 10000]
});

// Custom HTTP request counter
const httpRequestCounter = new promClient.Counter({
    name: 'http_requests_total',
    help: 'Total number of HTTP requests',
    labelNames: ['method', 'route', 'status_code']
});

// Custom error counter
const errorCounter = new promClient.Counter({
    name: 'errors_total',
    help: 'Total number of errors',
    labelNames: ['type']
});

// Register custom metrics
register.registerMetric(httpRequestDurationMicroseconds);
register.registerMetric(httpRequestCounter);
register.registerMetric(errorCounter);

/**
 * Setup Prometheus metrics endpoint
 * @param {Object} app - Express app
 */
const setupPrometheusMetrics = (app) => {
    // Middleware to measure request duration and count requests
    app.use((req, res, next) => {
        // Skip monitoring for metrics endpoint
        if (req.path === '/metrics') {
            return next();
        }

        // Record start time
        const start = Date.now();

        // Function to record metrics after response
        const recordMetrics = () => {
            // Calculate duration
            const duration = Date.now() - start;

            // Extract route path (normalize to prevent high cardinality)
            let route = req.route ? req.route.path : req.path;

            // Replace route parameters with placeholders
            route = route.replace(/\/[a-f\d]{24}/g, '/:id');

            // Record request duration
            httpRequestDurationMicroseconds.labels(req.method, route, res.statusCode).observe(duration);

            // Count request
            httpRequestCounter.labels(req.method, route, res.statusCode).inc();

            // Count error if status code is 4xx or 5xx
            if (res.statusCode >= 400) {
                const errorType = res.statusCode >= 500 ? 'server' : 'client';
                errorCounter.labels(errorType).inc();
            }

            // Remove listeners to prevent memory leaks
            res.removeListener('finish', recordMetrics);
            res.removeListener('close', recordMetrics);
        };

        // Listen for response events
        res.on('finish', recordMetrics);
        res.on('close', recordMetrics);

        next();
    });

    // Expose metrics endpoint
    app.get('/metrics', async (req, res) => {
        try {
            res.set('Content-Type', register.contentType);
            res.end(await register.metrics());
        } catch (error) {
            logger.error('Error generating metrics:', error);
            res.status(500).send('Error generating metrics');
        }
    });

    logger.info('Prometheus metrics enabled at /metrics endpoint');
};

module.exports = {
    setupPrometheusMetrics,
    register,
    httpRequestDurationMicroseconds,
    httpRequestCounter,
    errorCounter
};
