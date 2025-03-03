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

/**
 * Create a new document
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Express next middleware function
 */
const create = async (req, res, next) => {
    try {
        // Check if file was uploaded
        if (!req.file) {
            throw new ApiError('No file uploaded', 400);
        }

        // Create document with file
        const document = await createDocument(req.body, req.file, req.user);

        res.status(201).json({
            success: true,
            document
        });
    } catch (error) {
        logger.error('Document creation error:', error);
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
        const document = await getDocumentById(req.params.id, req.user);

        res.status(200).json({
            success: true,
            document
        });
    } catch (error) {
        logger.error('Document retrieval error:', error);
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
    try {
        // Extract query parameters for filtering
        const filters = {
            classification: req.query.classification,
            country: req.query.country,
            fromDate: req.query.fromDate,
            toDate: req.query.toDate
        };

        // Extract query parameters for options
        const options = {
            page: req.query.page,
            limit: req.query.limit,
            sort: req.query.sort ? JSON.parse(req.query.sort) : undefined
        };

        const result = await getDocuments(filters, options, req.user);

        res.status(200).json({
            success: true,
            documents: result.documents,
            pagination: result.pagination
        });
    } catch (error) {
        logger.error('Documents retrieval error:', error);
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
        const document = await updateDocument(req.params.id, req.body, req.user);

        res.status(200).json({
            success: true,
            document
        });
    } catch (error) {
        logger.error('Document update error:', error);
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
        await deleteDocument(req.params.id, req.user);

        res.status(200).json({
            success: true,
            message: 'Document deleted successfully'
        });
    } catch (error) {
        logger.error('Document deletion error:', error);
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
    try {
        // Get document
        const document = await getDocumentById(req.params.id, req.user);

        // Get file
        const fileBuffer = await getFile(document.fileId);

        // Set headers
        res.setHeader('Content-Type', document.mimeType);
        res.setHeader('Content-Disposition', `attachment; filename="${document.filename}"`);
        res.setHeader('Content-Length', document.size);

        // Send file
        res.send(fileBuffer);

        // Create audit log
        await createAuditLog({
            userId: req.user.uniqueId,
            username: req.user.username,
            action: 'DOCUMENT_DOWNLOAD',
            resourceId: document._id,
            resourceType: 'document',
            details: {
                filename: document.filename,
                classification: document.metadata.classification
            },
            success: true
        });
    } catch (error) {
        logger.error('Document download error:', error);
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
        // Get document
        const document = await getDocumentById(req.params.id, req.user);

        // Get file
        const fileBuffer = await getFile(document.fileId);

        // Set headers
        res.setHeader('Content-Type', document.mimeType);
        res.setHeader('Content-Disposition', 'inline');
        res.setHeader('Content-Length', document.size);

        // Send file
        res.send(fileBuffer);

        // Update last accessed date
        document.lastAccessedDate = new Date();
        await document.save();
    } catch (error) {
        logger.error('Document preview error:', error);
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
    preview
};
