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
const errorHandler = async (err, req, res, next) => {
    let statusCode = 500;
    let message = 'Internal Server Error';
    let details = null;

    // Handle known errors
    if (err instanceof ApiError) {
        statusCode = err.statusCode;
        message = err.message;
        details = err.details;
    } else if (err.name === 'ValidationError') {
        // Mongoose validation error
        statusCode = 400;
        message = 'Validation Error';
        details = Object.values(err.errors).map(val => val.message);
    } else if (err.name === 'MongoError' && err.code === 11000) {
        // MongoDB duplicate key error
        statusCode = 409;
        message = 'Duplicate Key Error';
        details = err.keyValue;
    } else {
        // Unknown error
        logger.error('Unhandled error:', err);
    }

    // Create audit log for errors if user is authenticated
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
                details
            },
            ipAddress: req.ip,
            userAgent: req.get('User-Agent'),
            success: false,
            errorMessage: message
        });
    }

    // Send error response
    res.status(statusCode).json({
        success: false,
        error: {
            message,
            details,
            timestamp: new Date().toISOString()
        }
    });
};

module.exports = {
    errorHandler
};
