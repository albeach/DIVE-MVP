const { ApiError } = require('../utils/error.utils');
const logger = require('../utils/logger');
const { createAuditLog } = require('../services/audit.service');

/**
 * Global error handler middleware
 * @param {Error} err - Error object
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Express next middleware function
 */
const errorHandler = async (err, req, res, next) => { // eslint-disable-line no-unused-vars
    let statusCode = 500;
    let message = 'Internal Server Error';
    let details = null;
    let errorCode = 'INTERNAL_ERROR';

    // Handle known errors
    if (err instanceof ApiError) {
        statusCode = err.statusCode;
        message = err.message;
        details = err.details;
        errorCode = err.errorCode || `ERROR_${statusCode}`;
    } else if (err.name === 'ValidationError') {
        // Mongoose validation error
        statusCode = 400;
        message = 'Validation Error';
        details = Object.values(err.errors).map(val => val.message);
        errorCode = 'VALIDATION_ERROR';
    } else if (err.name === 'MongoError' && err.code === 11000) {
        // MongoDB duplicate key error
        statusCode = 409;
        message = 'Duplicate Key Error';
        details = err.keyValue;
        errorCode = 'DUPLICATE_KEY_ERROR';
    } else if (err.name === 'JsonWebTokenError') {
        // JWT validation error
        statusCode = 401;
        message = 'Invalid token';
        errorCode = 'INVALID_TOKEN';
    } else if (err.name === 'TokenExpiredError') {
        // JWT expired error
        statusCode = 401;
        message = 'Token expired';
        errorCode = 'TOKEN_EXPIRED';
    } else if (err.code === 'ECONNREFUSED' || err.code === 'ECONNRESET') {
        // Connection errors
        statusCode = 503;
        message = 'Service unavailable';
        details = err.message;
        errorCode = 'SERVICE_UNAVAILABLE';
    } else if (err.name === 'SyntaxError' && err.message.includes('JSON')) {
        // JSON parsing error
        statusCode = 400;
        message = 'Invalid JSON in request body';
        errorCode = 'INVALID_JSON';
    } else {
        // Unknown error
        logger.error('Unhandled error:', {
            error: {
                name: err.name,
                message: err.message,
                stack: err.stack,
                code: err.code
            },
            request: {
                path: req.path,
                method: req.method,
                query: req.query,
                headers: req.headers,
                ip: req.ip
            }
        });
    }

    // Create audit log for errors if user is authenticated
    try {
        if (req.user) {
            await createAuditLog({
                userId: req.user.uniqueId,
                username: req.user.username,
                action: 'SYSTEM_ERROR',
                details: {
                    path: req.path,
                    method: req.method,
                    statusCode,
                    message,
                    errorCode,
                    details
                },
                ipAddress: req.ip,
                userAgent: req.get('User-Agent'),
                success: false,
                errorMessage: message
            });
        }
    } catch (auditError) {
        logger.error('Failed to create audit log for error:', auditError);
    }

    // Send error response
    res.status(statusCode).json({
        success: false,
        error: {
            message,
            code: errorCode,
            details,
            timestamp: new Date().toISOString()
        }
    });
};

module.exports = {
    errorHandler
};
