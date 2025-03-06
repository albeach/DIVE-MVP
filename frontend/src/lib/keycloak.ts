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

// Hardcoded default values as fallbacks for local development only
// These should match the defaults in our .env.development file
const DEFAULT_KEYCLOAK_URL = 'http://localhost:8080/auth';
const DEFAULT_REALM = 'dive25';
const DEFAULT_CLIENT_ID = 'dive25-frontend';

// Initialize Keycloak instance with proper URL handling
const keycloakInit = () => {
    // Get Keycloak URL from environment with fallback to default
    // The environment should provide the complete URL including /auth path
    const keycloakUrl = process.env.NEXT_PUBLIC_KEYCLOAK_URL || DEFAULT_KEYCLOAK_URL;
    const realm = process.env.NEXT_PUBLIC_KEYCLOAK_REALM || DEFAULT_REALM;
    const clientId = process.env.NEXT_PUBLIC_KEYCLOAK_CLIENT_ID || DEFAULT_CLIENT_ID;

    logger.info('Initializing Keycloak with:', {
        url: keycloakUrl,
        realm: realm,
        clientId: clientId
    });

    // Create keycloak instance
    const keycloak = new Keycloak({
        url: keycloakUrl,
        realm: realm,
        clientId: clientId
    });

    // Log the configuration for debugging
    logger.debug('Keycloak configuration:', {
        url: keycloak.authServerUrl,
        realm: keycloak.realm,
        clientId: keycloak.clientId
    });

    // Set custom theme in login options
    const originalLogin = keycloak.login;
    keycloak.login = function (options) {
        const loginOptions = {
            ...options,
            // Set up parameters to use our custom theme
            ui_locales: 'en',
            kc_theme: 'dive25'
        };

        logger.debug('Keycloak login with options:', loginOptions);
        return originalLogin.call(this, loginOptions);
    };

    return keycloak;
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