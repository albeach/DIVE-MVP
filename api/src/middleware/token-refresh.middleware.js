/**
 * Middleware to check token expiration and add refresh headers
 */
const { checkTokenExpiration } = require('../services/auth.service');
const logger = require('../utils/logger');
const NodeCache = require('node-cache');

// Cache token expiration info to reduce token decoding overhead
const tokenExpiryCache = new NodeCache({ stdTTL: 60, checkperiod: 15 });

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
    const startTime = Date.now();

    try {
        // Get token from request
        const token = req.token || extractToken(req);

        // Skip if no token
        if (!token) {
            return next();
        }

        // Try to get from cache first
        const cacheKey = `exp_${token}`;
        let expirationInfo = tokenExpiryCache.get(cacheKey);

        if (!expirationInfo) {
            // Not in cache, check token expiration
            expirationInfo = await checkTokenExpiration(token);

            // Cache the result if valid
            if (expirationInfo) {
                // Cache for a shorter time if the token is about to expire
                const cacheTTL = expirationInfo.isExpiring ?
                    Math.min(expirationInfo.expiresIn, 30) : // Cache for token expiry time or 30 seconds, whichever is less
                    60; // Cache for 60 seconds otherwise

                tokenExpiryCache.set(cacheKey, expirationInfo, cacheTTL);
            }
        }

        if (expirationInfo) {
            // Add headers to inform client about token expiration status
            res.setHeader('X-Token-Expires-In', expirationInfo.expiresIn.toString());

            if (expirationInfo.isExpiring) {
                // Add warning header if token is about to expire
                res.setHeader('X-Token-Expiring', 'true');

                // Add refresh hint with different levels of urgency
                if (expirationInfo.expiresIn < 30) {
                    // Less than 30 seconds - critical
                    res.setHeader('X-Token-Refresh-Now', 'true');
                    res.setHeader('X-Token-Refresh-Priority', 'critical');
                    logger.warn(`Token critically expiring (${expirationInfo.expiresIn}s) - immediate refresh required`);
                } else if (expirationInfo.expiresIn < 60) {
                    // Less than 1 minute - high priority
                    res.setHeader('X-Token-Refresh-Now', 'true');
                    res.setHeader('X-Token-Refresh-Priority', 'high');
                    logger.debug(`Token expiring very soon (${expirationInfo.expiresIn}s) - refresh recommended`);
                } else {
                    // Otherwise - medium priority
                    res.setHeader('X-Token-Refresh-Priority', 'medium');
                    logger.debug(`Token expiring in ${expirationInfo.expiresIn} seconds - added headers`);
                }
            }
        }

        // Add processing time as header for diagnostics
        const processingTime = Date.now() - startTime;
        if (processingTime > 50) { // Only log if processing takes more than 50ms
            logger.debug(`Token expiration check took ${processingTime}ms`);
        }

        next();
    } catch (error) {
        // Non-blocking error - just log and continue
        logger.error('Error in token expiration check middleware:', {
            error: {
                message: error.message,
                stack: error.stack
            },
            path: req.path,
            method: req.method,
            processingTime: Date.now() - startTime
        });
        next();
    }
};

/**
 * Clear token expiry cache for a specific token
 * @param {string} token - Token to clear from cache
 */
const clearTokenExpiryCache = (token) => {
    if (token) {
        tokenExpiryCache.del(`exp_${token}`);
    }
};

module.exports = {
    tokenExpirationCheck,
    clearTokenExpiryCache
}; 