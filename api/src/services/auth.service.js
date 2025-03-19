const jwt = require('jsonwebtoken');
const { User } = require('../models/user.model');
const { createAuditLog } = require('./audit.service');
const logger = require('../utils/logger');
const { ApiError } = require('../utils/error.utils');
const NodeCache = require('node-cache');

// Create a cache for user data with 5-minute TTL
const userCache = new NodeCache({
    stdTTL: 300, // 5 minutes
    checkperiod: 60, // check for expired keys every 1 minute
    useClones: false,
    maxKeys: 1000 // Limit cache size to prevent memory issues
});

/**
 * Get user information from token payload and update or create user in local database
 * @param {Object} tokenPayload - Decoded token payload or user info from Kong
 * @returns {Promise<Object>} User object
 */
const getUserFromToken = async (tokenPayload) => {
    try {
        if (!tokenPayload) {
            throw new Error('No token payload provided');
        }

        // Extract user attributes from token payload
        const uniqueId = tokenPayload.sub;
        const username = tokenPayload.preferred_username || tokenPayload.username;
        const email = tokenPayload.email;
        const givenName = tokenPayload.given_name;
        const surname = tokenPayload.family_name;
        const organization = tokenPayload.organization || tokenPayload.adminOrganization;
        const countryOfAffiliation = tokenPayload.countryOfAffiliation;
        const clearance = tokenPayload.clearance;
        const caveats = tokenPayload.caveats ?
            (Array.isArray(tokenPayload.caveats) ? tokenPayload.caveats : [tokenPayload.caveats]) :
            [];
        const coi = tokenPayload.cOI || tokenPayload.aCPCOI ?
            (Array.isArray(tokenPayload.cOI || tokenPayload.aCPCOI) ? (tokenPayload.cOI || tokenPayload.aCPCOI) : [tokenPayload.cOI || tokenPayload.aCPCOI]) :
            [];

        // Find or create user in local database
        let user = await User.findOne({ uniqueId });

        if (user) {
            // Update existing user
            user.username = username;
            user.email = email;
            user.givenName = givenName;
            user.surname = surname;
            user.organization = organization;
            user.countryOfAffiliation = countryOfAffiliation;
            user.clearance = clearance;
            user.caveats = caveats;
            user.coi = coi;
            user.lastLogin = new Date();

            await user.save();
            logger.info(`User updated: ${uniqueId}`);
        } else {
            // Create new user
            user = await User.create({
                uniqueId,
                username,
                email,
                givenName,
                surname,
                organization,
                countryOfAffiliation,
                clearance,
                caveats,
                coi,
                lastLogin: new Date(),
                roles: ['user']
            });

            logger.info(`New user created: ${uniqueId}`);
        }

        // Create audit log for login
        await createAuditLog({
            userId: user.uniqueId,
            username: user.username,
            action: 'LOGIN',
            details: {
                method: 'federation'
            },
            success: true
        });

        return user;
    } catch (error) {
        logger.error('Error getting user from token:', error);
        throw new ApiError('User authentication failed', 500);
    }
};

/**
 * Check token expiration and refresh if needed
 * @param {string} token - Current token
 * @returns {Promise<Object>} Token expiration info
 */
const checkTokenExpiration = async (token) => {
    try {
        // Extract token without Bearer prefix if present
        const tokenValue = token.startsWith('Bearer ') ? token.split(' ')[1] : token;

        // Decode token without verification (Kong has already verified it)
        const decoded = jwt.decode(tokenValue);
        if (!decoded || !decoded.exp) {
            return null;
        }

        // Check if token is about to expire (less than 5 minutes left)
        const expiresIn = decoded.exp - Math.floor(Date.now() / 1000);
        if (expiresIn < 300) {
            logger.debug(`Token expires in ${expiresIn} seconds`);
            return { isExpiring: true, expiresIn };
        }

        return { isExpiring: false, expiresIn };
    } catch (error) {
        logger.error('Error checking token expiration:', error);
        return null;
    }
};

/**
 * Clear user cache
 */
const clearUserCache = () => {
    userCache.flushAll();
    logger.info('User cache cleared');
};

module.exports = {
    getUserFromToken,
    checkTokenExpiration,
    clearUserCache,
};
