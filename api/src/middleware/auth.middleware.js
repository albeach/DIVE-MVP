const { verifyToken, getUserFromToken } = require('../services/auth.service');
const { ApiError } = require('../utils/error.utils');
const logger = require('../utils/logger');
const NodeCache = require('node-cache');

// Create a cache for user data with 5-minute TTL
const userCache = new NodeCache({ stdTTL: 300, checkperiod: 60 });

/**
 * Extract token from request headers
 * @param {Object} req - Express request object
 * @returns {string|null} - Extracted token or null
 */
const extractToken = (req) => {
    const authHeader = req.headers.authorization;

    if (!authHeader) {
        return null;
    }

    // Check if token is in Bearer format
    if (authHeader.startsWith('Bearer ')) {
        return authHeader.substring(7);
    }

    // If not in Bearer format, return the whole header
    return authHeader;
};

/**
 * Authentication middleware to verify JWT token
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Express next middleware function
 */
const authenticate = async (req, res, next) => {
    try {
        // Get token from authorization header
        const token = extractToken(req);
        if (!token) {
            throw new ApiError('No authorization token provided', 401, 'MISSING_TOKEN');
        }

        // Check if user data is in cache
        const cacheKey = `auth_${token}`;
        const cachedUser = userCache.get(cacheKey);

        if (cachedUser) {
            req.user = cachedUser;
            req.token = token;
            return next();
        }

        // Verify and decode token
        const tokenPayload = await verifyToken(token);

        // Get user from token payload
        const user = await getUserFromToken(tokenPayload);

        // Check if user is active
        if (!user) {
            throw new ApiError('User not found', 401, 'USER_NOT_FOUND');
        }

        if (!user.active) {
            throw new ApiError('User account is disabled', 403, 'ACCOUNT_DISABLED');
        }

        // Cache user data
        userCache.set(cacheKey, user);

        // Attach user and token to request
        req.user = user;
        req.token = token;

        next();
    } catch (error) {
        if (error instanceof ApiError) {
            next(error);
        } else if (error.name === 'JsonWebTokenError') {
            next(new ApiError('Invalid token', 401, 'INVALID_TOKEN'));
        } else if (error.name === 'TokenExpiredError') {
            next(new ApiError('Token expired', 401, 'TOKEN_EXPIRED'));
        } else {
            logger.error('Authentication error:', {
                error: {
                    message: error.message,
                    stack: error.stack
                }
            });
            next(new ApiError('Authentication failed', 500, 'AUTH_ERROR'));
        }
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
            if (!req.user) {
                throw new ApiError('User not authenticated', 401, 'NOT_AUTHENTICATED');
            }

            // Check if authenticated user has required role
            const hasRole = roles.some(role => req.user.roles.includes(role));

            if (!hasRole) {
                throw new ApiError(
                    'You do not have permission to access this resource',
                    403,
                    'INSUFFICIENT_PERMISSIONS'
                );
            }

            next();
        } catch (error) {
            logger.error('Authorization error:', {
                error: error.message,
                user: req.user ? req.user.username : 'unknown',
                requiredRoles: roles,
                userRoles: req.user ? req.user.roles : []
            });
            next(error);
        }
    };
};

/**
 * Clear user cache
 * @param {string} token - Token to clear from cache
 */
const clearUserCache = (token) => {
    if (token) {
        userCache.del(`auth_${token}`);
    }
};

module.exports = {
    authenticate,
    authorize,
    clearUserCache
};
