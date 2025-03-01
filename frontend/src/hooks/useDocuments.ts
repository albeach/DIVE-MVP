// frontend/src/hooks/useDocuments.ts
import { useQuery } from '@tanstack/react-query';
import { fetchDocuments } from '@/services/documentService';
import { DocumentFilterParams } from '@/types/document';

export function useDocuments(filters: DocumentFilterParams) {
    return useQuery(
        ['documents', filters],
        () => fetchDocuments(filters),
        {
            keepPreviousData: true,
            staleTime: 5 * 60 * 1000, // 5 minutes
        }
    );
}