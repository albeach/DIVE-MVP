/**
 * Middleware to check token expiration and add refresh headers
 */
const { checkTokenExpiration } = require('../services/auth.service');
const logger = require('../utils/logger');

/**
 * Checks token expiration and adds headers to inform clients when tokens are about to expire
 */
const tokenExpirationCheck = async (req, res, next) => {
    try {
        // Skip if no authorization header or user is not authenticated
        if (!req.headers.authorization || !req.user) {
            return next();
        }

        // Check token expiration
        const expirationInfo = await checkTokenExpiration(req.headers.authorization);
        if (expirationInfo && expirationInfo.isExpiring) {
            // Add headers to inform client about token expiration
            res.setHeader('X-Token-Expiring', 'true');
            res.setHeader('X-Token-Expires-In', expirationInfo.expiresIn.toString());

            logger.debug(`Token expiring in ${expirationInfo.expiresIn} seconds - added headers`);
        }

        next();
    } catch (error) {
        // Non-blocking error - just log and continue
        logger.error('Error in token expiration check middleware:', error);
        next();
    }
};

module.exports = {
    tokenExpirationCheck
}; 