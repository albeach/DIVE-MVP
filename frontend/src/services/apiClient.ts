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
const MAX_RETRY_ATTEMPTS = 2;
const RETRY_DELAY = 1000; // 1 second delay between retries

// Declare global Keycloak type
declare global {
    interface Window {
        __keycloak?: any;
    }
}

// Extend AxiosRequestConfig to include retry info
interface ExtendedAxiosRequestConfig extends InternalAxiosRequestConfig {
    _retry?: boolean;
    _retryCount?: number;
    _startTime?: number;
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
    retryable?: boolean;
}

// Keep track of refresh status
let isRefreshing = false;
let refreshPromise: Promise<boolean> | null = null;
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

// List of status codes that can be retried
const RETRYABLE_STATUS_CODES = [408, 429, 500, 502, 503, 504];

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
            originalError: error,
            retryable: true
        };
    }

    if (error.code === 'ERR_NETWORK') {
        return {
            type: ApiErrorType.NETWORK,
            message: 'Network error, please check your connection',
            originalError: error,
            retryable: true
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
                originalError: error,
                retryable: false // Will be handled by token refresh
            };
        case 403:
            return {
                type: ApiErrorType.FORBIDDEN,
                status,
                message: 'You do not have permission to perform this action',
                originalError: error,
                retryable: false
            };
        case 404:
            return {
                type: ApiErrorType.NOT_FOUND,
                status,
                message: 'Resource not found',
                originalError: error,
                retryable: false
            };
        case 422:
            return {
                type: ApiErrorType.VALIDATION,
                status,
                message: error.response?.data && typeof error.response.data === 'object' && 'message' in error.response.data
                    ? String(error.response.data.message)
                    : 'Validation error',
                originalError: error,
                retryable: false
            };
        case 408: // Request Timeout
        case 429: // Too Many Requests
        case 500: // Internal Server Error
        case 502: // Bad Gateway
        case 503: // Service Unavailable
        case 504: // Gateway Timeout
            return {
                type: ApiErrorType.SERVER,
                status,
                message: 'Server error, please try again later',
                originalError: error,
                retryable: true
            };
        default:
            return {
                type: ApiErrorType.UNKNOWN,
                status,
                message: error.message || 'An unknown error occurred',
                originalError: error,
                retryable: status ? status >= 500 : false
            };
    }
};

// Refresh token (with caching)
const refreshAuthToken = async (): Promise<boolean> => {
    // If we're already refreshing, return the existing promise
    if (isRefreshing && refreshPromise) {
        return refreshPromise;
    }

    const keycloakInstance = window.__keycloak;
    if (!keycloakInstance?.authenticated) {
        return Promise.resolve(false);
    }

    isRefreshing = true;
    logger.debug('Refreshing auth token');

    refreshPromise = keycloakInstance.updateToken(TOKEN_REFRESH_TIMEOUT)
        .then((refreshed: boolean) => {
            logger.debug(`Token refresh ${refreshed ? 'complete' : 'not needed'}`);
            isRefreshing = false;

            if (refreshed && keycloakInstance.token) {
                // Update tokens in storage
                sessionStorage.setItem('kc_token', keycloakInstance.token);
                if (keycloakInstance.refreshToken) {
                    sessionStorage.setItem('kc_refreshToken', keycloakInstance.refreshToken);
                }

                // Notify subscribers
                onTokenRefreshed(keycloakInstance.token);
            }

            return true;
        })
        .catch((error: any) => {
            logger.error('Token refresh failed', error);
            isRefreshing = false;
            onRefreshError();

            // Handle session expiry by redirecting to login
            if (keycloakInstance.authenticated) {
                // Store current path for redirect after login
                sessionStorage.setItem('auth_redirect', window.location.pathname + window.location.search);

                // Attempt to logout and redirect to login 
                setTimeout(() => {
                    keycloakInstance.login();
                }, 500);
            }

            return false;
        });

    return refreshPromise;
};

// Request interceptor for API client
apiClient.interceptors.request.use(
    async (config: InternalAxiosRequestConfig) => {
        const extendedConfig = config as ExtendedAxiosRequestConfig;

        // Add request timing data
        extendedConfig._startTime = Date.now();

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
        const extendedConfig = config as ExtendedAxiosRequestConfig;

        // Add request timing data
        extendedConfig._startTime = Date.now();

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
        const extConfig = response.config as ExtendedAxiosRequestConfig;
        const requestStart = extConfig._startTime || parseInt(response.config.headers.get('X-Request-Start') as string, 10);

        if (requestStart) {
            const requestDuration = Date.now() - requestStart;
            logger.debug(`Request to ${response.config.url} completed in ${requestDuration}ms`);

            // Add timing header to response
            response.headers.set('X-Response-Time', requestDuration.toString());
        }

        return response;
    },
    async (error: AxiosError) => {
        const originalRequest = error.config as ExtendedAxiosRequestConfig;
        const apiError = handleApiError(error);

        // Handle retries for network errors and server errors (except auth errors)
        if (
            originalRequest &&
            (!originalRequest._retryCount || originalRequest._retryCount < MAX_RETRY_ATTEMPTS) &&
            apiError.retryable === true &&
            error.response?.status !== 401 &&
            error.response?.status !== 403
        ) {
            // Increment retry count
            originalRequest._retryCount = (originalRequest._retryCount || 0) + 1;

            logger.debug(`Retrying request (${originalRequest._retryCount}/${MAX_RETRY_ATTEMPTS}) due to error: ${apiError.message}`);

            // Add exponential backoff
            const delay = RETRY_DELAY * Math.pow(2, originalRequest._retryCount - 1);
            await new Promise(resolve => setTimeout(resolve, delay));

            return axios(originalRequest);
        }

        // Only proceed with token refresh if:
        // 1. There is a 401 Unauthorized response
        // 2. It's not already a retry
        // 3. We have a Keycloak instance
        const keycloakInstance = window.__keycloak;

        if (error.response?.status === 401 && originalRequest && !originalRequest._retry && keycloakInstance) {
            originalRequest._retry = true;
            logger.debug('401 Unauthorized response, attempting token refresh');

            // Check if Keycloak instance exists and is properly initialized
            if (!keycloakInstance.authenticated) {
                // Not authenticated - we need to log in
                logger.warn('Keycloak not authenticated, redirecting to login');
                sessionStorage.setItem('auth_redirect', window.location.pathname);

                // Let the UI handle the redirect to login
                return Promise.reject(apiError);
            }

            try {
                // Try to refresh the token
                const refreshed = await refreshAuthToken();

                if (refreshed) {
                    // Update the request with the new token
                    originalRequest.headers.set('Authorization', `Bearer ${keycloakInstance.token}`);

                    // Reset any retry count for the fresh token
                    originalRequest._retryCount = 0;

                    // Retry the request
                    return axios(originalRequest);
                } else {
                    // Refresh failed, redirect to login
                    sessionStorage.setItem('auth_redirect', window.location.pathname);
                    keycloakInstance.login();
                    return Promise.reject(apiError);
                }
            } catch (refreshError) {
                logger.error('Token refresh exception', refreshError);

                // Session expired, redirect to login
                keycloakInstance.login();
                return Promise.reject(apiError);
            }
        }

        // For 403 Forbidden errors (permission issues)
        if (error.response?.status === 403) {
            logger.warn('Permission denied', error.response.data);
        }

        // Calculate request duration
        if (originalRequest && originalRequest._startTime) {
            const duration = Date.now() - originalRequest._startTime;
            logger.debug(`Failed request to ${originalRequest.url} after ${duration}ms`);
        }

        // Pass the error to the caller
        return Promise.reject(apiError);
    }
);

// Use similar response interceptor for file client
fileClient.interceptors.response.use(
    (response: AxiosResponse) => {
        // Add performance tracking
        const extConfig = response.config as ExtendedAxiosRequestConfig;
        const requestStart = extConfig._startTime || parseInt(response.config.headers.get('X-Request-Start') as string, 10);

        if (requestStart) {
            const requestDuration = Date.now() - requestStart;
            logger.debug(`File request to ${response.config.url} completed in ${requestDuration}ms`);

            // Add timing header to response
            response.headers.set('X-Response-Time', requestDuration.toString());
        }

        return response;
    },
    async (error: AxiosError) => {
        const originalRequest = error.config as ExtendedAxiosRequestConfig;
        const apiError = handleApiError(error);

        // For file uploads, we generally don't want to retry automatically
        // but we do want to handle auth errors
        if (error.response?.status === 401) {
            const keycloakInstance = window.__keycloak;
            if (keycloakInstance && keycloakInstance.authenticated) {
                logger.debug('401 Unauthorized response for file request, attempting token refresh');

                try {
                    // Try to refresh the token
                    const refreshed = await refreshAuthToken();

                    if (refreshed && originalRequest) {
                        // Update the request with the new token
                        originalRequest.headers.set('Authorization', `Bearer ${keycloakInstance.token}`);

                        // Retry the file upload
                        return axios(originalRequest);
                    }
                } catch (refreshError) {
                    logger.error('Token refresh failed for file request', refreshError);
                }
            }
        }

        // Calculate request duration for logging
        if (originalRequest && originalRequest._startTime) {
            const duration = Date.now() - originalRequest._startTime;
            logger.debug(`Failed file request to ${originalRequest.url} after ${duration}ms`);
        }

        logger.error('File request error', error);
        return Promise.reject(apiError);
    }
);

// Helper function to check if user is authenticated
export const isAuthenticated = (): boolean => {
    return window.__keycloak?.authenticated === true;
};

// Export API client instances
export { fileClient };
export default apiClient; 