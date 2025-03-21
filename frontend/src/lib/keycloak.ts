/**
 * Keycloak authentication configuration
 * 
 * This file integrates with our standardized URL management approach:
 * - Environment variables are used for all URLs
 * - Consistent naming conventions for auth paths
 * - Clear fallbacks for development
 */
import Keycloak from 'keycloak-js';
import { createLogger } from '@/utils/logger';

// Create a logger instance for authentication
const logger = createLogger('KeycloakService');

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

        // For Identity Provider broker redirects, Keycloak expects a specific format
        // Use /auth/callback to distinguish it from the Kong OIDC plugin's /callback
        const redirectUri = `${kongBaseUrl}/auth/callback`;
        console.log(`DEBUG: getRedirectUri returning = ${redirectUri}`);
        return redirectUri;
    }

    // Fallback for SSR
    const fallbackUri = `${DEFAULT_KONG_URL}/auth/callback`;
    console.log(`DEBUG: getRedirectUri fallback returning = ${fallbackUri}`);
    return fallbackUri;
};

/**
 * Get the base Keycloak URL for identity provider redirects
 * This helps ensure consistency across the application
 */
export const getKeycloakBaseUrl = (): string => {
    // Always use the Keycloak URL for authentication, with fallback options
    const keycloakUrl = process.env.NEXT_PUBLIC_KEYCLOAK_URL || 'https://keycloak.dive25.local:8443/auth';
    // Extract the base Keycloak URL without the /auth path if present
    const baseUrl = keycloakUrl.replace(/\/auth$/, '');
    console.log(`DEBUG: getKeycloakBaseUrl processing ${keycloakUrl} -> ${baseUrl}`);
    return baseUrl;
};

/**
 * Create a proper redirect URL for an identity provider
 * @param countryIdp The country identity provider ID (e.g., 'usa-oidc')
 * @returns The full URL for the identity provider redirect
 */
export const createIdpRedirectUrl = (countryIdp: string): string => {
    console.log(`===DIVE25 DEBUG START - createIdpRedirectUrl (${new Date().toISOString()})===`);
    console.log(`Input countryIdp: ${countryIdp}`);

    // Get base URL with debugging
    const baseUrl = getKeycloakBaseUrl();
    console.log(`baseUrl: ${baseUrl}`);

    // Get realm with debugging
    const realm = process.env.NEXT_PUBLIC_KEYCLOAK_REALM || 'dive25';
    console.log(`realm: ${realm}`);
    console.log(`NEXT_PUBLIC_KEYCLOAK_REALM env var: ${process.env.NEXT_PUBLIC_KEYCLOAK_REALM}`);

    // Extract country name from the IdP alias (e.g., usa-oidc -> usa)
    const country = countryIdp.split('-')[0];
    console.log(`country: ${country}`);

    // Use the main frontend client ID instead of country-specific
    const clientId = process.env.NEXT_PUBLIC_KEYCLOAK_CLIENT_ID || DEFAULT_CLIENT_ID;
    console.log(`clientId: ${clientId}`);
    console.log(`NEXT_PUBLIC_KEYCLOAK_CLIENT_ID env var: ${process.env.NEXT_PUBLIC_KEYCLOAK_CLIENT_ID}`);
    console.log(`DEFAULT_CLIENT_ID: ${DEFAULT_CLIENT_ID}`);

    // Use the proper auth callback endpoint with /auth prefix
    const kongUrl = process.env.NEXT_PUBLIC_KONG_URL || DEFAULT_KONG_URL;
    console.log(`kongUrl: ${kongUrl}`);
    console.log(`NEXT_PUBLIC_KONG_URL env var: ${process.env.NEXT_PUBLIC_KONG_URL}`);
    console.log(`DEFAULT_KONG_URL: ${DEFAULT_KONG_URL}`);

    const redirectUri = `${kongUrl}/auth/callback`;
    console.log(`redirectUri: ${redirectUri}`);

    // Generate a random state parameter for security
    const state = Math.random().toString(36).substring(2, 15) + Math.random().toString(36).substring(2, 15);
    console.log(`state: ${state}`);

    // Generate a session state parameter for Keycloak's broker service
    const sessionState = Math.random().toString(36).substring(2, 15);
    console.log(`sessionState: ${sessionState}`);

    // Store state in sessionStorage for verification when returning
    if (typeof window !== 'undefined') {
        sessionStorage.setItem('idp_state', state);
        console.log(`Set sessionStorage: idp_state = ${state}`);

        sessionStorage.setItem('idp_session_state', sessionState);
        console.log(`Set sessionStorage: idp_session_state = ${sessionState}`);

        // Add timestamp for debugging
        const timestamp = new Date().toISOString();
        sessionStorage.setItem('idp_redirect_time', timestamp);
        console.log(`Set sessionStorage: idp_redirect_time = ${timestamp}`);

        // Store the country for user context
        sessionStorage.setItem('selected_country', country);
        console.log(`Set sessionStorage: selected_country = ${country}`);
    }

    // Build the IDP redirect URL with session_state parameter
    const encodedRedirectUri = encodeURIComponent(redirectUri);
    console.log(`encodedRedirectUri: ${encodedRedirectUri}`);

    const idpRedirectUrl = `${baseUrl}/realms/${realm}/broker/${countryIdp}/login?client_id=${clientId}&redirect_uri=${encodedRedirectUri}&state=${state}&session_state=${sessionState}`;
    console.log(`FINAL idpRedirectUrl: ${idpRedirectUrl}`);

    // Log all important components for debugging
    console.log(`===URL Components Summary===`);
    console.log(`baseUrl: ${baseUrl}`);
    console.log(`realm: ${realm}`);
    console.log(`countryIdp: ${countryIdp}`);
    console.log(`clientId: ${clientId}`);
    console.log(`redirectUri: ${redirectUri}`);
    console.log(`encodedRedirectUri: ${encodedRedirectUri}`);
    console.log(`state: ${state}`);
    console.log(`sessionState: ${sessionState}`);
    console.log(`===DIVE25 DEBUG END - createIdpRedirectUrl===`);

    return idpRedirectUrl;
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

/**
 * Get the Keycloak configuration from environment variables
 */
export function getKeycloakConfig() {
    return {
        url: process.env.NEXT_PUBLIC_KEYCLOAK_URL,
        realm: process.env.NEXT_PUBLIC_KEYCLOAK_REALM || 'dive25',
        clientId: process.env.NEXT_PUBLIC_KEYCLOAK_CLIENT_ID || 'dive25-frontend'
    };
}

/**
 * Initialize a Keycloak instance if one doesn't exist already
 * @returns A Keycloak instance
 */
export function getKeycloak(): Keycloak {
    if (typeof window === 'undefined') {
        throw new Error('Keycloak can only be initialized in browser environment');
    }

    // Return existing instance if available
    if (window.__keycloak) {
        logger.debug('Using existing Keycloak instance from window');
        return window.__keycloak;
    }

    // Return our cached instance if available
    if (keycloakInstance) {
        logger.debug('Using cached Keycloak instance');
        return keycloakInstance;
    }

    // Create a new instance if needed
    logger.debug('Creating new Keycloak instance');
    const config = getKeycloakConfig();
    logger.debug('Keycloak config:', config);

    keycloakInstance = new Keycloak(config);

    // Store globally for resilience
    window.__keycloak = keycloakInstance;

    return keycloakInstance;
}

/**
 * Clear the Keycloak instance (useful for testing)
 */
export function clearKeycloakInstance(): void {
    keycloakInstance = null;
    if (typeof window !== 'undefined') {
        delete window.__keycloak;
    }
}

export default getKeycloak; 