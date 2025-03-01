const { verifyToken, getUserFromToken } = require('../services/auth.service');
const { ApiError } = require('../utils/error.utils');
const logger = require('../utils/logger');

/**
 * Verify user token and return user info
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Express next middleware function
 */
const verifyUser = async (req, res, next) => {
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

        // Return user info
        res.status(200).json({
            success: true,
            user: {
                id: user._id,
                uniqueId: user.uniqueId,
                username: user.username,
                email: user.email,
                givenName: user.givenName,
                surname: user.surname,
                organization: user.organization,
                countryOfAffiliation: user.countryOfAffiliation,
                clearance: user.clearance,
                caveats: user.caveats,
                coi: user.coi,
                roles: user.roles
            }
        });
    } catch (error) {
        logger.error('Auth verification error:', error);
        next(error);
    }
};

/**
 * Logout user
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Express next middleware function
 */
const logout = async (req, res, next) => {
    try {
        // In a stateless JWT-based authentication system, there's no server-side logout
        // The client should discard the token and redirect to Keycloak logout endpoint

        res.status(200).json({
            success: true,
            message: 'Logout successful',
            keycloakLogoutUrl: `${req.app.get('keycloakConfig').authServerUrl}/realms/${req.app.get('keycloakConfig').realm}/protocol/openid-connect/logout`
        });
    } catch (error) {
        logger.error('Logout error:', error);
        next(error);
    }
};

module.exports = {
    verifyUser,
    logout
};
