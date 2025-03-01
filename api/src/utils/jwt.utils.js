const jwt = require('jsonwebtoken');
const config = require('../config');
const { ApiError } = require('./error.utils');
const logger = require('./logger');

/**
 * Generate JWT token
 * @param {Object} payload - Token payload
 * @param {Object} options - Token options
 * @returns {string} JWT token
 */
const generateToken = (payload, options = {}) => {
    try {
        const secret = config.jwt.jwtSecret;
        if (!secret) {
            throw new ApiError('JWT secret is not configured', 500);
        }

        const defaultOptions = {
            expiresIn: config.jwt.expiresIn
        };

        const mergedOptions = { ...defaultOptions, ...options };

        return jwt.sign(payload, secret, mergedOptions);
    } catch (error) {
        logger.error('Error generating JWT token:', error);
        throw error;
    }
};

/**
 * Verify JWT token
 * @param {string} token - JWT token
 * @returns {Object} Decoded token payload
 */
const verifyToken = (token) => {
    try {
        const secret = config.jwt.jwtSecret;
        if (!secret) {
            throw new ApiError('JWT secret is not configured', 500);
        }

        return jwt.verify(token, secret);
    } catch (error) {
        logger.error('Error verifying JWT token:', error);

        if (error.name === 'TokenExpiredError') {
            throw new ApiError('Token has expired', 401);
        } else if (error.name === 'JsonWebTokenError') {
            throw new ApiError('Invalid token', 401);
        }

        throw error;
    }
};

module.exports = {
    generateToken,
    verifyToken
};
