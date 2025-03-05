const morgan = require('morgan');
const logger = require('../utils/logger');
const { performance } = require('perf_hooks');

// List of sensitive fields to redact
const SENSITIVE_FIELDS = [
    'password', 'token', 'accessToken', 'refreshToken', 'secret',
    'apiKey', 'authorization', 'key', 'credential', 'ssn', 'creditCard'
];

// List of paths to skip detailed logging
const SKIP_PATHS = [
    '/health',
    '/health/live',
    '/health/ready',
    '/metrics'
];

/**
 * Redact sensitive information from an object
 * @param {Object} obj - Object to redact
 * @returns {Object} - Redacted object
 */
const redactSensitiveInfo = (obj) => {
    if (!obj || typeof obj !== 'object') {
        return obj;
    }

    const redacted = { ...obj };

    Object.keys(redacted).forEach(key => {
        // Check if the key is a sensitive field
        if (SENSITIVE_FIELDS.some(field => key.toLowerCase().includes(field.toLowerCase()))) {
            redacted[key] = '[REDACTED]';
        } else if (typeof redacted[key] === 'object' && redacted[key] !== null) {
            // Recursively redact nested objects
            redacted[key] = redactSensitiveInfo(redacted[key]);
        }
    });

    return redacted;
};

// Create custom Morgan token for request body
morgan.token('body', (req) => {
    if ((req.method === 'POST' || req.method === 'PUT') && req.body) {
        try {
            const redactedBody = redactSensitiveInfo(req.body);
            return JSON.stringify(redactedBody);
        } catch (error) {
            logger.error('Error redacting request body:', error);
            return '[Error processing body]';
        }
    }
    return '';
});

// Create custom Morgan token for user ID
morgan.token('userId', (req) => {
    return req.user ? req.user.uniqueId : 'anonymous';
});

// Create custom Morgan token for request ID
morgan.token('requestId', (req) => {
    return req.id || '-';
});

// Create a custom logging format
const logFormat = ':requestId :remote-addr :userId :method :url :status :response-time ms - :res[content-length] :body';

// Create Morgan middleware
const httpLogger = morgan(logFormat, {
    stream: {
        write: (message) => {
            logger.info({ msg: 'HTTP Request', httpLog: message.trim() });
        }
    },
    skip: (req) => {
        return SKIP_PATHS.includes(req.path);
    }
});

/**
 * Logging middleware
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Express next middleware function
 */
const loggingMiddleware = (req, res, next) => {
    // Generate request ID if not already present
    req.id = req.id || `req-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;

    // Add request ID to response headers
    res.setHeader('X-Request-ID', req.id);

    // Record start time
    req.startTime = performance.now();

    // Log request completion and timing
    const logRequestCompletion = () => {
        const duration = performance.now() - req.startTime;

        // Log detailed information for slow requests
        if (duration > 1000 && !SKIP_PATHS.includes(req.path)) {
            logger.warn({
                msg: 'Slow request detected',
                requestId: req.id,
                path: req.path,
                method: req.method,
                duration: `${duration.toFixed(2)}ms`,
                user: req.user ? req.user.username : 'anonymous'
            });
        }
    };

    // Add listeners for request completion
    res.on('finish', logRequestCompletion);
    res.on('close', logRequestCompletion);

    // Apply Morgan logging middleware
    httpLogger(req, res, next);
};

module.exports = {
    loggingMiddleware,
    redactSensitiveInfo
};
