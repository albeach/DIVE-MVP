/**
 * Middleware to check token expiration and add refresh headers
 */
const { checkTokenExpiration } = require('../services/auth.service');
const logger = require('../utils/logger');

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
 * Checks token expiration and adds headers to inform clients when tokens are about to expire
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Express next middleware function
 */
const tokenExpirationCheck = async (req, res, next) => {
    try {
        // Get token from request
        const token = req.token || extractToken(req);

        // Skip if no token
        if (!token) {
            return next();
        }

        // Check token expiration
        const expirationInfo = await checkTokenExpiration(token);

        if (expirationInfo) {
            // Add headers to inform client about token expiration status
            res.setHeader('X-Token-Expires-In', expirationInfo.expiresIn.toString());

            if (expirationInfo.isExpiring) {
                // Add warning header if token is about to expire
                res.setHeader('X-Token-Expiring', 'true');

                // Add refresh hint if expiration is very close
                if (expirationInfo.expiresIn < 60) { // Less than 1 minute
                    res.setHeader('X-Token-Refresh-Now', 'true');
                    logger.debug(`Token expiring very soon (${expirationInfo.expiresIn}s) - refresh recommended`);
                } else {
                    logger.debug(`Token expiring in ${expirationInfo.expiresIn} seconds - added headers`);
                }
            }
        }

        next();
    } catch (error) {
        // Non-blocking error - just log and continue
        logger.error('Error in token expiration check middleware:', {
            error: {
                message: error.message,
                stack: error.stack
            }
        });
        next();
    }
};

module.exports = {
    tokenExpirationCheck
}; 