import { useState, useCallback, useEffect } from 'react';
import {
    Document,
    DocumentFilterParams,
    DocumentResponse,
    PaginationInfo
} from '@/types/document';
import { fetchDocuments, deleteDocument } from '@/services/documentService';
import { useAuth } from '@/context/auth-context';
import { usePermissions } from './usePermissions';
import { createLogger } from '@/utils/logger';

const logger = createLogger('useDocumentList');

interface SortOptions {
    field: string;
    direction: 'asc' | 'desc';
}

/**
 * Hook for handling document list functionality including fetching, filtering, sorting, and pagination
 */
export function useDocumentList(initialFilters?: Partial<DocumentFilterParams>) {
    const [documents, setDocuments] = useState<Document[]>([]);
    const [filteredDocuments, setFilteredDocuments] = useState<Document[]>([]);
    const [pagination, setPagination] = useState<PaginationInfo>({
        total: 0,
        page: 1,
        limit: 10,
        totalPages: 0
    });
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState<Error | null>(null);
    const [filters, setFilters] = useState<DocumentFilterParams>({
        page: 1,
        limit: 10,
        ...initialFilters
    });
    const [sort, setSort] = useState<SortOptions>({ field: 'uploadDate', direction: 'desc' });

    const { isAuthenticated } = useAuth();
    const { getDocumentPermissions } = usePermissions();

    /**
     * Load documents from the API
     */
    const loadDocuments = useCallback(async (params?: DocumentFilterParams) => {
        if (!isAuthenticated) {
            logger.warn('Attempted to load documents while not authenticated');
            return;
        }

        setLoading(true);
        setError(null);

        try {
            const filterParams: DocumentFilterParams = {
                ...filters,
                ...params,
                sort: { [sort.field]: sort.direction === 'asc' ? 1 : -1 }
            };

            logger.debug('Loading documents with filters', filterParams);

            const response: DocumentResponse = await fetchDocuments(filterParams);

            setDocuments(response.documents);
            setPagination(response.pagination);

            // Apply additional client-side filtering (permissions)
            const filtered = response.documents.filter(doc => {
                const permissions = getDocumentPermissions(doc);
                return permissions.canView;
            });

            setFilteredDocuments(filtered);

            logger.debug(`Loaded ${response.documents.length} documents, ${filtered.length} viewable`);
        } catch (err) {
            logger.error('Failed to load documents', err);
            setError(err instanceof Error ? err : new Error('Failed to load documents'));
        } finally {
            setLoading(false);
        }
    }, [filters, sort, isAuthenticated, getDocumentPermissions]);

    /**
     * Apply new filters and reload documents
     */
    const applyFilters = useCallback((newFilters: Partial<DocumentFilterParams>) => {
        setFilters(prev => ({
            ...prev,
            ...newFilters,
            // Reset to page 1 when filters change
            page: (newFilters.search !== undefined && newFilters.search !== prev.search) ? 1 : prev.page
        }));
    }, []);

    /**
     * Change page
     */
    const changePage = useCallback((page: number) => {
        setFilters(prev => ({
            ...prev,
            page
        }));
    }, []);

    /**
     * Change sort order
     */
    const changeSort = useCallback((field: string, direction: 'asc' | 'desc') => {
        setSort({ field, direction });
    }, []);

    /**
     * Delete a document
     */
    const handleDeleteDocument = useCallback(async (documentId: string) => {
        try {
            logger.debug(`Deleting document ${documentId}`);
            await deleteDocument(documentId);

            // Remove the document from the list
            setDocuments(prev => prev.filter(doc => doc._id !== documentId));
            setFilteredDocuments(prev => prev.filter(doc => doc._id !== documentId));

            // Adjust pagination
            setPagination(prev => ({
                ...prev,
                total: prev.total - 1,
                totalItems: prev.totalItems ? prev.totalItems - 1 : undefined
            }));

            logger.info(`Document ${documentId} deleted successfully`);

            return true;
        } catch (err) {
            logger.error(`Failed to delete document ${documentId}`, err);
            setError(err instanceof Error ? err : new Error(`Failed to delete document ${documentId}`));
            return false;
        }
    }, []);

    /**
     * Reset all filters and sort to default
     */
    const resetFilters = useCallback(() => {
        setFilters({
            page: 1,
            limit: 10
        });
        setSort({ field: 'uploadDate', direction: 'desc' });
    }, []);

    /**
     * Reload documents when filters or sort changes
     */
    useEffect(() => {
        if (isAuthenticated) {
            loadDocuments();
        }
    }, [filters, sort, isAuthenticated, loadDocuments]);

    return {
        documents: filteredDocuments,
        allDocuments: documents,
        pagination,
        loading,
        error,
        filters,
        sort,
        applyFilters,
        changePage,
        changeSort,
        deleteDocument: handleDeleteDocument,
        resetFilters,
        refresh: loadDocuments
    };
} 