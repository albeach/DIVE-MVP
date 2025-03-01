// frontend/src/services/documentService.ts
import { apiClient } from './apiClient';
import {
    Document,
    DocumentResponse,
    DocumentFilterParams,
    DocumentUploadData
} from '@/types/document';

export async function fetchDocuments(filters: DocumentFilterParams): Promise<DocumentResponse> {
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

    const response = await apiClient.get(`/documents?${queryParams.toString()}`);
    return response.data;
}

export async function fetchDocumentById(id: string): Promise<Document> {
    const response = await apiClient.get(`/documents/${id}`);
    return response.data.document;
}

export async function uploadDocument(data: DocumentUploadData): Promise<Document> {
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

    const response = await apiClient.post('/documents', formData, {
        headers: {
            'Content-Type': 'multipart/form-data',
        },
    });

    return response.data.document;
}

export async function deleteDocument(id: string): Promise<void> {
    await apiClient.delete(`/documents/${id}`);
}