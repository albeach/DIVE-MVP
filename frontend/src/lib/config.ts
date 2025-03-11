/**
 * Application configuration
 * 
 * This file centralizes all configuration settings for the application
 * including environment-specific settings, feature flags, and constants.
 */

// Environment detection
export const isProduction = process.env.NODE_ENV === 'production';
export const isDevelopment = process.env.NODE_ENV === 'development';
export const isTest = process.env.NODE_ENV === 'test';

// API configuration
export const API_CONFIG = {
    BASE_URL: process.env.NEXT_PUBLIC_API_URL ?
        (process.env.NEXT_PUBLIC_API_URL.endsWith('/v1') ?
            process.env.NEXT_PUBLIC_API_URL :
            `${process.env.NEXT_PUBLIC_API_URL}/v1`) :
        '/api/v1',
    TIMEOUT: {
        DEFAULT: 20000, // 20 seconds
        FILE_OPERATIONS: 60000, // 60 seconds
    },
    RETRY: {
        MAX_RETRIES: 3,
        RETRY_DELAY: 1000, // 1 second
    },
    TOKEN_REFRESH: {
        BUFFER_SECONDS: 30, // Refresh token 30 seconds before expiry
    }
};

// Authentication configuration
export const AUTH_CONFIG = {
    TOKEN_REFRESH_BUFFER: 60, // Refresh token 60 seconds before expiry
    TOKEN_CHECK_INTERVAL: 15000, // Check token expiry every 15 seconds
    DEFAULT_REDIRECT_PATH: '/',
    SILENT_CHECK_SSO_PATH: '/silent-check-sso.html',
};

// Security configuration
export const SECURITY_CONFIG = {
    PASSWORD_MIN_LENGTH: 12,
    PASSWORD_SPECIAL_CHARS_REQUIRED: true,
    SESSION_TIMEOUT: 3600, // 1 hour in seconds
    MAX_FAILED_ATTEMPTS: 5,
};

// Document service configuration
export const DOCUMENT_CONFIG = {
    MAX_FILE_SIZE: 100 * 1024 * 1024, // 100 MB
    ALLOWED_FILE_TYPES: [
        'application/pdf',
        'application/msword',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'text/plain',
        'application/vnd.ms-excel',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        'application/vnd.ms-powerpoint',
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
        'image/jpeg',
        'image/png'
    ],
    PAGINATION: {
        DEFAULT_PAGE_SIZE: 10,
        MAX_PAGE_SIZE: 100,
    },
};

// Feature flags
export const FEATURES = {
    ENABLE_ANALYTICS: isProduction,
    ENABLE_USER_FEEDBACK: true,
    ENABLE_DOCUMENT_PREVIEW: true,
    ENABLE_ADVANCED_SEARCH: true,
    ENABLE_NOTIFICATIONS: false, // Feature under development
};

// Default system values for different environments
export const DEFAULTS = {
    EMAIL_DOMAIN: isProduction ? 'dive25.org' : 'example.com',
    SUPPORT_EMAIL: isProduction ? 'support@dive25.org' : 'test-support@example.com',
    ORGANIZATION: 'DIVE25',
};

// Export a default config object combining all settings
export default {
    API_CONFIG,
    AUTH_CONFIG,
    SECURITY_CONFIG,
    DOCUMENT_CONFIG,
    FEATURES,
    DEFAULTS,
    isProduction,
    isDevelopment,
    isTest,
}; 