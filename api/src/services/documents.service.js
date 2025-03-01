const { Document, documentValidationSchema } = require('../models/document.model');
const { evaluateAccessPolicy } = require('./opa.service');
const { createAuditLog } = require('./audit.service');
const logger = require('../utils/logger');
const { ApiError } = require('../utils/error.utils');
const fs = require('fs').promises;
const path = require('path');
const { v4: uuidv4 } = require('uuid');
const config = require('../config');

/**
 * Upload file to storage
 * @param {Object} file - File object from multer
 * @returns {Promise<Object>} File info
 */
const storeFile = async (file) => {
    try {
        // Generate unique file ID
        const fileId = uuidv4();

        // Create storage directory if it doesn't exist
        const storageDir = path.join(config.storage.basePath, fileId.substring(0, 2));
        await fs.mkdir(storageDir, { recursive: true });

        // Store file
        const filePath = path.join(storageDir, fileId);
        await fs.writeFile(filePath, file.buffer);

        return {
            fileId,
            filename: file.originalname,
            mimeType: file.mimetype,
            size: file.size
        };
    } catch (error) {
        logger.error('Error storing file:', error);
        throw new ApiError('Failed to store file', 500);
    }
};

/**
 * Get file from storage
 * @param {string} fileId - File ID
 * @returns {Promise<Buffer>} File buffer
 */
const getFile = async (fileId) => {
    try {
        // Validate file ID format
        if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.test(fileId)) {
            throw new ApiError('Invalid file ID', 400);
        }

        // Get file path
        const filePath = path.join(config.storage.basePath, fileId.substring(0, 2), fileId);

        // Check if file exists
        try {
            await fs.access(filePath);
        } catch (error) {
            throw new ApiError('File not found', 404);
        }

        // Read file
        return await fs.readFile(filePath);
    } catch (error) {
        logger.error('Error getting file:', error);
        if (error instanceof ApiError) {
            throw error;
        }
        throw new ApiError('Failed to get file', 500);
    }
};

/**
 * Delete file from storage
 * @param {string} fileId - File ID
 * @returns {Promise<boolean>} Success status
 */
const deleteFile = async (fileId) => {
    try {
        // Validate file ID format
        if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.test(fileId)) {
            throw new ApiError('Invalid file ID', 400);
        }

        // Get file path
        const filePath = path.join(config.storage.basePath, fileId.substring(0, 2), fileId);

        // Check if file exists
        try {
            await fs.access(filePath);
        } catch (error) {
            throw new ApiError('File not found', 404);
        }

        // Delete file
        await fs.unlink(filePath);

        return true;
    } catch (error) {
        logger.error('Error deleting file:', error);
        if (error instanceof ApiError) {
            throw error;
        }
        throw new ApiError('Failed to delete file', 500);
    }
};

/**
 * Create a new document
 * @param {Object} documentData - Document data
 * @param {Object} file - File object from multer
 * @param {Object} user - User creating the document
 * @returns {Promise<Object>} Created document
 */
const createDocument = async (documentData, file, user) => {
    try {
        // Validate document data
        const { error, value } = documentValidationSchema.validate(documentData);
        if (error) {
            throw new ApiError(`Invalid document data: ${error.message}`, 400);
        }

        // Store file
        const fileInfo = await storeFile(file);

        // Create new document
        const document = new Document({
            filename: fileInfo.filename,
            fileId: fileInfo.fileId,
            mimeType: fileInfo.mimeType,
            size: fileInfo.size,
            metadata: {
                ...value.metadata,
                creator: {
                    id: user.uniqueId,
                    name: `${user.givenName} ${user.surname}`,
                    organization: user.organization,
                    country: user.countryOfAffiliation
                }
            }
        });

        // Save document
        await document.save();

        // Create audit log
        await createAuditLog({
            userId: user.uniqueId,
            username: user.username,
            action: 'DOCUMENT_CREATE',
            resourceId: document._id,
            resourceType: 'document',
            details: {
                filename: document.filename,
                classification: document.metadata.classification
            },
            success: true
        });

        return document;
    } catch (error) {
        logger.error('Error creating document:', error);
        if (error instanceof ApiError) {
            throw error;
        }
        throw new ApiError('Failed to create document', 500);
    }
};

/**
 * Get document by ID with access control
 * @param {string} id - Document ID
 * @param {Object} user - User requesting the document
 * @returns {Promise<Object>} Document
 */
const getDocumentById = async (id, user) => {
    try {
        // Find document
        const document = await Document.findById(id);
        if (!document) {
            throw new ApiError('Document not found', 404);
        }

        // Check if user has access to the document
        const accessAllowed = await evaluateAccessPolicy({
            user: {
                clearance: user.clearance,
                countryOfAffiliation: user.countryOfAffiliation,
                caveats: user.caveats,
                coi: user.coi
            },
            resource: {
                classification: document.metadata.classification,
                releasability: document.metadata.releasability,
                caveats: document.metadata.caveats,
                coi: document.metadata.coi
            }
        });

        if (!accessAllowed) {
            // Create audit log for denied access
            await createAuditLog({
                userId: user.uniqueId,
                username: user.username,
                action: 'ACCESS_DENIED',
                resourceId: document._id,
                resourceType: 'document',
                details: {
                    filename: document.filename,
                    classification: document.metadata.classification
                },
                success: false
            });

            throw new ApiError('Access denied', 403);
        }

        // Update last accessed date
        document.lastAccessedDate = new Date();
        await document.save();

        // Create audit log
        await createAuditLog({
            userId: user.uniqueId,
            username: user.username,
            action: 'DOCUMENT_VIEW',
            resourceId: document._id,
            resourceType: 'document',
            details: {
                filename: document.filename,
                classification: document.metadata.classification
            },
            success: true
        });

        return document;
    } catch (error) {
        logger.error('Error getting document:', error);
        if (error instanceof ApiError) {
            throw error;
        }
        throw new ApiError('Failed to get document', 500);
    }
};

/**
 * Get documents with pagination and filtering
 * @param {Object} filters - Query filters
 * @param {Object} options - Query options (sort, pagination)
 * @param {Object} user - User requesting the documents
 * @returns {Promise<Object>} Documents and pagination info
 */
const getDocuments = async (filters, options, user) => {
    try {
        const page = parseInt(options.page) || 1;
        const limit = parseInt(options.limit) || 10;
        const skip = (page - 1) * limit;

        // Build query based on filters
        const query = {};

        // Apply classification filter if specified
        if (filters.classification) {
            query['metadata.classification'] = filters.classification;
        }

        // Apply country filter if specified
        if (filters.country) {
            query['metadata.creator.country'] = filters.country;
        }

        // Apply date filters if specified
        if (filters.fromDate || filters.toDate) {
            query.uploadDate = {};
            if (filters.fromDate) {
                query.uploadDate.$gte = new Date(filters.fromDate);
            }
            if (filters.toDate) {
                query.uploadDate.$lte = new Date(filters.toDate);
            }
        }

        // Find documents
        const documents = await Document.find(query)
            .sort(options.sort || { uploadDate: -1 })
            .skip(skip)
            .limit(limit);

        // Count total documents matching the query
        const total = await Document.countDocuments(query);

        // Filter documents based on user's access rights
        const accessibleDocuments = [];

        for (const document of documents) {
            // Check if user has access to the document
            const accessAllowed = await evaluateAccessPolicy({
                user: {
                    clearance: user.clearance,
                    countryOfAffiliation: user.countryOfAffiliation,
                    caveats: user.caveats,
                    coi: user.coi
                },
                resource: {
                    classification: document.metadata.classification,
                    releasability: document.metadata.releasability,
                    caveats: document.metadata.caveats,
                    coi: document.metadata.coi
                }
            });

            if (accessAllowed) {
                accessibleDocuments.push(document);
            }
        }

        return {
            documents: accessibleDocuments,
            pagination: {
                total,
                page,
                limit,
                totalPages: Math.ceil(total / limit)
            }
        };
    } catch (error) {
        logger.error('Error getting documents:', error);
        throw new ApiError('Failed to get documents', 500);
    }
};

/**
 * Update document by ID
 * @param {string} id - Document ID
 * @param {Object} updateData - Update data
 * @param {Object} user - User updating the document
 * @returns {Promise<Object>} Updated document
 */
const updateDocument = async (id, updateData, user) => {
    try {
        // Find document
        const document = await Document.findById(id);
        if (!document) {
            throw new ApiError('Document not found', 404);
        }

        // Check if user is the creator or has admin role
        if (document.metadata.creator.id !== user.uniqueId && !user.roles.includes('admin')) {
            // Create audit log for denied access
            await createAuditLog({
                userId: user.uniqueId,
                username: user.username,
                action: 'ACCESS_DENIED',
                resourceId: document._id,
                resourceType: 'document',
                details: {
                    operation: 'update',
                    filename: document.filename
                },
                success: false
            });

            throw new ApiError('You do not have permission to update this document', 403);
        }

        // Validate update data
        if (updateData.metadata) {
            const { error } = documentValidationSchema.validate({
                ...document.toObject(),
                ...updateData
            });

            if (error) {
                throw new ApiError(`Invalid update data: ${error.message}`, 400);
            }
        }

        // Apply updates
        if (updateData.filename) document.filename = updateData.filename;
        if (updateData.mimeType) document.mimeType = updateData.mimeType;
        if (updateData.metadata) {
            if (updateData.metadata.classification) {
                document.metadata.classification = updateData.metadata.classification;
            }
            if (updateData.metadata.releasability) {
                document.metadata.releasability = updateData.metadata.releasability;
            }
            if (updateData.metadata.caveats) {
                document.metadata.caveats = updateData.metadata.caveats;
            }
            if (updateData.metadata.coi) {
                document.metadata.coi = updateData.metadata.coi;
            }
            if (updateData.metadata.policyIdentifier) {
                document.metadata.policyIdentifier = updateData.metadata.policyIdentifier;
            }
        }

        // Update modification date
        document.lastModifiedDate = new Date();

        // Save updated document
        await document.save();

        // Create audit log
        await createAuditLog({
            userId: user.uniqueId,
            username: user.username,
            action: 'DOCUMENT_UPDATE',
            resourceId: document._id,
            resourceType: 'document',
            details: {
                filename: document.filename,
                fields: Object.keys(updateData)
            },
            success: true
        });

        return document;
    } catch (error) {
        logger.error('Error updating document:', error);
        if (error instanceof ApiError) {
            throw error;
        }
        throw new ApiError('Failed to update document', 500);
    }
};

/**
 * Delete document by ID
 * @param {string} id - Document ID
 * @param {Object} user - User deleting the document
 * @returns {Promise<boolean>} Success status
 */
const deleteDocument = async (id, user) => {
    try {
        // Find document
        const document = await Document.findById(id);
        if (!document) {
            throw new ApiError('Document not found', 404);
        }

        // Check if user is the creator or has admin role
        if (document.metadata.creator.id !== user.uniqueId && !user.roles.includes('admin')) {
            // Create audit log for denied access
            await createAuditLog({
                userId: user.uniqueId,
                username: user.username,
                action: 'ACCESS_DENIED',
                resourceId: document._id,
                resourceType: 'document',
                details: {
                    operation: 'delete',
                    filename: document.filename
                },
                success: false
            });

            throw new ApiError('You do not have permission to delete this document', 403);
        }

        // Delete document
        await Document.deleteOne({ _id: id });

        // Create audit log
        await createAuditLog({
            userId: user.uniqueId,
            username: user.username,
            action: 'DOCUMENT_DELETE',
            resourceId: document._id,
            resourceType: 'document',
            details: {
                filename: document.filename,
                classification: document.metadata.classification
            },
            success: true
        });

        return true;
    } catch (error) {
        logger.error('Error deleting document:', error);
        if (error instanceof ApiError) {
            throw error;
        }
        throw new ApiError('Failed to delete document', 500);
    }
};

module.exports = {
    createDocument,
    getDocumentById,
    getDocuments,
    updateDocument,
    deleteDocument,
    storeFile,
    getFile,
    deleteFile
};
