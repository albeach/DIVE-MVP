const { getAuditLogs } = require('../services/audit.service');
const logger = require('../utils/logger');

/**
 * Get audit logs with filtering and pagination
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Express next middleware function
 */
const getAll = async (req, res, next) => {
    try {
        // Check if user has admin role
        if (!req.user.roles.includes('admin')) {
            return res.status(403).json({
                success: false,
                message: 'You do not have permission to access audit logs'
            });
        }

        // Extract query parameters for filtering
        const filters = {
            userId: req.query.userId,
            username: req.query.username,
            action: req.query.action,
            resourceId: req.query.resourceId,
            resourceType: req.query.resourceType,
            success: req.query.success,
            fromDate: req.query.fromDate,
            toDate: req.query.toDate
        };

        // Extract query parameters for options
        const options = {
            page: req.query.page,
            limit: req.query.limit,
            sort: req.query.sort ? JSON.parse(req.query.sort) : undefined
        };

        const result = await getAuditLogs(filters, options);

        res.status(200).json({
            success: true,
            auditLogs: result.auditLogs,
            pagination: result.pagination
        });
    } catch (error) {
        logger.error('Audit logs retrieval error:', error);
        next(error);
    }
};

module.exports = {
    getAll
};
