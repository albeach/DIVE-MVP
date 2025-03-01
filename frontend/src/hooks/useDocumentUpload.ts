// frontend/src/hooks/useDocumentUpload.ts
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { uploadDocument } from '@/services/documentService';
import { DocumentUploadData } from '@/types/document';

export function useDocumentUpload() {
    const queryClient = useQueryClient();

    const mutation = useMutation(
        (data: DocumentUploadData) => uploadDocument(data),
        {
            onSuccess: () => {
                // Invalidate and refetch documents queries
                queryClient.invalidateQueries(['documents']);
            },
        }
    );

    return {
        uploadDocument: mutation.mutateAsync,
        isUploading: mutation.isLoading,
        error: mutation.error,
    };
}