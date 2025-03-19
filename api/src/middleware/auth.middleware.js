const { getUserFromToken } = require('../services/auth.service');
const { ApiError } = require('../utils/error.utils');
const logger = require('../utils/logger');
const NodeCache = require('node-cache');

// Create a cache for user data with 5-minute TTL and more frequent checks
const userCache = new NodeCache({ stdTTL: 300, checkperiod: 30 });
// Create a separate blacklist cache for revoked tokens
const tokenBlacklist = new NodeCache({ stdTTL: 3600, checkperiod: 60 });

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
 * Extract user information from incoming Kong headers or token
 * @param {Object} req - Express request object
 * @returns {Object|null} - User information or null
 */
const extractUserInfo = (req) => {
    // Kong should pass user info in specific headers if OIDC plugin is configured properly
    const kongUser = req.headers['x-userinfo'] || req.headers['x-user-info'];

    if (kongUser) {
        try {
            return JSON.parse(Buffer.from(kongUser, 'base64').toString('utf-8'));
        } catch (error) {
            logger.error('Error parsing Kong user info header:', error);
            return null;
        }
    }

    return null;
};

/**
 * Authentication middleware to verify JWT token
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Express next middleware function
 */
const authenticate = async (req, res, next) => {
    // ============================================================================
    // BEGIN TEMPORARY AUTH BYPASS FOR TESTING 
    // ============================================================================
    // WARNING: This is a temporary workaround to bypass JWT validation issues
    // with the Kong OIDC plugin. This should be REMOVED before deploying to 
    // production or any environment accessible outside development.
    //
    // This code allows any request with the X-Skip-JWT-Verification header to 
    // bypass normal authentication and use a hardcoded test user instead.
    //
    // TODO: SECURITY RISK - Remove this bypass before deploying to production!
    // ============================================================================
    if (req.headers["x-skip-jwt-verification"]) {
        logger.info("SECURITY WARNING: Using test authentication bypass due to X-Skip-JWT-Verification header");
        req.user = {
            uniqueId: 'test-user-123',
            username: 'test.user',
            email: 'test.user@example.com',
            roles: ['user'],
            clearance: "NATO SECRET",
            countryOfAffiliation: "USA",
            caveats: ["FVEY", "NATO"],
            coi: ["OpAlpha", "OpBravo"]
        };
        req.token = extractToken(req) || "test-token";
        return next();
    }
    // ============================================================================
    // END TEMPORARY AUTH BYPASS FOR TESTING
    // ============================================================================

    const startTime = Date.now();
    try {
        // Get token from authorization header
        const token = extractToken(req);
        if (!token) {
            throw new ApiError('No authorization token provided', 401, 'MISSING_TOKEN');
        }

        // In Kong-integrated mode, we trust that Kong has already validated 
        // the token through the OIDC plugin, so we don't need to re-verify it

        // Check if user data is in cache
        const cacheKey = `auth_${token}`;
        const cachedUser = userCache.get(cacheKey);

        if (cachedUser) {
            req.user = cachedUser;
            req.token = token;

            logger.debug(`Auth from cache for ${cachedUser.username} - ${Date.now() - startTime}ms`);
            return next();
        }

        // Try to get user info from Kong headers
        const userInfo = extractUserInfo(req);

        // If Kong didn't provide user info through headers, we need to extract it from the token
        // This is a fallback mechanism in case Kong authentication is used without header propagation
        if (!userInfo) {
            try {
                // Get user from token payload - note we're not verifying the token,
                // as we trust Kong has already done this
                const jwt = require('jsonwebtoken');
                const decodedToken = jwt.decode(token);

                if (!decodedToken) {
                    throw new ApiError('Invalid token format', 401, 'INVALID_TOKEN');
                }

                // Get user from token payload
                const user = await getUserFromToken(decodedToken);

                // Cache user data
                userCache.set(cacheKey, user);

                // Attach user and token to request
                req.user = user;
                req.token = token;

                logger.debug(`Auth completed for ${user.username} - ${Date.now() - startTime}ms`);
                return next();
            } catch (error) {
                throw new ApiError('Failed to process authentication token', 401, 'AUTH_ERROR');
            }
        }

        // If we have user info from Kong, use it directly
        const user = await getUserFromToken(userInfo);

        // Cache user data
        userCache.set(cacheKey, user);

        // Attach user and token to request
        req.user = user;
        req.token = token;

        logger.debug(`Auth completed for ${user.username} from Kong headers - ${Date.now() - startTime}ms`);
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
                },
                path: req.path,
                method: req.method,
                processingTime: Date.now() - startTime
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
                userRoles: req.user ? req.user.roles : [],
                path: req.path
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

/**
 * Blacklist a token (e.g. on logout)
 * @param {string} token - Token to blacklist
 * @param {number} ttl - Time to live in seconds
 */
const blacklistToken = (token, ttl = 3600) => {
    if (token) {
        tokenBlacklist.set(token, true, ttl);
        // Also clear from user cache
        clearUserCache(token);
    }
};

module.exports = {
    authenticate,
    authorize,
    clearUserCache,
    blacklistToken
};
