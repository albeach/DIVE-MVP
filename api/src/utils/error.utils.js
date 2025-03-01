/**
 * Custom API error class
 */
class ApiError extends Error {
    /**
     * Create an API error
     * @param {string} message - Error message
     * @param {number} statusCode - HTTP status code
     * @param {any} details - Additional error details
     */
    constructor(message, statusCode = 500, details = null) {
        super(message);
        this.name = 'ApiError';
        this.statusCode = statusCode;
        this.details = details;
        Error.captureStackTrace(this, this.constructor);
    }
}

module.exports = {
    ApiError
};
