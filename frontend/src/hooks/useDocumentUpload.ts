// frontend/src/hooks/useDocumentUpload.ts
import { useState, useCallback } from 'react';
import { DocumentUploadData, DocumentUploadProgress } from '@/types/document';
import { uploadDocument } from '@/services/documentService';
import { createLogger } from '@/utils/logger';
import { useAuth } from '@/context/auth-context';
import { DOCUMENT_CONFIG } from '@/lib/config';
import { ApiError, ApiErrorType } from '@/services/apiClient';

const logger = createLogger('useDocumentUpload');

interface UseDocumentUploadOptions {
    onSuccess?: (documentId: string) => void;
    onError?: (error: Error) => void;
    resetAfterUpload?: boolean;
}

interface FileValidation {
    valid: boolean;
    error?: string;
}

interface UploadState {
    isUploading: boolean;
    error: Error | null;
    message: string;
    success: boolean;
    percentage: number;
    documentId?: string;
}

/**
 * Custom hook for handling document uploads with progress tracking
 */
export function useDocumentUpload(options?: UseDocumentUploadOptions) {
    const [uploadState, setUploadState] = useState<UploadState>({
        isUploading: false,
        error: null,
        message: '',
        success: false,
        percentage: 0,
    });
    const { user } = useAuth();

    // Define security attributes based on user data
    const securityAttributes = {
        clearance: user?.clearance || '',
        caveats: user?.caveats || [],
        coi: user?.coi || [],
        countryOfAffiliation: user?.countryOfAffiliation || ''
    };

    /**
     * Validate file type and size
     */
    const validateFile = useCallback((file: File): FileValidation => {
        // Validate file size
        if (file.size > DOCUMENT_CONFIG.MAX_FILE_SIZE) {
            return {
                valid: false,
                error: `File is too large. Maximum size is ${DOCUMENT_CONFIG.MAX_FILE_SIZE / (1024 * 1024)}MB.`,
            };
        }

        // Validate file type
        const isValidType = DOCUMENT_CONFIG.ALLOWED_FILE_TYPES.some(
            type => file.type === type
        );

        if (!isValidType) {
            return {
                valid: false,
                error: 'File type not supported. Please upload a PDF, Word, Excel, PowerPoint, or image file.',
            };
        }

        return { valid: true };
    }, []);

    /**
     * Reset upload progress and status
     */
    const resetUpload = useCallback(() => {
        setUploadState({
            isUploading: false,
            error: null,
            message: '',
            success: false,
            percentage: 0,
        });
    }, []);

    /**
     * Handle document upload with progress tracking
     */
    const uploadDocumentWithProgress = useCallback(
        async (data: DocumentUploadData) => {
            // Reset state first
            resetUpload();

            // Validate the file
            if (!data.file) {
                setUploadState({
                    isUploading: false,
                    error: new Error('Please select a file to upload'),
                    message: '',
                    success: false,
                    percentage: 0,
                });
                return;
            }

            const fileValidation = validateFile(data.file);
            if (!fileValidation.valid) {
                setUploadState({
                    isUploading: false,
                    error: new Error(fileValidation.error || 'Validation error'),
                    message: '',
                    success: false,
                    percentage: 0,
                });
                return;
            }

            // Pre-populate security attributes if not provided
            if (!data.classification) {
                data.classification = securityAttributes.clearance;

                if (!data.caveats || data.caveats.length === 0) {
                    data.caveats = securityAttributes.caveats;
                }

                if (!data.coi || data.coi.length === 0) {
                    data.coi = securityAttributes.coi;
                }
            }

            // Start upload
            setUploadState(prev => ({
                ...prev,
                isUploading: true,
                percentage: 0,
            }));

            // Simulate progress updates (since actual upload progress isn't available)
            const progressInterval = setInterval(() => {
                setUploadState(prev => ({
                    ...prev,
                    percentage: prev.percentage >= 90 ? 90 : prev.percentage + 10,
                }));
            }, 300);

            try {
                logger.debug(`Starting upload of ${data.file.name} (${Math.round(data.file.size / 1024)}KB)`);

                const uploadedDocument = await uploadDocument(data);

                // Upload complete, set to 100%
                setUploadState({
                    isUploading: false,
                    error: null,
                    message: `Document upload successful: ${uploadedDocument._id}`,
                    success: true,
                    percentage: 100,
                    documentId: uploadedDocument._id,
                });

                logger.info(`Document upload successful: ${uploadedDocument._id}`);

                // Call onSuccess callback if provided
                if (options?.onSuccess) {
                    options.onSuccess(uploadedDocument._id);
                }

                // Reset after successful upload if enabled
                if (options?.resetAfterUpload) {
                    setTimeout(resetUpload, 3000);
                }

                return uploadedDocument;
            } catch (error) {
                logger.error('Upload failed', error);

                // Determine error message
                let errorMessage = 'An error occurred while uploading the document';

                if (error instanceof Error) {
                    errorMessage = error.message;
                } else if ((error as ApiError)?.type === ApiErrorType.VALIDATION) {
                    errorMessage = `Validation error: ${(error as ApiError).message}`;
                }

                // Update state
                setUploadState({
                    isUploading: false,
                    error: new Error(errorMessage),
                    message: errorMessage,
                    success: false,
                    percentage: 0,
                });

                // Call onError callback if provided
                if (options?.onError && error instanceof Error) {
                    options.onError(error);
                }

                throw error;
            } finally {
                clearInterval(progressInterval);
            }
        },
        [validateFile, resetUpload, securityAttributes, options]
    );

    return {
        uploadDocument: uploadDocumentWithProgress,
        uploadState,
        resetUpload,
        validateFile,
    };
}