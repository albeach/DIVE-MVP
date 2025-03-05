const jwt = require('jsonwebtoken');
const { keycloakJwksClient } = require('../config/keycloak.config');
const { User } = require('../models/user.model');
const { createAuditLog } = require('./audit.service');
const logger = require('../utils/logger');
const { ApiError } = require('../utils/error.utils');
const NodeCache = require('node-cache');

// Create a cache for JWT validation with 5-minute TTL by default
const tokenCache = new NodeCache({
    stdTTL: 300, // 5 minutes
    checkperiod: 60, // check for expired keys every 1 minute
    useClones: false,
    maxKeys: 1000 // Limit cache size to prevent memory issues
});

// Cache for public keys
const keyCache = new NodeCache({
    stdTTL: 3600, // 1 hour
    checkperiod: 300, // check every 5 minutes
    useClones: false,
    maxKeys: 100 // Limit cache size
});

/**
 * Get public key from Keycloak by kid
 * @param {string} kid - Key ID
 * @returns {Promise<string>} Public key
 */
const getPublicKey = (kid) => {
    return new Promise((resolve, reject) => {
        // Check if key is in cache
        const cachedKey = keyCache.get(kid);
        if (cachedKey) {
            logger.debug(`Using cached public key for kid: ${kid}`);
            return resolve(cachedKey);
        }

        // Get key from Keycloak
        keycloakJwksClient.getSigningKey(kid, (err, key) => {
            if (err) {
                logger.error(`Error getting public key for kid ${kid}:`, err);
                return reject(err);
            }
            const signingKey = key.publicKey || key.rsaPublicKey;

            // Cache the key
            keyCache.set(kid, signingKey);

            resolve(signingKey);
        });
    });
};

/**
 * Verify and decode a JWT token
 * @param {string} token - JWT token to verify
 * @returns {Promise<Object>} Decoded token payload
 */
const verifyToken = async (token) => {
    try {
        // Token format: Bearer <token>
        const tokenParts = token.split(' ');
        if (tokenParts.length !== 2 || tokenParts[0] !== 'Bearer') {
            throw new ApiError('Invalid token format', 401);
        }

        const tokenValue = tokenParts[1];

        // Check if token is in cache
        const cachedResult = tokenCache.get(tokenValue);
        if (cachedResult) {
            logger.debug('Using cached token validation result');
            // If cached result is an error, throw it
            if (cachedResult instanceof Error) {
                throw cachedResult;
            }
            return cachedResult;
        }

        // Decode token without verification to extract header
        const decodedToken = jwt.decode(tokenValue, { complete: true });
        if (!decodedToken) {
            const error = new ApiError('Invalid token', 401);
            tokenCache.set(tokenValue, error); // Cache the error too
            throw error;
        }

        // Get the public key from Keycloak
        const getKey = async (header, callback) => {
            try {
                const signingKey = await getPublicKey(header.kid);
                callback(null, signingKey);
            } catch (err) {
                callback(err);
            }
        };

        // Verify the token
        return new Promise((resolve, reject) => {
            jwt.verify(tokenValue, getKey, { algorithms: ['RS256'] }, (err, decoded) => {
                if (err) {
                    logger.error('Token verification failed:', err);
                    const apiError = new ApiError('Invalid token', 401);
                    tokenCache.set(tokenValue, apiError); // Cache the error
                    return reject(apiError);
                }

                // Cache successful result, but subtract 30 seconds from exp to account for clock skew
                const timeToLive = decoded.exp ? (decoded.exp - Math.floor(Date.now() / 1000) - 30) : 300;
                if (timeToLive > 0) {
                    tokenCache.set(tokenValue, decoded, timeToLive);
                }

                resolve(decoded);
            });
        });
    } catch (error) {
        logger.error('Token verification error:', error);
        if (error instanceof ApiError) {
            throw error;
        }
        throw new ApiError('Token verification failed', 401);
    }
};

/**
 * Get user information from token payload and update or create user in local database
 * @param {Object} tokenPayload - Decoded token payload
 * @returns {Promise<Object>} User object
 */
const getUserFromToken = async (tokenPayload) => {
    try {
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
 * Clear token cache to force re-validation
 */
const clearTokenCache = () => {
    tokenCache.flushAll();
    logger.info('Token cache cleared');
};

/**
 * Check token expiration and refresh if needed
 * @param {string} token - Current token
 * @param {string} refreshToken - Refresh token
 * @returns {Promise<Object>} New tokens if refreshed, or null if no refresh needed
 */
const checkTokenExpiration = async (token) => {
    try {
        // Extract token without Bearer prefix
        const tokenValue = token.split(' ')[1];

        // Decode token without verification
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

module.exports = {
    verifyToken,
    getUserFromToken,
    clearTokenCache,
    checkTokenExpiration,
};
