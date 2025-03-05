// frontend/src/types/document.ts
export interface DocumentMetadata {
    classification: string;
    releasability?: string[];
    caveats?: string[];
    coi?: string[];
    policyIdentifier?: string;
    creator: {
        id: string;
        name: string;
        organization: string;
        country: string;
    };
}

export interface Document {
    _id: string;
    filename: string;
    fileId: string;
    mimeType: string;
    size: number;
    metadata: DocumentMetadata;
    uploadDate: string;
    lastAccessedDate?: string;
    lastModifiedDate?: string;
}

export interface PaginationInfo {
    total: number;
    page: number;
    limit: number;
    totalPages: number;
    totalItems?: number;
}

export interface DocumentResponse {
    success: boolean;
    documents: Document[];
    pagination: PaginationInfo;
}

export interface DocumentFilterParams {
    classification?: string;
    country?: string;
    fromDate?: string;
    toDate?: string;
    search?: string;
    page?: number;
    limit?: number;
    sort?: Record<string, number>;
}

export interface DocumentUploadData {
    file: File;
    classification: string;
    releasability?: string[];
    caveats?: string[];
    coi?: string[];
    policyIdentifier?: string;
}