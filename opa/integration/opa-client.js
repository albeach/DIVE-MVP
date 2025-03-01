// opa/integration/opa-client.js
/**
 * OPA Client for DIVE25 API
 * Provides a client library to interact with the Open Policy Agent service
 */

const axios = require('axios');
const logger = require('./logger');

class OpaClient {
    /**
     * Creates a new OPA client
     * @param {string} opaUrl - Base URL for the OPA service
     * @param {string} defaultPolicyPath - Default policy path to evaluate
     */
    constructor(opaUrl = 'http://localhost:8181', defaultPolicyPath = 'dive25/document_access/allow') {
        this.opaUrl = opaUrl;
        this.defaultPolicyPath = defaultPolicyPath;
        this.client = axios.create({
            baseURL: this.opaUrl,
            timeout: 5000, // 5 second timeout
            headers: {
                'Content-Type': 'application/json'
            }
        });

        // Add request interceptor for logging
        this.client.interceptors.request.use(
            (config) => {
                logger.debug('OPA Request:', {
                    url: config.url,
                    method: config.method,
                    data: config.data
                });
                return config;
            },
            (error) => {
                logger.error('OPA Request Error:', error);
                return Promise.reject(error);
            }
        );

        // Add response interceptor for logging
        this.client.interceptors.response.use(
            (response) => {
                logger.debug('OPA Response:', {
                    status: response.status,
                    data: response.data
                });
                return response;
            },
            (error) => {
                logger.error('OPA Response Error:', error.response ? {
                    status: error.response.status,
                    data: error.response.data
                } : error.message);
                return Promise.reject(error);
            }
        );
    }

    /**
     * Evaluate a policy with the given input
     * @param {Object} input - Input document for policy evaluation
     * @param {string} policyPath - Policy path to evaluate (optional)
     * @returns {Promise<boolean>} - True if access is allowed, false otherwise
     */
    async evaluatePolicy(input, policyPath = this.defaultPolicyPath) {
        try {
            const response = await this.client.post(`/v1/data/${policyPath}`, { input });

            return response.data.result === true;
        } catch (error) {
            logger.error('Error evaluating policy:', error);
            // Default to denying access on error
            return false;
        }
    }

    /**
     * Get policy explanation for a decision
     * @param {Object} input - Input document for policy evaluation
     * @param {string} policyPath - Policy path to evaluate (optional)
     * @returns {Promise<string>} - Explanation message
     */
    async getPolicyExplanation(input, policyPath = 'dive25/document_access/explanation') {
        try {
            const response = await this.client.post(`/v1/data/${policyPath}`, { input });

            return response.data.result || 'No explanation available';
        } catch (error) {
            logger.error('Error getting policy explanation:', error);
            return 'Error getting policy explanation';
        }
    }

    /**
     * Check if a user can access a document
     * @param {Object} user - User attributes
     * @param {Object} document - Document metadata
     * @returns {Promise<Object>} - Result with access decision and explanation
     */
    async checkDocumentAccess(user, document) {
        const input = {
            user: {
                uniqueId: user.uniqueId,
                username: user.username,
                clearance: user.clearance,
                countryOfAffiliation: user.countryOfAffiliation,
                caveats: user.caveats || [],
                coi: user.coi || []
            },
            resource: {
                id: document._id || document.id,
                classification: document.metadata.classification,
                releasableTo: document.metadata.releasability || [],
                caveats: document.metadata.caveats || [],
                coiTags: document.metadata.coi || []
            }
        };

        const allowed = await this.evaluatePolicy(input);
        const explanation = allowed ?
            await this.getPolicyExplanation(input) :
            await this.getPolicyExplanation(input);

        return {
            allowed,
            explanation
        };
    }
}

module.exports = OpaClient;