const {
    createDocument,
    getDocumentById,
    getDocuments,
    updateDocument,
    deleteDocument,
    getFile
} = require('../services/documents.service');
const { createAuditLog } = require('../services/audit.service');
const logger = require('../utils/logger');
const { ApiError } = require('../utils/error.utils');
const { performance } = require('perf_hooks');
const { documentValidationSchema } = require('../models/document.model');

/**
 * Validate document input
 * @param {Object} data - Document data to validate
 * @returns {Object} - Validation result
 */
const validateDocumentInput = (data) => {
    const { error, value } = documentValidationSchema.validate(data, {
        abortEarly: false,
        stripUnknown: true
    });

    if (error) {
        const details = error.details.map(detail => detail.message);
        throw new ApiError('Validation error', 400, 'VALIDATION_ERROR', details);
    }

    return value;
};

/**
 * Create a new document
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Express next middleware function
 */
const create = async (req, res, next) => {
    const startTime = performance.now();
    try {
        // Check if file was uploaded
        if (!req.file) {
            throw new ApiError('No file uploaded', 400, 'FILE_REQUIRED');
        }

        // Check file size
        const maxSize = 10 * 1024 * 1024; // 10MB
        if (req.file.size > maxSize) {
            throw new ApiError(`File size exceeds maximum limit (${maxSize / (1024 * 1024)}MB)`, 400, 'FILE_TOO_LARGE');
        }

        // Create document with file
        const document = await createDocument(req.body, req.file, req.user);

        // Create audit log
        await createAuditLog({
            userId: req.user.uniqueId,
            username: req.user.username,
            action: 'DOCUMENT_CREATE',
            resourceId: document._id,
            resourceType: 'document',
            details: {
                filename: document.filename,
                classification: document.metadata.classification
            },
            success: true
        });

        const duration = performance.now() - startTime;
        logger.debug(`Document creation completed in ${duration.toFixed(2)}ms`);

        res.status(201).json({
            success: true,
            document
        });
    } catch (error) {
        logger.error('Document creation error:', {
            error: error.message,
            user: req.user ? req.user.username : 'unknown',
            filename: req.file ? req.file.originalname : 'unknown'
        });
        next(error);
    }
};

/**
 * Get document by ID
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Express next middleware function
 */
const getById = async (req, res, next) => {
    try {
        if (!req.params.id) {
            throw new ApiError('Document ID is required', 400, 'ID_REQUIRED');
        }

        const document = await getDocumentById(req.params.id, req.user);

        // Create audit log for sensitive documents
        if (document.metadata.classification !== 'UNCLASSIFIED') {
            await createAuditLog({
                userId: req.user.uniqueId,
                username: req.user.username,
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

        res.status(200).json({
            success: true,
            document
        });
    } catch (error) {
        logger.error('Document retrieval error:', {
            error: error.message,
            documentId: req.params.id,
            user: req.user ? req.user.username : 'unknown'
        });
        next(error);
    }
};

/**
 * Get documents with filtering and pagination
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Express next middleware function
 */
const getAll = async (req, res, next) => {
    const startTime = performance.now();
    try {
        // Extract query parameters for filtering
        const filters = {
            classification: req.query.classification,
            country: req.query.country,
            fromDate: req.query.fromDate,
            toDate: req.query.toDate,
            searchTerm: req.query.search,
            coi: req.query.coi ? req.query.coi.split(',') : undefined,
            releasability: req.query.releasability ? req.query.releasability.split(',') : undefined
        };

        // Extract query parameters for options
        const options = {
            page: parseInt(req.query.page) || 1,
            limit: parseInt(req.query.limit) || 10,
            sort: req.query.sort ? JSON.parse(req.query.sort) : { uploadDate: -1 }
        };

        // Validate and sanitize options
        options.limit = Math.min(options.limit, 100); // Maximum 100 items per page
        options.page = Math.max(options.page, 1); // Minimum page 1

        const result = await getDocuments(filters, options, req.user);

        const duration = performance.now() - startTime;
        logger.debug(`Documents retrieval completed in ${duration.toFixed(2)}ms, returned ${result.documents.length} documents`);

        res.status(200).json({
            success: true,
            documents: result.documents,
            pagination: result.pagination
        });
    } catch (error) {
        logger.error('Documents retrieval error:', {
            error: error.message,
            filters: req.query,
            user: req.user ? req.user.username : 'unknown'
        });
        next(error);
    }
};

/**
 * Update document by ID
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Express next middleware function
 */
const update = async (req, res, next) => {
    try {
        if (!req.params.id) {
            throw new ApiError('Document ID is required', 400, 'ID_REQUIRED');
        }

        const document = await updateDocument(req.params.id, req.body, req.user);

        // Create audit log
        await createAuditLog({
            userId: req.user.uniqueId,
            username: req.user.username,
            action: 'DOCUMENT_UPDATE',
            resourceId: document._id,
            resourceType: 'document',
            details: {
                filename: document.filename,
                classification: document.metadata.classification,
                changes: Object.keys(req.body).join(', ')
            },
            success: true
        });

        res.status(200).json({
            success: true,
            document
        });
    } catch (error) {
        logger.error('Document update error:', {
            error: error.message,
            documentId: req.params.id,
            user: req.user ? req.user.username : 'unknown'
        });
        next(error);
    }
};

/**
 * Delete document by ID
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Express next middleware function
 */
const remove = async (req, res, next) => {
    try {
        if (!req.params.id) {
            throw new ApiError('Document ID is required', 400, 'ID_REQUIRED');
        }

        // Get document before deletion for audit log
        const document = await getDocumentById(req.params.id, req.user);

        await deleteDocument(req.params.id, req.user);

        // Create audit log
        await createAuditLog({
            userId: req.user.uniqueId,
            username: req.user.username,
            action: 'DOCUMENT_DELETE',
            resourceId: req.params.id,
            resourceType: 'document',
            details: {
                filename: document.filename,
                classification: document.metadata.classification
            },
            success: true
        });

        res.status(200).json({
            success: true,
            message: 'Document deleted successfully'
        });
    } catch (error) {
        logger.error('Document deletion error:', {
            error: error.message,
            documentId: req.params.id,
            user: req.user ? req.user.username : 'unknown'
        });
        next(error);
    }
};

/**
 * Download document file
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Express next middleware function
 */
const download = async (req, res, next) => {
    const startTime = performance.now();
    try {
        if (!req.params.id) {
            throw new ApiError('Document ID is required', 400, 'ID_REQUIRED');
        }

        // Get document
        const document = await getDocumentById(req.params.id, req.user);

        // Get file
        const fileBuffer = await getFile(document.fileId);

        // Set security headers
        res.setHeader('X-Content-Type-Options', 'nosniff');
        res.setHeader('Content-Security-Policy', "default-src 'none'");
        res.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate, proxy-revalidate');
        res.setHeader('Pragma', 'no-cache');
        res.setHeader('Expires', '0');

        // Set content headers
        res.setHeader('Content-Type', document.mimeType);
        res.setHeader('Content-Disposition', `attachment; filename="${encodeURIComponent(document.filename)}"`);
        res.setHeader('Content-Length', document.size);

        // Send file
        res.send(fileBuffer);

        const duration = performance.now() - startTime;
        logger.debug(`Document download completed in ${duration.toFixed(2)}ms, size: ${document.size} bytes`);

        // Create audit log
        await createAuditLog({
            userId: req.user.uniqueId,
            username: req.user.username,
            action: 'DOCUMENT_DOWNLOAD',
            resourceId: document._id,
            resourceType: 'document',
            details: {
                filename: document.filename,
                classification: document.metadata.classification,
                size: document.size
            },
            success: true
        });
    } catch (error) {
        logger.error('Document download error:', {
            error: error.message,
            documentId: req.params.id,
            user: req.user ? req.user.username : 'unknown'
        });
        next(error);
    }
};

/**
 * Preview document file
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Express next middleware function
 */
const preview = async (req, res, next) => {
    try {
        if (!req.params.id) {
            throw new ApiError('Document ID is required', 400, 'ID_REQUIRED');
        }

        // Get document
        const document = await getDocumentById(req.params.id, req.user);

        // Get file
        const fileBuffer = await getFile(document.fileId);

        // Set security headers
        res.setHeader('X-Content-Type-Options', 'nosniff');
        res.setHeader('Content-Security-Policy', "default-src 'none'; img-src 'self' data:; style-src 'self' 'unsafe-inline'; script-src 'none'");
        res.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate, proxy-revalidate');
        res.setHeader('Pragma', 'no-cache');
        res.setHeader('Expires', '0');

        // Set content headers
        res.setHeader('Content-Type', document.mimeType);
        res.setHeader('Content-Disposition', 'inline');
        res.setHeader('Content-Length', document.size);

        // Send file
        res.send(fileBuffer);

        // Update last accessed date
        document.lastAccessedDate = new Date();
        await document.save();

        // Create audit log for sensitive documents
        if (document.metadata.classification !== 'UNCLASSIFIED') {
            await createAuditLog({
                userId: req.user.uniqueId,
                username: req.user.username,
                action: 'DOCUMENT_PREVIEW',
                resourceId: document._id,
                resourceType: 'document',
                details: {
                    filename: document.filename,
                    classification: document.metadata.classification
                },
                success: true
            });
        }
    } catch (error) {
        logger.error('Document preview error:', {
            error: error.message,
            documentId: req.params.id,
            user: req.user ? req.user.username : 'unknown'
        });
        next(error);
    }
};

module.exports = {
    create,
    getById,
    getAll,
    update,
    remove,
    download,
    preview,
    validateDocumentInput
};
