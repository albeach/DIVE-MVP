import Keycloak from 'keycloak-js';

// Initialize Keycloak instance
const keycloakInit = () => {
    // Create keycloak instance
    const keycloak = new Keycloak({
        url: (process.env.NEXT_PUBLIC_KEYCLOAK_URL || 'http://localhost:8080') + '/auth',
        realm: process.env.NEXT_PUBLIC_KEYCLOAK_REALM || 'dive25',
        clientId: process.env.NEXT_PUBLIC_KEYCLOAK_CLIENT_ID || 'dive25-frontend'
    });

    // Set custom theme in login options
    const originalLogin = keycloak.login;
    keycloak.login = function (options) {
        const loginOptions = {
            ...options,
            // Add kc_idp_hint if needed for specific identity provider
            // kc_idp_hint: 'specific-provider',

            // Set up parameters to use our custom theme
            ui_locales: 'en',
            // Set the theme explicitly (theme is usually controlled at realm level)
            // but can be overridden for specific login sessions
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