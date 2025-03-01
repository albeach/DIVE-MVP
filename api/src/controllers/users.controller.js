const {
    getUserById,
    getUserByUniqueId,
    getUsers,
    createUser,
    updateUser,
    deleteUser
} = require('../services/users.service');
const logger = require('../utils/logger');

/**
 * Get user by ID
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Express next middleware function
 */
const getById = async (req, res, next) => {
    try {
        const user = await getUserById(req.params.id);

        res.status(200).json({
            success: true,
            user
        });
    } catch (error) {
        logger.error('User retrieval error:', error);
        next(error);
    }
};

/**
 * Get user by unique ID
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Express next middleware function
 */
const getByUniqueId = async (req, res, next) => {
    try {
        const user = await getUserByUniqueId(req.params.uniqueId);

        res.status(200).json({
            success: true,
            user
        });
    } catch (error) {
        logger.error('User retrieval error:', error);
        next(error);
    }
};

/**
 * Get users with filtering and pagination
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Express next middleware function
 */
const getAll = async (req, res, next) => {
    try {
        // Extract query parameters for filtering
        const filters = {
            organization: req.query.organization,
            countryOfAffiliation: req.query.countryOfAffiliation,
            clearance: req.query.clearance,
            active: req.query.active,
            search: req.query.search
        };

        // Extract query parameters for options
        const options = {
            page: req.query.page,
            limit: req.query.limit,
            sort: req.query.sort ? JSON.parse(req.query.sort) : undefined
        };

        const result = await getUsers(filters, options);

        res.status(200).json({
            success: true,
            users: result.users,
            pagination: result.pagination
        });
    } catch (error) {
        logger.error('Users retrieval error:', error);
        next(error);
    }
};

/**
 * Create a new user
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Express next middleware function
 */
const create = async (req, res, next) => {
    try {
        const user = await createUser(req.body, req.user);

        res.status(201).json({
            success: true,
            user
        });
    } catch (error) {
        logger.error('User creation error:', error);
        next(error);
    }
};

/**
 * Update user by ID
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Express next middleware function
 */
const update = async (req, res, next) => {
    try {
        const user = await updateUser(req.params.id, req.body, req.user);

        res.status(200).json({
            success: true,
            user
        });
    } catch (error) {
        logger.error('User update error:', error);
        next(error);
    }
};

/**
 * Delete user by ID
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Express next middleware function
 */
const remove = async (req, res, next) => {
    try {
        await deleteUser(req.params.id, req.user);

        res.status(200).json({
            success: true,
            message: 'User deleted successfully'
        });
    } catch (error) {
        logger.error('User deletion error:', error);
        next(error);
    }
};

module.exports = {
    getById,
    getByUniqueId,
    getAll,
    create,
    update,
    remove
};
