// frontend/src/services/apiClient.ts - Updated with better file handling
import axios, { AxiosRequestConfig, AxiosError, InternalAxiosRequestConfig } from 'axios';
import toast from 'react-hot-toast';

// Create axios instance with default config
const apiClient = axios.create({
    baseURL: process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3000/api/v1',
    headers: {
        'Content-Type': 'application/json',
    },
    timeout: 15000, // 15 seconds
});

// Create a separate client for file uploads
const fileClient = axios.create({
    baseURL: process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3000/api/v1',
    headers: {
        'Content-Type': 'multipart/form-data',
    },
    timeout: 60000, // 60 seconds for file operations
});

// Track if a token refresh is in progress
let isRefreshing = false;
let failedQueue: Array<{
    resolve: (value?: unknown) => void;
    reject: (reason?: any) => void;
    config: any;
}> = [];

// Process the failed queue
const processQueue = (error: any = null) => {
    failedQueue.forEach(promise => {
        if (error) {
            promise.reject(error);
        } else {
            promise.resolve();
        }
    });

    failedQueue = [];
};

// Request interceptor to add authorization header for both clients
const addAuthHeader = (config: InternalAxiosRequestConfig): InternalAxiosRequestConfig => {
    // Get token from Keycloak if available
    const keycloakInstance = window.__keycloak;
    if (keycloakInstance?.token) {
        config.headers.set('Authorization', `Bearer ${keycloakInstance.token}`);
    }
    return config;
};

apiClient.interceptors.request.use(addAuthHeader, (error) => Promise.reject(error));
fileClient.interceptors.request.use(addAuthHeader, (error) => Promise.reject(error));

// Response interceptor for error handling (shared logic)
const handleResponseError = async (error: AxiosError): Promise<any> => {
    const { response, config } = error;

    // Handle 401 errors (unauthorized) that occur due to token expiry
    if (response?.status === 401) {
        // Handle token refresh
        const keycloakInstance = window.__keycloak;

        if (keycloakInstance && !isRefreshing) {
            isRefreshing = true;

            try {
                const refreshed = await keycloakInstance.updateToken(30);

                if (refreshed) {
                    // Update config with new token
                    if (config && config.headers) {
                        config.headers['Authorization'] = `Bearer ${keycloakInstance.token}`;
                    }

                    // Retry the original request
                    isRefreshing = false;
                    processQueue();
                    return axios(config!);
                } else {
                    // Token not refreshed but still valid
                    isRefreshing = false;
                    processQueue();
                    return axios(config!);
                }
            } catch (refreshError) {
                // Token refresh failed
                isRefreshing = false;
                processQueue(refreshError);

                // Redirect to login
                toast.error('Session expired. Please log in again.');
                keycloakInstance.login();
                return Promise.reject(error);
            }
        } else if (isRefreshing) {
            // If a refresh is already in progress, queue this request
            return new Promise((resolve, reject) => {
                failedQueue.push({ resolve, reject, config: config! });
            }).then(() => {
                // Retry with new token
                if (config && window.__keycloak?.token) {
                    config.headers!['Authorization'] = `Bearer ${window.__keycloak.token}`;
                }
                return axios(config!);
            }).catch(err => {
                return Promise.reject(err);
            });
        } else {
            // No keycloak instance, just reject
            toast.error('Session expired. Please log in again.');
            window.location.href = '/';
            return Promise.reject(error);
        }
    }

    // Handle different error scenarios
    if (!response) {
        // Network error
        toast.error('Network error. Please check your connection.');
    } else if (response.status === 403) {
        // Forbidden
        toast.error('You do not have permission to perform this action.');
    } else if (response.status === 404) {
        // Not found
        toast.error('The requested resource was not found.');
    } else if (response.status >= 500) {
        // Server error
        toast.error('Server error. Please try again later.');
    }

    return Promise.reject(error);
};

apiClient.interceptors.response.use(
    (response) => response,
    handleResponseError
);

fileClient.interceptors.response.use(
    (response) => response,
    handleResponseError
);

export { apiClient, fileClient };