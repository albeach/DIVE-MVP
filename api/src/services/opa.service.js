const { opaClient, policyPath } = require('../config/opa.config');
const logger = require('../utils/logger');
const { ApiError } = require('../utils/error.utils');

/**
 * Evaluate access control policy using OPA
 * @param {Object} input - Input for policy evaluation
 * @returns {Promise<{allowed: boolean, explanation: string}>} Access result with explanation
 */
const evaluateAccessPolicy = async (input) => {
    try {
        logger.debug('Evaluating access policy:', { input });

        // Prepare the OPA input
        const opaInput = {
            input: {
                user: {
                    uniqueId: input.user.uniqueId,
                    username: input.user.username,
                    clearance: input.user.clearance,
                    countryOfAffiliation: input.user.countryOfAffiliation,
                    caveats: input.user.caveats || [],
                    coi: input.user.coi || [],
                    roles: input.user.roles || []
                },
                resource: {
                    id: input.resource.id,
                    classification: input.resource.classification,
                    releasableTo: input.resource.releasability || [],
                    caveats: input.resource.caveats || [],
                    coiTags: input.resource.coi || []
                }
            }
        };

        // Send request to OPA
        const response = await opaClient.post(policyPath, opaInput);

        // Check if 'result' field is present in the response
        const allowed = response.data && response.data.result === true;

        // Get explanation if available
        let explanation = 'No explanation available';
        try {
            const explanationResponse = await opaClient.post('dive25/document_access/explanation', opaInput);
            if (explanationResponse.data && explanationResponse.data.result) {
                explanation = explanationResponse.data.result;
            }
        } catch (explanationError) {
            logger.warn('Failed to get policy explanation:', explanationError);
        }

        logger.debug('Policy evaluation result:', { allowed, explanation });
        return { allowed, explanation };
    } catch (error) {
        logger.error('Error evaluating access policy:', error);

        // Fall back to a secure default if OPA is unreachable
        // For production, we might want to fail closed (deny access)
        // For development, we might allow access with a warning
        const isDevelopment = process.env.NODE_ENV !== 'production';
        const fallbackAllow = isDevelopment && input.user.roles?.includes('admin');

        const result = {
            allowed: fallbackAllow,
            explanation: fallbackAllow
                ? 'Access granted using fallback policy (admin role in development mode)'
                : 'Access denied - Policy service unavailable'
        };

        logger.warn('Using fallback policy decision:', result);
        return result;
    }
};

/**
 * Check if a user can access a document
 * @param {Object} user - User object
 * @param {Object} document - Document object
 * @returns {Promise<{allowed: boolean, explanation: string}>} Access result with explanation
 */
const checkDocumentAccess = async (user, document) => {
    const input = {
        user: {
            uniqueId: user.uniqueId,
            username: user.username,
            clearance: user.clearance,
            countryOfAffiliation: user.countryOfAffiliation,
            caveats: user.caveats || [],
            coi: user.coi || [],
            roles: user.roles || []
        },
        resource: {
            id: document._id || document.id,
            classification: document.metadata.classification,
            releasability: document.metadata.releasability || [],
            caveats: document.metadata.caveats || [],
            coi: document.metadata.coi || []
        }
    };

    return evaluateAccessPolicy(input);
};

/**
 * Get policy details from OPA
 * @returns {Promise<Object>} Policy details
 */
const getPolicy = async () => {
    try {
        // Get the policy data from OPA
        const response = await opaClient.get('/');
        return response.data;
    } catch (error) {
        logger.error('Error getting policy:', error);
        throw new ApiError('Failed to get policy', 500);
    }
};

module.exports = {
    evaluateAccessPolicy,
    checkDocumentAccess,
    getPolicy
};
