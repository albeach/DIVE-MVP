// frontend/src/hooks/useDocument.ts
import { useQuery } from '@tanstack/react-query';
import { fetchDocumentById } from '@/services/documentService';

export function useDocument(id: string) {
    return useQuery(
        ['document', id],
        () => fetchDocumentById(id),
        {
            enabled: !!id,
            staleTime: 5 * 60 * 1000, // 5 minutes
        }
    );
}