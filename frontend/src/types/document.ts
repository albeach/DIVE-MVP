// frontend/src/types/document.ts
/**
 * Document type definitions and interfaces for the DIVE25 system
 * This file contains all types related to document handling.
 */

import { User } from './user';

/**
 * Security classification levels
 */
export enum ClassificationLevel {
    UNCLASSIFIED = 'UNCLASSIFIED',
    RESTRICTED = 'RESTRICTED',
    CONFIDENTIAL = 'CONFIDENTIAL',
    NATO_CONFIDENTIAL = 'NATO CONFIDENTIAL',
    SECRET = 'SECRET',
    NATO_SECRET = 'NATO SECRET',
    TOP_SECRET = 'TOP SECRET',
    COSMIC_TOP_SECRET = 'COSMIC TOP SECRET'
}

/**
 * Document metadata including security markings and creator information
 */
export interface DocumentMetadata {
    /** Security classification level */
    classification: ClassificationLevel | string;

    /** Countries or organizations that the document can be released to */
    releasability?: string[];

    /** Special handling caveats */
    caveats?: string[];

    /** Communities of Interest */
    coi?: string[];

    /** Security policy identifier (e.g., 'NATO') */
    policyIdentifier?: string;

    /** Document creator information */
    creator: {
        /** Unique identifier of the creator */
        id: string;

        /** Full name of the creator */
        name: string;

        /** Creator's organization */
        organization: string;

        /** Creator's country of affiliation */
        country: string;
    };
}

/**
 * Document entity representing a file in the system with its metadata
 */
export interface Document {
    /** Unique identifier for the document */
    _id: string;

    /** Original filename */
    filename: string;

    /** System-generated file ID for storage reference */
    fileId: string;

    /** MIME type of the document */
    mimeType: string;

    /** File size in bytes */
    size: number;

    /** Document metadata including security markings */
    metadata: DocumentMetadata;

    /** Timestamp when the document was uploaded */
    uploadDate: string;

    /** Timestamp when the document was last viewed */
    lastAccessedDate?: string;

    /** Timestamp when the document was last modified */
    lastModifiedDate?: string;
}

/**
 * Pagination information for document lists
 */
export interface PaginationInfo {
    /** Total number of documents matching the filter criteria */
    total: number;

    /** Current page number (1-based) */
    page: number;

    /** Number of documents per page */
    limit: number;

    /** Total number of pages */
    totalPages: number;

    /** Total number of items (may differ from total in some cases) */
    totalItems?: number;
}

/**
 * Response structure for document list API calls
 */
export interface DocumentResponse {
    /** API call success status */
    success: boolean;

    /** Array of document objects */
    documents: Document[];

    /** Pagination information */
    pagination: PaginationInfo;
}

/**
 * Filter parameters for document search and listing
 */
export interface DocumentFilterParams {
    /** Filter by security classification */
    classification?: string;

    /** Filter by country */
    country?: string;

    /** Filter by upload date range - start */
    fromDate?: string;

    /** Filter by upload date range - end */
    toDate?: string;

    /** Text search query */
    search?: string;

    /** Page number for pagination (1-based) */
    page?: number;

    /** Number of documents per page */
    limit?: number;

    /** Sorting criteria with field names and directions (1 for ascending, -1 for descending) */
    sort?: Record<string, number>;
}

/**
 * Data structure for document upload requests
 */
export interface DocumentUploadData {
    /** File to upload */
    file: File;

    /** Security classification */
    classification: string;

    /** Countries or organizations the document can be released to */
    releasability?: string[];

    /** Special handling caveats */
    caveats?: string[];

    /** Communities of Interest */
    coi?: string[];

    /** Security policy identifier */
    policyIdentifier?: string;
}

/**
 * Document upload progress state
 */
export interface DocumentUploadProgress {
    /** Current upload status */
    status: 'idle' | 'uploading' | 'success' | 'error';

    /** Upload progress percentage (0-100) */
    percentage: number;

    /** Error message in case of failure */
    error?: string;

    /** Uploaded document ID when successful */
    documentId?: string;
}

/**
 * Document access permissions
 */
export interface DocumentPermissions {
    /** Whether the user can view the document */
    canView: boolean;

    /** Whether the user can download the document */
    canDownload: boolean;

    /** Whether the user can edit the document metadata */
    canEdit: boolean;

    /** Whether the user can delete the document */
    canDelete: boolean;

    /** Whether the user can share the document */
    canShare: boolean;
}