const jwt = require('jsonwebtoken');
const { keycloakJwksClient } = require('../config/keycloak.config');
const { User } = require('../models/user.model');
const { createAuditLog } = require('./audit.service');
const config = require('../config');
const logger = require('../utils/logger');
const { ApiError } = require('../utils/error.utils');

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

        // Decode token without verification to extract header
        const decodedToken = jwt.decode(tokenValue, { complete: true });
        if (!decodedToken) {
            throw new ApiError('Invalid token', 401);
        }

        // Get the key ID from the token header
        const kid = decodedToken.header.kid;

        // Get the public key from Keycloak
        const getKey = (header, callback) => {
            keycloakJwksClient.getSigningKey(header.kid, (err, key) => {
                if (err) {
                    return callback(err);
                }
                const signingKey = key.publicKey || key.rsaPublicKey;
                callback(null, signingKey);
            });
        };

        // Verify the token
        return new Promise((resolve, reject) => {
            jwt.verify(tokenValue, getKey, { algorithms: ['RS256'] }, (err, decoded) => {
                if (err) {
                    logger.error('Token verification failed:', err);
                    return reject(new ApiError('Invalid token', 401));
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

module.exports = {
    verifyToken,
    getUserFromToken
};
