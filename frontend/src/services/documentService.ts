// frontend/src/services/documentService.ts
import apiClient, { fileClient, ApiErrorType, ApiError } from './apiClient';
import {
    Document,
    DocumentResponse,
    DocumentFilterParams,
    DocumentUploadData
} from '@/types/document';
import { createLogger } from '@/utils/logger';

// Create a logger instance for the document service
const logger = createLogger('DocumentService');

/**
 * Fetch documents with optional filtering and pagination
 */
export async function fetchDocuments(filters: DocumentFilterParams): Promise<DocumentResponse> {
    try {
        logger.debug('Fetching documents with filters:', filters);

        // Convert the filters object to query parameters
        const queryParams = new URLSearchParams();

        if (filters.classification) {
            queryParams.append('classification', filters.classification);
        }
        if (filters.country) {
            queryParams.append('country', filters.country);
        }
        if (filters.fromDate) {
            queryParams.append('fromDate', filters.fromDate);
        }
        if (filters.toDate) {
            queryParams.append('toDate', filters.toDate);
        }
        if (filters.search) {
            queryParams.append('search', filters.search);
        }
        if (filters.page) {
            queryParams.append('page', filters.page.toString());
        }
        if (filters.limit) {
            queryParams.append('limit', filters.limit.toString());
        }
        if (filters.sort) {
            queryParams.append('sort', JSON.stringify(filters.sort));
        }

        const response = await apiClient.get(`/api/v1/documents?${queryParams.toString()}`);
        logger.debug('Documents fetched successfully', response.data.pagination);
        return response.data;
    } catch (error: any) {
        logger.error('Error fetching documents', error);
        const apiError = error as ApiError;

        // Throw a more specific error based on the type
        if (apiError.type === ApiErrorType.FORBIDDEN) {
            throw new Error('You do not have permission to view these documents');
        }

        throw error;
    }
}

/**
 * Fetch a single document by ID
 */
export async function fetchDocumentById(id: string): Promise<Document> {
    try {
        logger.debug(`Fetching document with ID: ${id}`);
        const response = await apiClient.get(`/api/v1/documents/${id}`);
        logger.debug(`Document ${id} fetched successfully`);
        return response.data.document;
    } catch (error: any) {
        logger.error(`Error fetching document ${id}`, error);
        const apiError = error as ApiError;

        if (apiError.type === ApiErrorType.NOT_FOUND) {
            throw new Error(`Document with ID ${id} was not found`);
        } else if (apiError.type === ApiErrorType.FORBIDDEN) {
            throw new Error('You do not have permission to view this document');
        }

        throw error;
    }
}

/**
 * Upload a new document with metadata
 */
export async function uploadDocument(data: DocumentUploadData): Promise<Document> {
    try {
        logger.debug(`Uploading document: ${data.file.name} (${Math.round(data.file.size / 1024)}KB)`);
        const startTime = Date.now();

        // Create a FormData object to handle file upload
        const formData = new FormData();
        formData.append('file', data.file);

        // Add metadata as a JSON string
        formData.append('metadata', JSON.stringify({
            classification: data.classification,
            releasability: data.releasability,
            caveats: data.caveats,
            coi: data.coi,
            policyIdentifier: data.policyIdentifier || 'NATO'
        }));

        const response = await fileClient.post('/api/v1/documents', formData);

        const duration = Date.now() - startTime;
        logger.info(`Document upload successful, took ${duration}ms`, {
            documentId: response.data.document._id,
            fileSize: data.file.size,
            fileName: data.file.name,
            classification: data.classification
        });

        return response.data.document;
    } catch (error: any) {
        logger.error('Error uploading document', error);
        const apiError = error as ApiError;

        if (apiError.type === ApiErrorType.VALIDATION) {
            throw new Error(`Document validation failed: ${apiError.message}`);
        } else if (apiError.type === ApiErrorType.FORBIDDEN) {
            throw new Error('You do not have permission to upload documents');
        }

        throw error;
    }
}

/**
 * Delete a document by ID
 */
export async function deleteDocument(id: string): Promise<void> {
    try {
        logger.debug(`Deleting document with ID: ${id}`);
        await apiClient.delete(`/api/v1/documents/${id}`);
        logger.info(`Document ${id} deleted successfully`);
    } catch (error: any) {
        logger.error(`Error deleting document ${id}`, error);
        const apiError = error as ApiError;

        if (apiError.type === ApiErrorType.NOT_FOUND) {
            throw new Error(`Document with ID ${id} was not found`);
        } else if (apiError.type === ApiErrorType.FORBIDDEN) {
            throw new Error('You do not have permission to delete this document');
        }

        throw error;
    }
}

/**
 * Download a document by ID
 */
export async function downloadDocument(id: string): Promise<Blob> {
    try {
        logger.debug(`Downloading document with ID: ${id}`);
        const response = await fileClient.get(`/api/v1/documents/${id}/download`, {
            responseType: 'blob'
        });
        logger.debug(`Document ${id} downloaded successfully`);
        return response.data;
    } catch (error: any) {
        logger.error(`Error downloading document ${id}`, error);
        const apiError = error as ApiError;

        if (apiError.type === ApiErrorType.NOT_FOUND) {
            throw new Error(`Document with ID ${id} was not found`);
        } else if (apiError.type === ApiErrorType.FORBIDDEN) {
            throw new Error('You do not have permission to download this document');
        }

        throw error;
    }
}

/**
 * Preview a document by ID (usually returns a thumbnail or PDF preview)
 */
export async function previewDocument(id: string): Promise<Blob> {
    try {
        logger.debug(`Previewing document with ID: ${id}`);
        const response = await fileClient.get(`/api/v1/documents/${id}/preview`, {
            responseType: 'blob'
        });
        logger.debug(`Document ${id} preview generated successfully`);
        return response.data;
    } catch (error: any) {
        logger.error(`Error previewing document ${id}`, error);
        const apiError = error as ApiError;

        if (apiError.type === ApiErrorType.NOT_FOUND) {
            throw new Error(`Document with ID ${id} was not found`);
        } else if (apiError.type === ApiErrorType.FORBIDDEN) {
            throw new Error('You do not have permission to preview this document');
        }

        throw error;
    }
}