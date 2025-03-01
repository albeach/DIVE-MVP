const mongoose = require('mongoose');
const config = require('./index');
const logger = require('../utils/logger');

let connection;

/**
 * Establishes connection to MongoDB
 * @returns {Promise<mongoose.Connection>} Mongoose connection
 */
const connectToMongoDB = async () => {
    if (connection) return connection;

    try {
        logger.info('Connecting to MongoDB...');

        mongoose.connection.on('connected', () => {
            logger.info('MongoDB connected successfully');
        });

        mongoose.connection.on('error', (err) => {
            logger.error('MongoDB connection error:', err);
        });

        mongoose.connection.on('disconnected', () => {
            logger.info('MongoDB disconnected');
        });

        await mongoose.connect(config.mongodb.uri, config.mongodb.options);
        connection = mongoose.connection;

        return connection;
    } catch (error) {
        logger.error('Failed to connect to MongoDB:', error);
        throw error;
    }
};

/**
 * Closes the MongoDB connection
 */
const disconnectFromMongoDB = async () => {
    if (!connection) return;

    try {
        await mongoose.disconnect();
        connection = null;
        logger.info('Disconnected from MongoDB');
    } catch (error) {
        logger.error('Error disconnecting from MongoDB:', error);
        throw error;
    }
};

module.exports = {
    connectToMongoDB,
    disconnectFromMongoDB,
    getConnection: () => connection,
};
