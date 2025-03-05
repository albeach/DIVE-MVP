// frontend/src/components/documents/DocumentUploadForm.tsx
import React, { useEffect, useState } from 'react';
import { useForm, Controller } from 'react-hook-form';
import { useDropzone } from 'react-dropzone';
import { ArrowUpTrayIcon, XMarkIcon, ExclamationCircleIcon } from '@heroicons/react/24/solid';
import { ChevronUpDownIcon } from '@heroicons/react/24/solid';
import { uploadDocument } from '@/services/documentService';
import { SecurityBanner } from '@/components/security/SecurityBanner';
import { useAuth } from '@/context/auth-context';
import { getClassifications, getCaveats, getReleasability, getCOIs } from '@/lib/securityUtils';
import { DocumentUploadData } from '@/types/document';

interface FormData {
  file: File | null;
  classification: string;
  releasability: string[];
  caveats: string[];
  coi: string[];
}

interface DocumentUploadFormProps {
  onSuccess?: (documentId: string) => void;
  onError?: (error: Error) => void;
  resetAfterSubmit?: boolean;
}

export function DocumentUploadForm({
  onSuccess,
  onError,
  resetAfterSubmit = false,
}: DocumentUploadFormProps) {
  const [isUploading, setIsUploading] = useState(false);
  const [uploadProgress, setUploadProgress] = useState(0);
  const [fileError, setFileError] = useState<string | null>(null);
  const { getUserSecurityAttributes } = useAuth();
  
  const {
    control,
    handleSubmit,
    setValue,
    watch,
    reset,
    formState: { errors, isSubmitting, isValid },
  } = useForm<FormData>({
    defaultValues: {
      file: null,
      classification: '',
      releasability: [],
      caveats: [],
      coi: [],
    },
    mode: 'onChange',
  });

  const file = watch('file');
  const classification = watch('classification');
  const caveats = watch('caveats');
  const releasability = watch('releasability');
  const coi = watch('coi');

  // Pre-populate form with user's security attributes
  useEffect(() => {
    const userSecurityAttributes = getUserSecurityAttributes();
    
    if (userSecurityAttributes.clearance) {
      setValue('classification', userSecurityAttributes.clearance);
    }
    
    if (userSecurityAttributes.caveats && userSecurityAttributes.caveats.length > 0) {
      setValue('caveats', userSecurityAttributes.caveats);
    }
    
    if (userSecurityAttributes.coi && userSecurityAttributes.coi.length > 0) {
      setValue('coi', userSecurityAttributes.coi);
    }
  }, [getUserSecurityAttributes, setValue]);

  // Handle file uploads with react-dropzone
  const { getRootProps, getInputProps, isDragActive, fileRejections } = useDropzone({
    onDrop: (acceptedFiles) => {
      if (acceptedFiles && acceptedFiles.length > 0) {
        setValue('file', acceptedFiles[0], { shouldValidate: true });
        setFileError(null);
      }
    },
    maxFiles: 1,
    maxSize: 100 * 1024 * 1024, // 100MB
    accept: {
      'application/pdf': ['.pdf'],
      'application/msword': ['.doc'],
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document': ['.docx'],
      'text/plain': ['.txt'],
      'application/vnd.ms-excel': ['.xls'],
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': ['.xlsx'],
      'application/vnd.ms-powerpoint': ['.ppt'],
      'application/vnd.openxmlformats-officedocument.presentationml.presentation': ['.pptx'],
      'image/jpeg': ['.jpg', '.jpeg'],
      'image/png': ['.png'],
    },
    onDropRejected: (fileRejections) => {
      if (fileRejections.length > 0) {
        const { errors } = fileRejections[0];
        if (errors[0]?.code === 'file-too-large') {
          setFileError('File is too large. Maximum size is 100MB.');
        } else if (errors[0]?.code === 'file-invalid-type') {
          setFileError('File type not supported. Please upload a PDF, Word, Excel, PowerPoint, or image file.');
        } else {
          setFileError('File upload error: ' + errors[0]?.message);
        }
      }
    },
  });

  const removeFile = () => {
    setValue('file', null, { shouldValidate: true });
    setFileError(null);
  };

  const onFormSubmit = async (data: FormData) => {
    if (!data.file) {
      setFileError('Please select a file to upload');
      return;
    }

    if (!data.classification) {
      return;
    }

    setIsUploading(true);
    setUploadProgress(0);

    // For demo purposes, we'll simulate a progress bar
    const progressInterval = setInterval(() => {
      setUploadProgress((prev) => (prev >= 90 ? 90 : prev + 10));
    }, 300);

    try {
      const uploadData: DocumentUploadData = {
        file: data.file,
        classification: data.classification,
        releasability: data.releasability,
        caveats: data.caveats,
        coi: data.coi,
      };

      const uploadedDocument = await uploadDocument(uploadData);
      
      setUploadProgress(100);
      setTimeout(() => {
        setIsUploading(false);
        setUploadProgress(0);
        
        if (resetAfterSubmit) {
          reset();
        }
        
        if (onSuccess) {
          onSuccess(uploadedDocument._id);
        }
      }, 500);
    } catch (error) {
      console.error('Upload failed:', error);
      setIsUploading(false);
      setUploadProgress(0);
      
      if (onError && error instanceof Error) {
        onError(error);
      }
    } finally {
      clearInterval(progressInterval);
    }
  };

  return (
    <form onSubmit={handleSubmit(onFormSubmit)} className="space-y-6">
      {/* Security Banner Preview */}
      <div className="mb-4">
        <h3 className="text-sm font-medium text-gray-700 mb-2">Document Security Banner Preview</h3>
        <SecurityBanner
          classification={classification || 'UNCLASSIFIED'}
          caveats={caveats || []}
          releasability={releasability || []}
          coi={coi || []}
        />
      </div>

      {/* File Upload Section */}
      <div className="space-y-2">
        <label className="block text-sm font-medium text-gray-700">
          Document Upload*
        </label>
        
        <div 
          {...getRootProps()} 
          className={`mt-1 flex justify-center px-6 pt-5 pb-6 border-2 border-dashed rounded-md ${
            isDragActive 
              ? 'border-indigo-500 bg-indigo-50' 
              : fileError 
                ? 'border-red-300 bg-red-50' 
                : 'border-gray-300 hover:border-gray-400'
          }`}
          aria-describedby="file-upload-error"
        >
          <div className="space-y-1 text-center">
            <ArrowUpTrayIcon className="mx-auto h-12 w-12 text-gray-400" aria-hidden="true" />
            <div className="flex text-sm text-gray-600">
              <label
                htmlFor="file-upload"
                className="relative cursor-pointer rounded-md font-medium text-indigo-600 hover:text-indigo-500 focus-within:outline-none"
              >
                <span>Upload a file</span>
                <input {...getInputProps()} name="file" id="file-upload" className="sr-only" />
              </label>
              <p className="pl-1">or drag and drop</p>
            </div>
            <p className="text-xs text-gray-500">
              PDF, Word, Excel, PowerPoint, or Images up to 100MB
            </p>
          </div>
        </div>
        
        {fileError && (
          <p className="mt-2 text-sm text-red-600 flex items-center" id="file-upload-error">
            <ExclamationCircleIcon className="h-4 w-4 mr-1" />
            {fileError}
          </p>
        )}

        {file && (
          <div className="mt-2 flex items-center justify-between p-2 bg-gray-50 rounded-md">
            <span className="truncate max-w-xs text-sm">{file.name}</span>
            <span className="text-xs text-gray-500 ml-2 mr-auto">
              {(file.size / 1024 / 1024).toFixed(2)} MB
            </span>
            <button
              type="button"
              onClick={removeFile}
              className="text-red-500 hover:text-red-700"
              aria-label="Remove file"
            >
              <XMarkIcon className="h-5 w-5" />
            </button>
          </div>
        )}
      </div>

      {/* Classification Dropdown */}
      <div>
        <Controller
          name="classification"
          control={control}
          rules={{ required: 'Classification is required' }}
          render={({ field }) => (
            <div>
              <label htmlFor="classification" className="block text-sm font-medium text-gray-700">
                Classification*
              </label>
              <div className="mt-1 relative">
                <select
                  id="classification"
                  {...field}
                  className="block w-full rounded-md border-gray-300 py-2 pl-3 pr-10 text-base focus:border-indigo-500 focus:outline-none focus:ring-indigo-500 sm:text-sm"
                  aria-invalid={errors.classification ? 'true' : 'false'}
                  aria-describedby={errors.classification ? 'classification-error' : undefined}
                >
                  <option value="">Select a classification</option>
                  {getClassifications().map((option) => (
                    <option key={option.value} value={option.value}>
                      {option.label}
                    </option>
                  ))}
                </select>
                <div className="pointer-events-none absolute inset-y-0 right-0 flex items-center px-2 text-gray-700">
                  <ChevronUpDownIcon className="h-4 w-4" aria-hidden="true" />
                </div>
              </div>
              {errors.classification && (
                <p id="classification-error" className="mt-2 text-sm text-red-600">
                  {errors.classification.message}
                </p>
              )}
            </div>
          )}
        />
      </div>

      {/* Caveats Multi-select */}
      <div>
        <Controller
          name="caveats"
          control={control}
          render={({ field: { onChange, value } }) => (
            <div>
              <label htmlFor="caveats" className="block text-sm font-medium text-gray-700">
                Caveats
              </label>
              <div className="mt-1">
                <select
                  id="caveats"
                  multiple
                  value={value}
                  onChange={(e) => {
                    const selectedOptions = Array.from(e.target.selectedOptions, (option) => option.value);
                    onChange(selectedOptions);
                  }}
                  className="block w-full rounded-md border-gray-300 py-2 pl-3 pr-10 text-base focus:border-indigo-500 focus:outline-none focus:ring-indigo-500 sm:text-sm"
                >
                  {getCaveats().map((option) => (
                    <option key={option.value} value={option.value}>
                      {option.label}
                    </option>
                  ))}
                </select>
                <p className="mt-1 text-xs text-gray-500">Hold Ctrl/Cmd to select multiple options</p>
              </div>
            </div>
          )}
        />
      </div>

      {/* Releasability Multi-select */}
      <div>
        <Controller
          name="releasability"
          control={control}
          render={({ field: { onChange, value } }) => (
            <div>
              <label htmlFor="releasability" className="block text-sm font-medium text-gray-700">
                Releasability
              </label>
              <div className="mt-1">
                <select
                  id="releasability"
                  multiple
                  value={value}
                  onChange={(e) => {
                    const selectedOptions = Array.from(e.target.selectedOptions, (option) => option.value);
                    onChange(selectedOptions);
                  }}
                  className="block w-full rounded-md border-gray-300 py-2 pl-3 pr-10 text-base focus:border-indigo-500 focus:outline-none focus:ring-indigo-500 sm:text-sm"
                >
                  {getReleasability().map((option) => (
                    <option key={option.value} value={option.value}>
                      {option.label}
                    </option>
                  ))}
                </select>
                <p className="mt-1 text-xs text-gray-500">Hold Ctrl/Cmd to select multiple options</p>
              </div>
            </div>
          )}
        />
      </div>

      {/* COI Multi-select */}
      <div>
        <Controller
          name="coi"
          control={control}
          render={({ field: { onChange, value } }) => (
            <div>
              <label htmlFor="coi" className="block text-sm font-medium text-gray-700">
                COI
              </label>
              <div className="mt-1">
                <select
                  id="coi"
                  multiple
                  value={value}
                  onChange={(e) => {
                    const selectedOptions = Array.from(e.target.selectedOptions, (option) => option.value);
                    onChange(selectedOptions);
                  }}
                  className="block w-full rounded-md border-gray-300 py-2 pl-3 pr-10 text-base focus:border-indigo-500 focus:outline-none focus:ring-indigo-500 sm:text-sm"
                >
                  {getCOIs().map((option) => (
                    <option key={option.value} value={option.value}>
                      {option.label}
                    </option>
                  ))}
                </select>
                <p className="mt-1 text-xs text-gray-500">Hold Ctrl/Cmd to select multiple options</p>
              </div>
            </div>
          )}
        />
      </div>

      {/* Progress Bar */}
      {isUploading && (
        <div>
          <div className="w-full bg-gray-200 rounded-full h-2.5">
            <div
              className="bg-indigo-600 h-2.5 rounded-full transition-all"
              style={{ width: `${uploadProgress}%` }}
            ></div>
          </div>
          <p className="text-sm text-gray-600 mt-2 text-center">
            Uploading document... {uploadProgress}%
          </p>
        </div>
      )}

      {/* Submit Button */}
      <div className="flex justify-end">
        <button
          type="submit"
          disabled={!file || isSubmitting || isUploading}
          className="px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 disabled:bg-indigo-300 disabled:cursor-not-allowed"
        >
          {isUploading ? 'Uploading...' : 'Upload Document'}
        </button>
      </div>
    </form>
  );
}