/**
 * URL utilities for the application
 */

/**
 * Get the base URL for API requests
 * Uses environment variables with fallbacks
 */
export const getBaseUrl = (): string => {
    // In browser, use the relative URL to the API
    if (typeof window !== 'undefined') {
        const apiUrl = process.env.NEXT_PUBLIC_API_URL;
        if (apiUrl) {
            // If absolute URL is provided, use it
            if (apiUrl.startsWith('http')) {
                return apiUrl;
            }

            // Otherwise, append to origin
            return `${window.location.origin}${apiUrl}`;
        }

        // Default to relative API path
        return `${window.location.origin}/api`;
    }

    // Server-side, use the internal API URL if available
    return process.env.INTERNAL_API_URL || 'http://backend:8080';
};

/**
 * Get the auth server URL for login/logout operations
 */
export const getAuthServerUrl = (): string => {
    // Use the Keycloak URL directly without adding '/auth'
    return process.env.NEXT_PUBLIC_KEYCLOAK_URL || 'https://keycloak.dive25.local';
}; 