// frontend/src/services/apiClient.ts - Updated with better file handling
import axios from 'axios';
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

// Request interceptor to add authorization header for both clients
const addAuthHeader = (config) => {
    // Get token from Keycloak if available
    const keycloakInstance = window.__keycloak;
    if (keycloakInstance?.token) {
        config.headers.Authorization = `Bearer ${keycloakInstance.token}`;
    }
    return config;
};

apiClient.interceptors.request.use(addAuthHeader, (error) => Promise.reject(error));
fileClient.interceptors.request.use(addAuthHeader, (error) => Promise.reject(error));

// Response interceptor for error handling (shared logic)
const handleResponseError = (error) => {
    const { response } = error;

    // Handle different error scenarios
    if (!response) {
        // Network error
        toast.error('Network error. Please check your connection.');
    } else if (response.status === 401) {
        // Unauthorized - redirect to login
        toast.error('Session expired. Please log in again.');

        // Attempt to refresh token or redirect to login
        const keycloakInstance = window.__keycloak;
        if (keycloakInstance) {
            keycloakInstance.login();
        }
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