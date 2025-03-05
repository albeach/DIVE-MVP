import axios, { AxiosInstance, AxiosRequestConfig, AxiosResponse, AxiosError, InternalAxiosRequestConfig } from 'axios';

// Define base URL
const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || '/api';

// Declare global Keycloak type
declare global {
    interface Window {
        __keycloak?: any;
    }
}

// Extend AxiosRequestConfig to include retry flag
interface ExtendedAxiosRequestConfig extends InternalAxiosRequestConfig {
    _retry?: boolean;
}

// Keep track of refresh status
let isRefreshing = false;
let refreshSubscribers: ((token: string) => void)[] = [];

// Function to push a callback to be executed when token is refreshed
function subscribeTokenRefresh(callback: (token: string) => void) {
    refreshSubscribers.push(callback);
}

// Function to notify all subscribers that token is refreshed
function onTokenRefreshed(token: string) {
    refreshSubscribers.forEach(callback => callback(token));
    refreshSubscribers = [];
}

// Function to handle token refresh error
function onRefreshError() {
    refreshSubscribers = [];
}

// Create the axios instance
const apiClient: AxiosInstance = axios.create({
    baseURL: API_BASE_URL,
    timeout: 20000, // 20 second timeout
    headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json'
    }
});

// Create a separate client for file uploads
const fileClient: AxiosInstance = axios.create({
    baseURL: API_BASE_URL,
    timeout: 60000, // 60 seconds for file operations
    headers: {
        'Content-Type': 'multipart/form-data',
    }
});

// Request interceptor for API client
apiClient.interceptors.request.use(
    async (config: InternalAxiosRequestConfig) => {
        // Skip auth header for public endpoints
        if (config.url && [
            '/health',
            '/api/public',
            '/api/config/public'
        ].some(publicPath => config.url?.includes(publicPath))) {
            return config;
        }

        // Auth paths that need authentication
        const needsAuth = config.url && [
            '/api/auth',
            '/api/user'
        ].some(authPath => config.url?.includes(authPath));

        // Get token from Keycloak if available
        const keycloakInstance = window.__keycloak;
        if (keycloakInstance?.token) {
            config.headers.set('Authorization', `Bearer ${keycloakInstance.token}`);
        } else if (needsAuth) {
            // If auth is needed but not available, store the current location for after login
            sessionStorage.setItem('auth_redirect', window.location.pathname);
        }

        return config;
    },
    (error) => Promise.reject(error)
);

// Use the same interceptor for file client
fileClient.interceptors.request.use(
    async (config: InternalAxiosRequestConfig) => {
        // Get token from Keycloak if available
        const keycloakInstance = window.__keycloak;
        if (keycloakInstance?.token) {
            config.headers.set('Authorization', `Bearer ${keycloakInstance.token}`);
        }
        return config;
    },
    (error) => Promise.reject(error)
);

// Response interceptor for API client
apiClient.interceptors.response.use(
    (response: AxiosResponse) => {
        return response;
    },
    async (error: AxiosError) => {
        const originalRequest = error.config as ExtendedAxiosRequestConfig;

        // Only proceed if:
        // 1. There is a 401 Unauthorized response
        // 2. It's not already a retry
        // 3. We have a Keycloak instance
        // 4. We're not already refreshing
        const keycloakInstance = window.__keycloak;

        if (error.response?.status === 401 &&
            originalRequest &&
            !originalRequest._retry &&
            keycloakInstance && !isRefreshing) {

            originalRequest._retry = true;

            // Check if Keycloak instance exists and is properly initialized
            if (!keycloakInstance.authenticated) {
                // Not authenticated - we need to log in
                sessionStorage.setItem('auth_redirect', window.location.pathname);

                // Let the UI handle the redirect to login
                return Promise.reject(error);
            }

            try {
                isRefreshing = true;

                // Try to refresh the token
                const refreshed = await keycloakInstance.updateToken(30);

                if (refreshed) {
                    // Update the request with the new token
                    originalRequest.headers.set('Authorization', `Bearer ${keycloakInstance.token}`);

                    // Let other requests know the token was refreshed
                    onTokenRefreshed(keycloakInstance.token);
                }

                isRefreshing = false;

                // Retry the request
                return axios(originalRequest);
            } catch (refreshError) {
                isRefreshing = false;
                onRefreshError();

                // Session expired, redirect to login
                keycloakInstance.login();
                return Promise.reject(error);
            }
        }

        // For 403 Forbidden errors (permission issues)
        if (error.response?.status === 403) {
            console.error('Permission denied', error);
            // Let UI component handle the forbidden error
        }

        // Pass the error to the caller
        return Promise.reject(error);
    }
);

// Use the same response interceptor for file client
fileClient.interceptors.response.use(
    (response: AxiosResponse) => response,
    async (error: AxiosError) => {
        // Use the same error handling as the API client
        if (error.response?.status === 401) {
            const keycloakInstance = window.__keycloak;
            if (keycloakInstance) {
                // Try to refresh the token or redirect to login
                keycloakInstance.updateToken(30).catch(() => {
                    keycloakInstance.login();
                });
            }
        }
        return Promise.reject(error);
    }
);

// Helper function to check if user is authenticated
export const isAuthenticated = (): boolean => {
    return window.__keycloak?.authenticated === true;
};

export { fileClient };
export default apiClient; 