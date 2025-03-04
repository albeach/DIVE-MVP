// Joi is imported for documentation purposes as schemas use it
// eslint-disable-next-line no-unused-vars
const Joi = require('joi');

/**
 * Validate request body against schema
 * @param {Object} schema - Joi schema
 * @returns {Function} Express middleware
 */
const validateBody = (schema) => {
    return (req, res, next) => {
        const { error } = schema.validate(req.body);
        if (error) {
            return res.status(400).json({
                success: false,
                error: {
                    message: 'Validation Error',
                    details: error.details.map(detail => detail.message),
                    timestamp: new Date().toISOString()
                }
            });
        }
        next();
    };
};

/**
 * Validate request query parameters against schema
 * @param {Object} schema - Joi schema
 * @returns {Function} Express middleware
 */
const validateQuery = (schema) => {
    return (req, res, next) => {
        const { error } = schema.validate(req.query);
        if (error) {
            return res.status(400).json({
                success: false,
                error: {
                    message: 'Validation Error',
                    details: error.details.map(detail => detail.message),
                    timestamp: new Date().toISOString()
                }
            });
        }
        next();
    };
};

/**
 * Validate request parameters against schema
 * @param {Object} schema - Joi schema
 * @returns {Function} Express middleware
 */
const validateParams = (schema) => {
    return (req, res, next) => {
        const { error } = schema.validate(req.params);
        if (error) {
            return res.status(400).json({
                success: false,
                error: {
                    message: 'Validation Error',
                    details: error.details.map(detail => detail.message),
                    timestamp: new Date().toISOString()
                }
            });
        }
        next();
    };
};

module.exports = {
    validateBody,
    validateQuery,
    validateParams
};
