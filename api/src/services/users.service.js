const { User, userValidationSchema } = require('../models/user.model');
const { createAuditLog } = require('./audit.service');
const logger = require('../utils/logger');
const { ApiError } = require('../utils/error.utils');
const mongoose = require('mongoose');
const fs = require('fs');
const path = require('path');
const { v4: uuidv4 } = require('uuid');

/**
 * Get user by ID
 * @param {string} id - User ID
 * @returns {Promise<Object>} User
 */
const getUserById = async (id) => {
    try {
        const user = await User.findById(id);
        if (!user) {
            throw new ApiError('User not found', 404);
        }
        return user;
    } catch (error) {
        logger.error('Error getting user by ID:', error);
        if (error instanceof ApiError) {
            throw error;
        }
        throw new ApiError('Failed to get user', 500);
    }
};

/**
 * Get user by unique ID
 * @param {string} uniqueId - Unique ID
 * @returns {Promise<Object>} User
 */
const getUserByUniqueId = async (uniqueId) => {
    try {
        const user = await User.findOne({ uniqueId });
        if (!user) {
            throw new ApiError('User not found', 404);
        }
        return user;
    } catch (error) {
        logger.error('Error getting user by unique ID:', error);
        if (error instanceof ApiError) {
            throw error;
        }
        throw new ApiError('Failed to get user', 500);
    }
};

/**
 * Get users with pagination and filtering
 * @param {Object} filters - Query filters
 * @param {Object} options - Query options (sort, pagination)
 * @returns {Promise<Object>} Users and pagination info
 */
const getUsers = async (filters = {}, options = {}) => {
    try {
        const page = parseInt(options.page) || 1;
        const limit = parseInt(options.limit) || 10;
        const skip = (page - 1) * limit;

        // Build query based on filters
        const query = {};

        // Apply organization filter if specified
        if (filters.organization) {
            query.organization = filters.organization;
        }

        // Apply country filter if specified
        if (filters.countryOfAffiliation) {
            query.countryOfAffiliation = filters.countryOfAffiliation;
        }

        // Apply clearance filter if specified
        if (filters.clearance) {
            query.clearance = filters.clearance;
        }

        // Apply active filter if specified
        if (filters.active !== undefined) {
            query.active = filters.active === 'true';
        }

        // Apply search filter if specified
        if (filters.search) {
            query.$or = [
                { username: { $regex: filters.search, $options: 'i' } },
                { email: { $regex: filters.search, $options: 'i' } },
                { givenName: { $regex: filters.search, $options: 'i' } },
                { surname: { $regex: filters.search, $options: 'i' } }
            ];
        }

        // Find users
        const users = await User.find(query)
            .sort(options.sort || { username: 1 })
            .skip(skip)
            .limit(limit);

        // Count total users matching the query
        const total = await User.countDocuments(query);

        return {
            users,
            pagination: {
                total,
                page,
                limit,
                totalPages: Math.ceil(total / limit)
            }
        };
    } catch (error) {
        logger.error('Error getting users:', error);
        throw new ApiError('Failed to get users', 500);
    }
};

/**
 * Create a new user
 * @param {Object} userData - User data
 * @param {Object} createdBy - User creating the user
 * @returns {Promise<Object>} Created user
 */
const createUser = async (userData, createdBy) => {
    try {
        // Validate user data
        const { error, value } = userValidationSchema.validate(userData);
        if (error) {
            throw new ApiError(`Invalid user data: ${error.message}`, 400);
        }

        // Check if user already exists
        const existingUser = await User.findOne({
            $or: [
                { uniqueId: value.uniqueId },
                { username: value.username },
                { email: value.email }
            ]
        });

        if (existingUser) {
            throw new ApiError('User already exists', 409);
        }

        // Create new user
        const user = new User(value);

        // Save user
        await user.save();

        // Create audit log
        await createAuditLog({
            userId: createdBy.uniqueId,
            username: createdBy.username,
            action: 'USER_CREATE',
            resourceId: user._id,
            resourceType: 'user',
            details: {
                username: user.username,
                email: user.email
            },
            success: true
        });

        return user;
    } catch (error) {
        logger.error('Error creating user:', error);
        if (error instanceof ApiError) {
            throw error;
        }
        throw new ApiError('Failed to create user', 500);
    }
};

/**
 * Update user by ID
 * @param {string} id - User ID
 * @param {Object} updateData - Update data
 * @param {Object} updatedBy - User updating the user
 * @returns {Promise<Object>} Updated user
 */
const updateUser = async (id, updateData, updatedBy) => {
    try {
        // Find user
        const user = await User.findById(id);
        if (!user) {
            throw new ApiError('User not found', 404);
        }

        // Check if updater has admin role or is updating their own profile
        if (user._id.toString() !== updatedBy._id.toString() && !updatedBy.roles.includes('admin')) {
            throw new ApiError('You do not have permission to update this user', 403);
        }

        // Validate update data
        if (updateData.email || updateData.username || updateData.uniqueId) {
            const { error } = userValidationSchema.validate({
                ...user.toObject(),
                ...updateData
            });

            if (error) {
                throw new ApiError(`Invalid update data: ${error.message}`, 400);
            }

            // Check if email or username is already taken
            if (updateData.email || updateData.username) {
                const query = { _id: { $ne: user._id }, $or: [] };
                if (updateData.email) query.$or.push({ email: updateData.email });
                if (updateData.username) query.$or.push({ username: updateData.username });

                if (query.$or.length > 0) {
                    const existingUser = await User.findOne(query);
                    if (existingUser) {
                        throw new ApiError('Email or username already taken', 409);
                    }
                }
            }
        }

        // Apply updates
        if (updateData.email) user.email = updateData.email;
        if (updateData.givenName) user.givenName = updateData.givenName;
        if (updateData.surname) user.surname = updateData.surname;
        if (updateData.organization) user.organization = updateData.organization;
        if (updateData.countryOfAffiliation) user.countryOfAffiliation = updateData.countryOfAffiliation;
        if (updateData.clearance) user.clearance = updateData.clearance;
        if (updateData.caveats) user.caveats = updateData.caveats;
        if (updateData.coi) user.coi = updateData.coi;

        // Admin-only updates
        if (updatedBy.roles.includes('admin')) {
            if (updateData.roles) user.roles = updateData.roles;
            if (updateData.active !== undefined) user.active = updateData.active;
        }

        // Save updated user
        await user.save();

        // Create audit log
        await createAuditLog({
            userId: updatedBy.uniqueId,
            username: updatedBy.username,
            action: 'USER_UPDATE',
            resourceId: user._id,
            resourceType: 'user',
            details: {
                username: user.username,
                fields: Object.keys(updateData)
            },
            success: true
        });

        return user;
    } catch (error) {
        logger.error('Error updating user:', error);
        if (error instanceof ApiError) {
            throw error;
        }
        throw new ApiError('Failed to update user', 500);
    }
};

/**
 * Delete user by ID
 * @param {string} id - User ID
 * @param {Object} deletedBy - User deleting the user
 * @returns {Promise<boolean>} Success status
 */
const deleteUser = async (id, deletedBy) => {
    try {
        // Find user
        const user = await User.findById(id);
        if (!user) {
            throw new ApiError('User not found', 404);
        }

        // Check if deleter has admin role
        if (!deletedBy.roles.includes('admin')) {
            throw new ApiError('You do not have permission to delete users', 403);
        }

        // Delete user
        await User.deleteOne({ _id: id });

        // Create audit log
        await createAuditLog({
            userId: deletedBy.uniqueId,
            username: deletedBy.username,
            action: 'USER_DELETE',
            resourceId: user._id,
            resourceType: 'user',
            details: {
                username: user.username,
                email: user.email
            },
            success: true
        });

        return true;
    } catch (error) {
        logger.error('Error deleting user:', error);
        if (error instanceof ApiError) {
            throw error;
        }
        throw new ApiError('Failed to delete user', 500);
    }
};

/**
 * Upload an avatar image for a user
 * @param {Object} user - Current user object
 * @param {Object} file - Upload file from multer
 * @returns {Object} Result object with avatar URL
 */
const uploadUserAvatar = async (user, file) => {
    try {
        // Create uploads directory if it doesn't exist
        const uploadsDir = path.join(__dirname, '../../uploads/avatars');
        if (!fs.existsSync(uploadsDir)) {
            fs.mkdirSync(uploadsDir, { recursive: true });
        }

        // Generate unique filename
        const fileExtension = file.mimetype.split('/')[1];
        const fileName = `${uuidv4()}.${fileExtension}`;
        const filePath = path.join(uploadsDir, fileName);

        // Write file to disk
        fs.writeFileSync(filePath, file.buffer);

        // Update user record with avatar path
        const avatarUrl = `/api/uploads/avatars/${fileName}`;
        await User.findByIdAndUpdate(user.id, { avatar: avatarUrl });

        return { avatarUrl };
    } catch (error) {
        logger.error('Error uploading avatar:', error);
        throw new ApiError('Failed to upload avatar', 500, 'AVATAR_UPLOAD_FAILED');
    }
};

module.exports = {
    getUserById,
    getUserByUniqueId,
    getUsers,
    createUser,
    updateUser,
    deleteUser,
    uploadUserAvatar
};
