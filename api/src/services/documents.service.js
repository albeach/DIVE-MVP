const { Document, documentValidationSchema } = require('../models/document.model');
const { checkDocumentAccess } = require('./opa.service');
const { createAuditLog } = require('./audit.service');
const logger = require('../utils/logger');
const { ApiError } = require('../utils/error.utils');
const fs = require('fs').promises;
const path = require('path');
const { v4: uuidv4 } = require('uuid');
const config = require('../config');
const mongoose = require('mongoose');

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
 * @param {string} id - Document ID
 * @param {Object} user - User requesting the document
 * @returns {Promise<Object>} File data
 */
const getFile = async (id, user) => {
    try {
        // Get document metadata
        const document = await Document.findById(id);
        if (!document) {
            throw new ApiError('Document not found', 404);
        }

        // Check if user has access to the document
        const { allowed, explanation } = await checkDocumentAccess(user, document);

        if (!allowed) {
            // Create audit log for denied access
            await createAuditLog({
                userId: user.uniqueId,
                username: user.username,
                action: 'ACCESS_DENIED',
                resourceId: document._id,
                resourceType: 'document',
                details: {
                    operation: 'download',
                    filename: document.filename,
                    reason: explanation
                },
                success: false
            });

            throw new ApiError(`Access denied: ${explanation}`, 403);
        }

        // Get file data from storage
        const fileData = {
            // This is a placeholder. In a real system, we would retrieve the actual file
            content: Buffer.from('This is a test file content for document ' + id),
            filename: document.filename,
            contentType: document.mimeType || 'application/octet-stream'
        };

        // Create audit log
        await createAuditLog({
            userId: user.uniqueId,
            username: user.username,
            action: 'DOCUMENT_DOWNLOAD',
            resourceId: document._id,
            resourceType: 'document',
            details: {
                filename: document.filename,
                classification: document.metadata.classification
            },
            success: true
        });

        return fileData;
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
        // Parse metadata from documentData if it's a string
        const metadata = typeof documentData.metadata === 'string'
            ? JSON.parse(documentData.metadata)
            : documentData.metadata || {};

        // Combine the document data
        const completeDocumentData = {
            filename: file.originalname,
            metadata: {
                ...metadata,
                creator: {
                    id: user.uniqueId,
                    name: `${user.givenName} ${user.surname}`,
                    organization: user.organization,
                    country: user.countryOfAffiliation
                }
            }
        };

        // Validate document data
        const { error } = documentValidationSchema.validate(completeDocumentData);
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
                classification: metadata.classification || 'UNCLASSIFIED',
                releasability: metadata.releasability || [],
                caveats: metadata.caveats || [],
                coi: metadata.coi || [],
                policyIdentifier: metadata.policyIdentifier || 'NATO',
                creator: {
                    id: user.uniqueId,
                    name: `${user.givenName} ${user.surname}`,
                    organization: user.organization,
                    country: user.countryOfAffiliation
                }
            },
            uploadDate: new Date(),
            lastModifiedDate: new Date()
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
        const { allowed, explanation } = await checkDocumentAccess(user, document);

        if (!allowed) {
            // Create audit log for denied access
            await createAuditLog({
                userId: user.uniqueId,
                username: user.username,
                action: 'ACCESS_DENIED',
                resourceId: document._id,
                resourceType: 'document',
                details: {
                    filename: document.filename,
                    classification: document.metadata.classification,
                    reason: explanation
                },
                success: false
            });

            throw new ApiError(`Access denied: ${explanation}`, 403);
        }

        // Create audit log for sensitive documents
        if (document.metadata.classification !== 'UNCLASSIFIED') {
            await createAuditLog({
                userId: user.uniqueId,
                username: user.username,
                action: 'DOCUMENT_ACCESS',
                resourceId: document._id,
                resourceType: 'document',
                details: {
                    filename: document.filename,
                    classification: document.metadata.classification
                },
                success: true
            });
        }

        // Update last accessed date
        document.lastAccessedDate = new Date();
        await document.save();

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
const getDocuments = async (filters = {}, options = {}, user) => {
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

        // Apply search filter if specified
        if (filters.search) {
            query.$or = [
                { filename: { $regex: filters.search, $options: 'i' } },
                { 'metadata.classification': { $regex: filters.search, $options: 'i' } },
                { 'metadata.creator.name': { $regex: filters.search, $options: 'i' } },
                { 'metadata.creator.organization': { $regex: filters.search, $options: 'i' } }
            ];
        }

        // Add owner filter - users always see their own documents
        if (!user.roles || !user.roles.includes('admin')) {
            // Apply additional security pre-filters for non-admin users to improve performance
            // This pre-filters documents before performing individual access checks
            // These are just performance optimizations - final filtering happens via OPA

            // Only show documents with classification levels user has clearance for
            const clearanceLevels = {
                "UNCLASSIFIED": 0,
                "RESTRICTED": 10,
                "CONFIDENTIAL": 20,
                "SECRET": 30,
                "TOP SECRET": 40,
                "COSMIC TOP SECRET": 50
            };

            const userClearanceLevel = clearanceLevels[user.clearance] || 0;
            const allowedClassifications = Object.keys(clearanceLevels).filter(
                level => clearanceLevels[level] <= userClearanceLevel
            );

            // Add clearance pre-filter
            query['metadata.classification'] = { $in: allowedClassifications };

            // Add pre-filter for documents users own
            if (!query.$or) {
                query.$or = [];
            }
            query.$or.push({ 'metadata.creator.id': user.uniqueId });
        }

        logger.debug(`Document query: ${JSON.stringify(query)}`);
        logger.debug(`Pagination: page=${page}, limit=${limit}, skip=${skip}`);

        // Original query with Mongoose
        const documents = await Document.find(query)
            .sort(options.sort || { uploadDate: -1 })
            .skip(skip)
            .limit(limit);

        // Count total documents matching the query
        const total = await Document.countDocuments(query);
        logger.debug(`Total documents from database: ${total}`);

        // For all users, filter documents based on access rights (except admins who see everything)
        const accessibleDocuments = [];
        for (const document of documents) {
            const { allowed } = await checkDocumentAccess(user, document);
            if (allowed) {
                accessibleDocuments.push(document);
            }
        }

        // Create audit log for document listing
        await createAuditLog({
            userId: user.uniqueId,
            username: user.username,
            action: 'DOCUMENT_LIST',
            details: {
                filters: JSON.stringify(filters),
                resultCount: accessibleDocuments.length,
                totalCount: total
            },
            success: true
        });

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

        // Check if user has access to the document
        const { allowed, explanation } = await checkDocumentAccess(user, document);

        if (!allowed) {
            // Create audit log for denied access
            await createAuditLog({
                userId: user.uniqueId,
                username: user.username,
                action: 'ACCESS_DENIED',
                resourceId: document._id,
                resourceType: 'document',
                details: {
                    operation: 'update',
                    filename: document.filename,
                    reason: explanation
                },
                success: false
            });

            throw new ApiError(`Access denied: ${explanation}`, 403);
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
                    filename: document.filename,
                    reason: 'Not the document owner or admin'
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

        // Check if user has access to the document
        const { allowed, explanation } = await checkDocumentAccess(user, document);

        if (!allowed) {
            // Create audit log for denied access
            await createAuditLog({
                userId: user.uniqueId,
                username: user.username,
                action: 'ACCESS_DENIED',
                resourceId: document._id,
                resourceType: 'document',
                details: {
                    operation: 'delete',
                    filename: document.filename,
                    reason: explanation
                },
                success: false
            });

            throw new ApiError(`Access denied: ${explanation}`, 403);
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
                    filename: document.filename,
                    reason: 'Not the document owner or admin'
                },
                success: false
            });

            throw new ApiError('You do not have permission to delete this document', 403);
        }

        // Get file ID for deletion
        const fileId = document.fileId;

        // Delete document from database
        await Document.deleteOne({ _id: id });

        // Delete file from storage
        try {
            await deleteFile(fileId);
        } catch (fileError) {
            logger.error(`Failed to delete file ${fileId} for document ${id}:`, fileError);
            // We continue since the document was already deleted from the database
        }

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
