// api/src/utils/healthcheck.js
const { getConnection } = require('../config/mongodb.config');
const { opaClient } = require('../config/opa.config');
const logger = require('./logger');

/**
 * Check MongoDB connection
 * @returns {Promise<Object>} Health status
 */
const checkMongoDB = async () => {
    try {
        const connection = getConnection();
        if (!connection || !connection.readyState) {
            return { status: 'down', message: 'MongoDB connection not established' };
        }

        // 1 = connected
        if (connection.readyState === 1) {
            // Attempt a simple ping operation
            await connection.db.admin().ping();
            return { status: 'up' };
        }

        return {
            status: 'down',
            message: `MongoDB connection state: ${connection.readyState}`
        };
    } catch (error) {
        logger.error('MongoDB health check failed:', error);
        return { status: 'down', message: error.message };
    }
};

/**
 * Check OPA connection
 * @returns {Promise<Object>} Health status
 */
const checkOPA = async () => {
    try {
        // Simple query to test OPA connection
        logger.debug('Attempting OPA health check');
        const response = await opaClient.get('/health');
        logger.debug('OPA health check response:', response.data);
        return { status: 'up' };
    } catch (error) {
        logger.error('OPA health check failed:', {
            message: error.message,
            code: error.code,
            response: error.response ? {
                status: error.response.status,
                data: error.response.data
            } : 'No response',
            request: error.request ? 'Request sent but no response received' : 'Request setup failed'
        });

        // Try to get more information about the connection
        try {
            logger.debug('Attempting to diagnose OPA connection issue');
            const baseUrl = new URL(opaClient.defaults.baseURL);
            logger.debug(`OPA base URL: ${baseUrl.toString()}`);
        } catch (diagError) {
            logger.error('Error diagnosing OPA connection:', diagError.message);
        }

        return {
            status: 'down',
            message: error.message,
            details: error.code || 'Unknown error'
        };
    }
};

/**
 * Check file storage access
 * @returns {Promise<Object>} Health status
 */
const checkStorage = async () => {
    try {
        const fs = require('fs').promises;
        const path = require('path');
        const config = require('../config');

        // Check if storage directory exists
        await fs.access(config.storage.basePath);

        // Check write permission with a test file
        const testFile = path.join(config.storage.basePath, '.healthcheck');
        await fs.writeFile(testFile, 'ok');
        await fs.unlink(testFile);

        return { status: 'up' };
    } catch (error) {
        logger.error('Storage health check failed:', error);
        return { status: 'down', message: error.message };
    }
};

/**
 * Comprehensive health check
 * @returns {Promise<Object>} Health status
 */
const checkHealth = async () => {
    const mongodb = await checkMongoDB();
    const opa = await checkOPA();
    const storage = await checkStorage();

    const isHealthy =
        mongodb.status === 'up' &&
        opa.status === 'up' &&
        storage.status === 'up';

    return {
        status: isHealthy ? 'ok' : 'degraded',
        timestamp: new Date().toISOString(),
        checks: {
            mongodb,
            opa,
            storage
        }
    };
};

/**
 * Simple liveness check
 * @returns {Object} Health status
 */
const checkLiveness = () => {
    return {
        status: 'ok',
        timestamp: new Date().toISOString()
    };
};

module.exports = {
    checkHealth,
    checkLiveness
};