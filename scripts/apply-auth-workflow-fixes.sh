#!/bin/bash
#
# Apply Authentication Workflow Fixes
# ==================================
#
# This script applies the authentication workflow fixes to the API and frontend services
# to ensure they work properly with Kong and Keycloak.
#
# It should be run after deploying the services, either manually or as part of the deployment process.
#

set -e

# Set colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Authentication Workflow Fix Script ===${NC}"
echo -e "${BLUE}This script will apply the auth workflow fixes to the API and Frontend services${NC}"

# Define container names with defaults
API_CONTAINER=${API_CONTAINER:-dive25-api}
FRONTEND_CONTAINER=${FRONTEND_CONTAINER:-dive25-frontend}
KONG_CONTAINER=${KONG_CONTAINER:-dive25-kong}

# Check if containers are running
echo -e "${BLUE}Checking if containers are running...${NC}"

if docker ps | grep -q "${API_CONTAINER}"; then
  echo -e "${GREEN}✓ API container is running${NC}"
else
  echo -e "${RED}✗ API container (${API_CONTAINER}) is not running. Please start it first.${NC}"
  exit 1
fi

if docker ps | grep -q "${FRONTEND_CONTAINER}"; then
  echo -e "${GREEN}✓ Frontend container is running${NC}"
else
  echo -e "${RED}✗ Frontend container (${FRONTEND_CONTAINER}) is not running. Please start it first.${NC}"
  exit 1
fi

if docker ps | grep -q "${KONG_CONTAINER}"; then
  echo -e "${GREEN}✓ Kong container is running${NC}"
else
  echo -e "${RED}✗ Kong container (${KONG_CONTAINER}) is not running. Please start it first.${NC}"
  exit 1
fi

echo ""
echo -e "${BLUE}=== Applying Auth Middleware Fix to API ===${NC}"

# Define API middleware paths
AUTH_MIDDLEWARE_PATH="/app/src/middleware/auth.middleware.js"
AUTH_SERVICE_PATH="/app/src/services/auth.service.js"
TOKEN_REFRESH_PATH="/app/src/middleware/token-refresh.middleware.js"

# Create backup of the original files
echo "Creating backups of original files..."
docker exec ${API_CONTAINER} cp ${AUTH_MIDDLEWARE_PATH} ${AUTH_MIDDLEWARE_PATH}.bak
docker exec ${API_CONTAINER} cp ${AUTH_SERVICE_PATH} ${AUTH_SERVICE_PATH}.bak
docker exec ${API_CONTAINER} cp ${TOKEN_REFRESH_PATH} ${TOKEN_REFRESH_PATH}.bak

# Apply the auth middleware fix
echo "Applying auth.middleware.js fix..."
cat <<'EOF' | docker exec -i ${API_CONTAINER} tee ${AUTH_MIDDLEWARE_PATH} > /dev/null
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
EOF

# Apply the auth service fix
echo "Applying auth.service.js fix..."
cat <<'EOF' | docker exec -i ${API_CONTAINER} tee ${AUTH_SERVICE_PATH} > /dev/null
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
EOF

# Apply the token refresh middleware fix
echo "Applying token-refresh.middleware.js fix..."
cat <<'EOF' | docker exec -i ${API_CONTAINER} tee ${TOKEN_REFRESH_PATH} > /dev/null
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
        return authHeader;
    }

    // If not in Bearer format, add the Bearer prefix
    return `Bearer ${authHeader}`;
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
        // When using Kong with OIDC, Kong should handle token expiration and refresh
        // But we'll still provide token expiry information to clients as a convenience

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
EOF

echo -e "${GREEN}API middleware fixes applied successfully${NC}"

echo ""
echo -e "${BLUE}=== Applying Keycloak Config Fix to Frontend ===${NC}"

# Define frontend keycloak path
KEYCLOAK_TS_PATH="/app/src/lib/keycloak.ts"

# Create backup of the original file
echo "Creating backup of original file..."
docker exec ${FRONTEND_CONTAINER} cp ${KEYCLOAK_TS_PATH} ${KEYCLOAK_TS_PATH}.bak

# Apply the frontend keycloak fix
echo "Applying keycloak.ts fix..."
cat <<'EOF' | docker exec -i ${FRONTEND_CONTAINER} tee ${KEYCLOAK_TS_PATH} > /dev/null
/**
 * Keycloak authentication configuration
 * 
 * This file integrates with our standardized URL management approach:
 * - Environment variables are used for all URLs
 * - Consistent naming conventions for auth paths
 * - Clear fallbacks for development
 */
import Keycloak from 'keycloak-js';
import { createLogger } from '../utils/logger';

// Create a logger instance for authentication
const logger = createLogger('auth');

// In production/staging, all traffic should go through Kong on HTTPS port 8443
// These values are just fallbacks for local development
const DEFAULT_KONG_URL = 'https://dive25.local:8443';
const DEFAULT_KEYCLOAK_URL = 'https://keycloak.dive25.local:8443';
const DEFAULT_REALM = 'dive25';
const DEFAULT_CLIENT_ID = 'dive25-frontend';

/**
 * Ensures the URL is compatible with Keycloak 21+ (no /auth path)
 */
const sanitizeKeycloakUrl = (url: string): string => {
    // For Keycloak 21+, we need to remove the /auth path if it exists
    if (url.endsWith('/auth')) {
        const cleanUrl = url.slice(0, -5);
        logger.debug(`Removed '/auth' from URL for Keycloak 21+: ${url} -> ${cleanUrl}`);
        return cleanUrl;
    }
    return url;
};

/**
 * Get the correct redirect URI for authentication callbacks
 */
const getRedirectUri = (): string => {
    // In a browser environment
    if (typeof window !== 'undefined') {
        // Get the base URL - should be the Kong URL for external access
        const kongBaseUrl = process.env.NEXT_PUBLIC_KONG_URL || DEFAULT_KONG_URL;
        
        // Use the configured redirect path that matches Kong's OIDC plugin configuration
        // The OIDC plugin in Kong is configured with /callback path
        return `${kongBaseUrl}/callback`;
    }
    
    // Fallback for SSR
    return `${DEFAULT_KONG_URL}/callback`;
};

// Initialize Keycloak instance with proper URL handling
const keycloakInit = () => {
    // For Keycloak URL, we need direct access in local dev but Kong proxy in prod/staging
    const isProduction = process.env.NODE_ENV === 'production';
    // Custom check for staging environment, since NODE_ENV might not be 'staging'
    const isStaging = process.env.NEXT_PUBLIC_ENV === 'staging';
    
    // In production/staging environments, all traffic should route through Kong HTTPS
    // For Keycloak initialization, we need to use the proper URL
    let keycloakUrl;
    if (isProduction || isStaging) {
        // In production/staging, use Kong proxy for Keycloak traffic
        keycloakUrl = sanitizeKeycloakUrl(process.env.NEXT_PUBLIC_KONG_URL || DEFAULT_KONG_URL);
        logger.info('Using Kong proxy for Keycloak in production/staging');
    } else {
        // In development, use direct Keycloak URL
        keycloakUrl = sanitizeKeycloakUrl(process.env.NEXT_PUBLIC_KEYCLOAK_URL || DEFAULT_KEYCLOAK_URL);
        logger.info('Using direct Keycloak URL in development');
    }
    
    const realm = process.env.NEXT_PUBLIC_KEYCLOAK_REALM || DEFAULT_REALM;
    const clientId = process.env.NEXT_PUBLIC_KEYCLOAK_CLIENT_ID || DEFAULT_CLIENT_ID;

    logger.info('Initializing Keycloak with:', {
        url: keycloakUrl,
        realm: realm,
        clientId: clientId
    });

    try {
        // Create keycloak instance with base configuration
        const keycloak = new Keycloak({
            url: keycloakUrl,
            realm: realm,
            clientId: clientId
        });

        // Add error-handling mechanisms
        keycloak.onTokenExpired = () => {
            logger.debug('Token expired, refreshing...');
            keycloak.updateToken(30).catch(err => {
                logger.error('Failed to refresh token', err);
            });
        };

        // Store main URL for UI display/redirects in keycloak object for later use
        // @ts-ignore - Adding custom property to keycloak
        keycloak.mainDomainUrl = process.env.NEXT_PUBLIC_KONG_URL || 
                                 process.env.NEXT_PUBLIC_FRONTEND_URL || 
                                 DEFAULT_KONG_URL;

        // Bind the login and logout methods to the keycloak instance
        // This ensures proper handling of 'this' context
        const originalLoginMethod = keycloak.login;
        keycloak.login = function (options) {
            // Use the consistent redirect URI
            const redirectUri = getRedirectUri();
            
            const loginOptions = {
                ...options,
                // Set up parameters to use our custom theme
                ui_locales: 'en',
                kc_theme: 'dive25',
                prompt: 'login' as const,
                // Use the consistent redirect URI that matches Kong's OIDC configuration
                redirectUri: redirectUri
            };

            logger.debug('Keycloak login with options:', {
                ...loginOptions,
                redirectUri
            });
            
            return originalLoginMethod.call(this, loginOptions);
        };
        
        // Override logout to use consistent redirect URI
        const originalLogoutMethod = keycloak.logout;
        keycloak.logout = function (options) {
            // Get the Kong URL for redirection
            // @ts-ignore - Accessing custom property
            const kongUrl = keycloak.mainDomainUrl;
            
            const logoutOptions = {
                ...options,
                // Redirect to the main domain after logout
                redirectUri: kongUrl
            };
            
            logger.debug('Keycloak logout with options:', logoutOptions);
            return originalLogoutMethod.call(this, logoutOptions);
        };

        // Log the configuration for debugging
        logger.debug('Keycloak configuration:', {
            url: keycloak.authServerUrl,
            realm: keycloak.realm,
            clientId: keycloak.clientId
        });

        return keycloak;
    } catch (error) {
        logger.error('Error initializing Keycloak:', error);
        // Return a minimal keycloak instance that will gracefully fail
        // This allows the app to continue loading even if Keycloak is unavailable
        return new Keycloak({
            url: keycloakUrl,
            realm: realm,
            clientId: clientId
        });
    }
};

// Export singleton
let keycloakInstance: Keycloak | null = null;

export const getKeycloak = () => {
    if (!keycloakInstance) {
        keycloakInstance = keycloakInit();
    }
    return keycloakInstance;
};

export default getKeycloak;
EOF

echo -e "${GREEN}Frontend Keycloak fix applied successfully${NC}"

# Make the script executable
chmod +x $0

echo ""
echo -e "${GREEN}Authentication workflow fixes have been applied successfully!${NC}"
echo -e "${BLUE}Remember to restart the services for the changes to take effect:${NC}"
echo -e "  docker-compose restart api frontend"
echo ""
echo -e "${YELLOW}Note: These fixes will need to be reapplied if the containers are recreated.${NC}"
echo -e "${YELLOW}Consider integrating this script into your deployment process or making the changes permanent in your source code.${NC}" 