const { verifyToken, getUserFromToken } = require('../services/auth.service');
const { ApiError } = require('../utils/error.utils');
const logger = require('../utils/logger');

/**
 * Authentication middleware to verify JWT token
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Express next middleware function
 */
const authenticate = async (req, res, next) => {
    try {
        // Get token from authorization header
        const token = req.headers.authorization;
        if (!token) {
            throw new ApiError('No authorization token provided', 401);
        }

        // Verify and decode token
        const tokenPayload = await verifyToken(token);

        // Get user from token payload
        const user = await getUserFromToken(tokenPayload);

        // Check if user is active
        if (!user.active) {
            throw new ApiError('User account is disabled', 403);
        }

        // Attach user to request
        req.user = user;

        next();
    } catch (error) {
        logger.error('Authentication error:', error);
        next(error);
    }
};

/**
 * Authorization middleware to check user roles
 * @param {string[]} roles - Required roles
 * @returns {Function} Middleware function
 */
const authorize = (roles) => {
    return (req, res, next) => {
        try {
            // Check if authenticated user has required role
            const hasRole = roles.some(role => req.user.roles.includes(role));

            if (!hasRole) {
                throw new ApiError('You do not have permission to access this resource', 403);
            }

            next();
        } catch (error) {
            logger.error('Authorization error:', error);
            next(error);
        }
    };
};

module.exports = {
    authenticate,
    authorize
};
