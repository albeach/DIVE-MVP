const morgan = require('morgan');
const logger = require('../utils/logger');

// Create custom Morgan token for request body
morgan.token('body', (req) => {
    if (req.method === 'POST' || req.method === 'PUT') {
        const body = { ...req.body };
        // Remove sensitive fields
        if (body.password) body.password = '[REDACTED]';
        if (body.token) body.token = '[REDACTED]';

        return JSON.stringify(body);
    }
    return '';
});

// Create a custom logging format
const logFormat = ':remote-addr :method :url :status :response-time ms - :res[content-length] :body';

// Create Morgan middleware
const httpLogger = morgan(logFormat, {
    stream: {
        write: (message) => {
            logger.info({ msg: 'HTTP Request', httpLog: message.trim() });
        }
    }
});

/**
 * Logging middleware
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Express next middleware function
 */
const loggingMiddleware = (req, res, next) => {
    // Skip logging for health check endpoint
    if (req.path === '/health') {
        return next();
    }

    // Apply Morgan logging middleware
    httpLogger(req, res, next);
};

module.exports = {
    loggingMiddleware
};
