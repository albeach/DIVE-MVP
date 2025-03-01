// opa/integration/opa-middleware.js
/**
 * OPA Middleware for Express
 * Provides middleware to integrate OPA access control with Express
 */

const OpaClient = require('./opa-client');
const logger = require('./logger');

/**
 * Creates middleware to check document access using OPA
 * @param {OpaClient} opaClient - OPA client instance
 * @returns {Function} Express middleware
 */
const documentAccessMiddleware = (opaClient = new OpaClient()) => {
    return async (req, res, next) => {
        try {
            // Skip if no user or document
            if (!req.user || !req.document) {
                return next();
            }

            logger.debug('Checking document access:', {
                userId: req.user.uniqueId,
                documentId: req.document._id
            });

            const { allowed, explanation } = await opaClient.checkDocumentAccess(
                req.user,
                req.document
            );

            if (!allowed) {
                logger.warn('Access denied:', {
                    userId: req.user.uniqueId,
                    documentId: req.document._id,
                    explanation
                });

                return res.status(403).json({
                    success: false,
                    error: {
                        message: 'Access denied',
                        details: explanation,
                        timestamp: new Date().toISOString()
                    }
                });
            }

            // Access granted, continue
            next();
        } catch (error) {
            logger.error('Error in OPA middleware:', error);

            // Deny access on error for safety
            return res.status(500).json({
                success: false,
                error: {
                    message: 'Error checking access control policy',
                    timestamp: new Date().toISOString()
                }
            });
        }
    };
};

/**
 * Creates a function to check access for a list of documents and filter out
 * documents the user doesn't have access to
 * @param {OpaClient} opaClient - OPA client instance
 * @returns {Function} Document filter function
 */
const documentFilterFactory = (opaClient = new OpaClient()) => {
    return async (user, documents) => {
        if (!user || !documents || documents.length === 0) {
            return [];
        }

        const accessResults = await Promise.all(
            documents.map(doc => opaClient.checkDocumentAccess(user, doc))
        );

        // Filter documents based on access results
        return documents.filter((_, index) => accessResults[index].allowed);
    };
};

module.exports = {
    documentAccessMiddleware,
    documentFilterFactory
};