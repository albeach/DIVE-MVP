/**
 * Keycloak authentication configuration
 * 
 * This file follows a "hardcoded defaults with environment override" approach:
 * - Default values are hardcoded for clarity and reliability
 * - Environment variables can override these values when needed
 * - This provides the best balance of flexibility and simplicity
 */
import Keycloak from 'keycloak-js';

// Hardcoded default values
const DEFAULT_KEYCLOAK_URL = 'https://keycloak.dive25.local/auth';
const DEFAULT_REALM = 'dive25';
const DEFAULT_CLIENT_ID = 'dive25-frontend';

// Initialize Keycloak instance
const keycloakInit = () => {
    // Get Keycloak URL from environment or use default
    const keycloakUrl = process.env.NEXT_PUBLIC_KEYCLOAK_URL || DEFAULT_KEYCLOAK_URL;
    const realm = process.env.NEXT_PUBLIC_KEYCLOAK_REALM || DEFAULT_REALM;
    const clientId = process.env.NEXT_PUBLIC_KEYCLOAK_CLIENT_ID || DEFAULT_CLIENT_ID;

    // Create keycloak instance
    const keycloak = new Keycloak({
        url: keycloakUrl,
        realm: realm,
        clientId: clientId
    });

    // Log the configuration for debugging
    console.log('Keycloak configuration:', {
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