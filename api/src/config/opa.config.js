const axios = require('axios');
const config = require('./index');
const logger = require('../utils/logger');

// Create axios instance for OPA
const opaClient = axios.create({
    baseURL: config.opa.url,
    timeout: config.opa.timeout,
    headers: {
        'Content-Type': 'application/json',
    },
});

// Add request interceptor for logging
opaClient.interceptors.request.use(
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
opaClient.interceptors.response.use(
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

module.exports = {
    opaClient,
    policyPath: config.opa.policyPath,
};
