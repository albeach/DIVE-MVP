const { opaClient, policyPath } = require('../config/opa.config');
const logger = require('../utils/logger');
const { ApiError } = require('../utils/error.utils');

/**
 * Evaluate access control policy using OPA
 * @param {Object} input - Input for policy evaluation
 * @returns {Promise<boolean>} Allow or deny access
 */
const evaluateAccessPolicy = async (input) => {
    try {
        logger.debug('Evaluating access policy:', { input });

        // Prepare the OPA input
        const opaInput = {
            input: {
                user: {
                    clearance: input.user.clearance,
                    countryOfAffiliation: input.user.countryOfAffiliation,
                    caveats: input.user.caveats || [],
                    coi: input.user.coi || []
                },
                resource: {
                    classification: input.resource.classification,
                    releasableTo: input.resource.releasability || [],
                    caveats: input.resource.caveats || [],
                    coiTags: input.resource.coi || []
                }
            }
        };

        // Send request to OPA
        const response = await opaClient.post(policyPath, opaInput);

        // Check if 'allow' field is present in the response
        if (response.data && 'result' in response.data) {
            // Return the 'allow' value (true or false)
            logger.debug('Policy evaluation result:', response.data.result);
            return response.data.result === true;
        }

        // If 'allow' field is not present, deny access by default
        logger.warn('Policy evaluation did not return a valid result:', response.data);
        return false;
    } catch (error) {
        logger.error('Error evaluating access policy:', error);

        // Deny access on error
        return false;
    }
};

/**
 * Get policy details from OPA
 * @returns {Promise<Object>} Policy details
 */
const getPolicy = async () => {
    try {
        // Get the policy data from OPA
        const response = await opaClient.get(`/`);

        return response.data;
    } catch (error) {
        logger.error('Error getting policy:', error);
        throw new ApiError('Failed to get policy', 500);
    }
};

module.exports = {
    evaluateAccessPolicy,
    getPolicy
};
