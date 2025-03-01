const { Audit, actionTypes } = require('../models/audit.model');
const logger = require('../utils/logger');
const { ApiError } = require('../utils/error.utils');

/**
 * Create an audit log entry
 * @param {Object} logData - Audit log data
 * @returns {Promise<Object>} Created audit log
 */
const createAuditLog = async (logData) => {
    try {
        // Validate action type
        if (!actionTypes.includes(logData.action)) {
            logger.warn(`Invalid audit action type: ${logData.action}`);
            logData.action = 'SYSTEM_ERROR';
            logData.details = {
                ...logData.details,
                error: 'Invalid action type',
                originalAction: logData.action
            };
        }

        // Create audit log entry
        const auditLog = new Audit({
            userId: logData.userId,
            username: logData.username,
            action: logData.action,
            resourceId: logData.resourceId,
            resourceType: logData.resourceType,
            details: logData.details,
            ipAddress: logData.ipAddress,
            userAgent: logData.userAgent,
            success: logData.success,
            errorMessage: logData.errorMessage
        });

        // Save audit log
        await auditLog.save();

        return auditLog;
    } catch (error) {
        logger.error('Error creating audit log:', error);
        // Don't throw error to prevent cascading failures
        return null;
    }
};

/**
 * Get audit logs with pagination and filtering
 * @param {Object} filters - Query filters
 * @param {Object} options - Query options (sort, pagination)
 * @returns {Promise<Object>} Audit logs and pagination info
 */
const getAuditLogs = async (filters = {}, options = {}) => {
    try {
        const page = parseInt(options.page) || 1;
        const limit = parseInt(options.limit) || 20;
        const skip = (page - 1) * limit;

        // Build query based on filters
        const query = {};

        // Apply user filter if specified
        if (filters.userId) {
            query.userId = filters.userId;
        }

        // Apply username filter if specified
        if (filters.username) {
            query.username = { $regex: filters.username, $options: 'i' };
        }

        // Apply action filter if specified
        if (filters.action && actionTypes.includes(filters.action)) {
            query.action = filters.action;
        }

        // Apply resource filter if specified
        if (filters.resourceId) {
            query.resourceId = filters.resourceId;
        }

        // Apply resource type filter if specified
        if (filters.resourceType) {
            query.resourceType = filters.resourceType;
        }

        // Apply success filter if specified
        if (filters.success !== undefined) {
            query.success = filters.success === 'true';
        }

        // Apply date range filter if specified
        if (filters.fromDate || filters.toDate) {
            query.timestamp = {};
            if (filters.fromDate) {
                query.timestamp.$gte = new Date(filters.fromDate);
            }
            if (filters.toDate) {
                query.timestamp.$lte = new Date(filters.toDate);
            }
        }

        // Find audit logs
        const auditLogs = await Audit.find(query)
            .sort(options.sort || { timestamp: -1 })
            .skip(skip)
            .limit(limit);

        // Count total audit logs matching the query
        const total = await Audit.countDocuments(query);

        return {
            auditLogs,
            pagination: {
                total,
                page,
                limit,
                totalPages: Math.ceil(total / limit)
            }
        };
    } catch (error) {
        logger.error('Error getting audit logs:', error);
        throw new ApiError('Failed to get audit logs', 500);
    }
};

module.exports = {
    createAuditLog,
    getAuditLogs
};
