import axios, { AxiosInstance, AxiosRequestConfig, AxiosResponse, AxiosError, InternalAxiosRequestConfig } from 'axios';
import { API_CONFIG } from '@/lib/config';
import { createLogger } from '@/utils/logger';

// Create a logger for API client
const logger = createLogger('ApiClient');

// Define base URL
const API_BASE_URL = API_CONFIG.BASE_URL;

// Constants
const TOKEN_REFRESH_TIMEOUT = API_CONFIG.TOKEN_REFRESH.BUFFER_SECONDS;
const REQUEST_TIMEOUT = API_CONFIG.TIMEOUT.DEFAULT;
const FILE_REQUEST_TIMEOUT = API_CONFIG.TIMEOUT.FILE_OPERATIONS;

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

// Configure error types for better handling
export enum ApiErrorType {
    NETWORK = 'network',
    UNAUTHORIZED = 'unauthorized',
    FORBIDDEN = 'forbidden',
    NOT_FOUND = 'not_found',
    VALIDATION = 'validation',
    SERVER = 'server',
    TIMEOUT = 'timeout',
    UNKNOWN = 'unknown'
}

export interface ApiError {
    type: ApiErrorType;
    status?: number;
    message: string;
    originalError?: any;
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

// List of public endpoints that don't need auth
const PUBLIC_ENDPOINTS = [
    '/health',
    '/api/public',
    '/api/config/public'
];

// List of endpoints that require authentication
const AUTH_REQUIRED_ENDPOINTS = [
    '/api/auth',
    '/api/user',
    '/api/documents'
];

// Create the axios instance
const apiClient: AxiosInstance = axios.create({
    baseURL: API_BASE_URL,
    timeout: REQUEST_TIMEOUT,
    headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json'
    }
});

// Create a separate client for file uploads
const fileClient: AxiosInstance = axios.create({
    baseURL: API_BASE_URL,
    timeout: FILE_REQUEST_TIMEOUT,
    headers: {
        'Content-Type': 'multipart/form-data',
    }
});

// Helper to check if an endpoint is public
const isPublicEndpoint = (url?: string): boolean => {
    if (!url) return false;
    return PUBLIC_ENDPOINTS.some(publicPath => url.includes(publicPath));
};

// Helper to check if an endpoint requires auth
const requiresAuth = (url?: string): boolean => {
    if (!url) return false;
    return AUTH_REQUIRED_ENDPOINTS.some(authPath => url.includes(authPath));
};

// Helper to get the Keycloak token
const getAuthToken = (): string | null => {
    const keycloakInstance = window.__keycloak;
    return keycloakInstance?.token || null;
};

// Standardized error handler
const handleApiError = (error: AxiosError): ApiError => {
    // Network errors
    if (error.code === 'ECONNABORTED') {
        return {
            type: ApiErrorType.TIMEOUT,
            message: 'Request timed out, please try again',
            originalError: error
        };
    }

    if (error.code === 'ERR_NETWORK') {
        return {
            type: ApiErrorType.NETWORK,
            message: 'Network error, please check your connection',
            originalError: error
        };
    }

    // HTTP errors
    const status = error.response?.status;

    switch (status) {
        case 401:
            return {
                type: ApiErrorType.UNAUTHORIZED,
                status,
                message: 'Authentication required',
                originalError: error
            };
        case 403:
            return {
                type: ApiErrorType.FORBIDDEN,
                status,
                message: 'You do not have permission to perform this action',
                originalError: error
            };
        case 404:
            return {
                type: ApiErrorType.NOT_FOUND,
                status,
                message: 'Resource not found',
                originalError: error
            };
        case 422:
            return {
                type: ApiErrorType.VALIDATION,
                status,
                message: error.response?.data && typeof error.response.data === 'object' && 'message' in error.response.data
                    ? String(error.response.data.message)
                    : 'Validation error',
                originalError: error
            };
        case 500:
        case 502:
        case 503:
        case 504:
            return {
                type: ApiErrorType.SERVER,
                status,
                message: 'Server error, please try again later',
                originalError: error
            };
        default:
            return {
                type: ApiErrorType.UNKNOWN,
                status,
                message: error.message || 'An unknown error occurred',
                originalError: error
            };
    }
};

// Request interceptor for API client
apiClient.interceptors.request.use(
    async (config: InternalAxiosRequestConfig) => {
        // Skip auth header for public endpoints
        if (isPublicEndpoint(config.url)) {
            return config;
        }

        // Add performance tracking header
        config.headers.set('X-Request-Start', Date.now().toString());

        // Auth paths that need authentication
        const needsAuth = requiresAuth(config.url);

        // Get token from Keycloak if available
        const token = getAuthToken();
        if (token) {
            config.headers.set('Authorization', `Bearer ${token}`);
        } else if (needsAuth) {
            // If auth is needed but not available, store the current location for after login
            sessionStorage.setItem('auth_redirect', window.location.pathname);
        }

        logger.debug(`Making API request to ${config.url}`);
        return config;
    },
    (error) => {
        logger.error('Request interceptor error', error);
        return Promise.reject(handleApiError(error));
    }
);

// Use the same interceptor for file client
fileClient.interceptors.request.use(
    async (config: InternalAxiosRequestConfig) => {
        // Add performance tracking header
        config.headers.set('X-Request-Start', Date.now().toString());

        // Get token from Keycloak if available
        const token = getAuthToken();
        if (token) {
            config.headers.set('Authorization', `Bearer ${token}`);
        }

        logger.debug(`Making file request to ${config.url}`);
        return config;
    },
    (error) => {
        logger.error('File request interceptor error', error);
        return Promise.reject(handleApiError(error));
    }
);

// Response interceptor for API client
apiClient.interceptors.response.use(
    (response: AxiosResponse) => {
        // Add performance tracking
        const requestStart = parseInt(response.config.headers.get('X-Request-Start') as string, 10);
        if (requestStart) {
            const requestDuration = Date.now() - requestStart;
            logger.debug(`Request to ${response.config.url} completed in ${requestDuration}ms`);
        }
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
            logger.debug('401 Unauthorized response, attempting token refresh');

            // Check if Keycloak instance exists and is properly initialized
            if (!keycloakInstance.authenticated) {
                // Not authenticated - we need to log in
                logger.warn('Keycloak not authenticated, redirecting to login');
                sessionStorage.setItem('auth_redirect', window.location.pathname);

                // Let the UI handle the redirect to login
                return Promise.reject(handleApiError(error));
            }

            try {
                isRefreshing = true;
                logger.debug('Attempting to refresh token');

                // Try to refresh the token
                const refreshed = await keycloakInstance.updateToken(TOKEN_REFRESH_TIMEOUT);

                if (refreshed) {
                    logger.info('Token refreshed successfully');
                    // Update the request with the new token
                    originalRequest.headers.set('Authorization', `Bearer ${keycloakInstance.token}`);

                    // Let other requests know the token was refreshed
                    onTokenRefreshed(keycloakInstance.token);
                } else {
                    logger.debug('Token still valid, not refreshed');
                }

                isRefreshing = false;

                // Retry the request
                return axios(originalRequest);
            } catch (refreshError) {
                logger.error('Token refresh failed', refreshError);
                isRefreshing = false;
                onRefreshError();

                // Session expired, redirect to login
                keycloakInstance.login();
                return Promise.reject(handleApiError(error));
            }
        }

        // For 403 Forbidden errors (permission issues)
        if (error.response?.status === 403) {
            logger.warn('Permission denied', error);
        }

        // Pass the error to the caller
        return Promise.reject(handleApiError(error));
    }
);

// Use the same response interceptor for file client
fileClient.interceptors.response.use(
    (response: AxiosResponse) => {
        // Add performance tracking
        const requestStart = parseInt(response.config.headers.get('X-Request-Start') as string, 10);
        if (requestStart) {
            const requestDuration = Date.now() - requestStart;
            logger.debug(`File request to ${response.config.url} completed in ${requestDuration}ms`);
        }
        return response;
    },
    async (error: AxiosError) => {
        // Use the same error handling as the API client
        if (error.response?.status === 401) {
            const keycloakInstance = window.__keycloak;
            if (keycloakInstance) {
                logger.debug('401 Unauthorized response for file request, attempting token refresh');
                // Try to refresh the token or redirect to login
                keycloakInstance.updateToken(TOKEN_REFRESH_TIMEOUT).catch(() => {
                    logger.warn('Token refresh failed for file request, redirecting to login');
                    keycloakInstance.login();
                });
            }
        }

        logger.error('File request error', error);
        return Promise.reject(handleApiError(error));
    }
);

// Helper function to check if user is authenticated
export const isAuthenticated = (): boolean => {
    return window.__keycloak?.authenticated === true;
};

// Export API client instances
export { fileClient };
export default apiClient; 