// frontend/src/components/documents/DocumentUploadForm.tsx
import React, { useEffect, useState } from 'react';
import { useForm, Controller } from 'react-hook-form';
import { useDropzone } from 'react-dropzone';
import { useTranslation } from 'next-i18next';
import { 
  ArrowUpTrayIcon, 
  XMarkIcon, 
  ExclamationCircleIcon,
  DocumentIcon,
  DocumentTextIcon,
  PhotoIcon,
  TableCellsIcon,
  PresentationChartBarIcon,
  CheckCircleIcon
} from '@heroicons/react/24/solid';
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
  const { t } = useTranslation(['common', 'documents']);
  const [isUploading, setIsUploading] = useState(false);
  const [uploadProgress, setUploadProgress] = useState(0);
  const [fileError, setFileError] = useState<string | null>(null);
  const [isDraggingOver, setIsDraggingOver] = useState(false);
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

  // Helper function to get file type icon
  const getFileIcon = (fileName: string) => {
    const extension = fileName.split('.').pop()?.toLowerCase();
    
    switch(extension) {
      case 'pdf':
        return <DocumentTextIcon className="h-6 w-6 text-red-500" />;
      case 'doc':
      case 'docx':
        return <DocumentTextIcon className="h-6 w-6 text-blue-500" />;
      case 'xls':
      case 'xlsx':
        return <TableCellsIcon className="h-6 w-6 text-green-500" />;
      case 'ppt':
      case 'pptx':
        return <PresentationChartBarIcon className="h-6 w-6 text-orange-500" />;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return <PhotoIcon className="h-6 w-6 text-purple-500" />;
      default:
        return <DocumentIcon className="h-6 w-6 text-gray-500" />;
    }
  };

  // Handle file uploads with react-dropzone
  const { getRootProps, getInputProps, isDragActive, fileRejections } = useDropzone({
    onDrop: (acceptedFiles) => {
      if (acceptedFiles && acceptedFiles.length > 0) {
        setValue('file', acceptedFiles[0], { shouldValidate: true });
        setFileError(null);
      }
      setIsDraggingOver(false);
    },
    onDragEnter: () => setIsDraggingOver(true),
    onDragLeave: () => setIsDraggingOver(false),
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
          setFileError(t('documents:uploadForm.fileSize'));
        } else if (errors[0]?.code === 'file-invalid-type') {
          setFileError(t('documents:uploadForm.fileTypes'));
        } else {
          setFileError('File upload error: ' + errors[0]?.message);
        }
      }
      setIsDraggingOver(false);
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
    <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
      <form onSubmit={handleSubmit(onFormSubmit)} className="space-y-6">
        {/* Security Banner Preview */}
        <div className="mb-6">
          <h3 className="text-sm font-medium text-gray-700 mb-2">
            {t('documents:uploadForm.bannerPreview')}
          </h3>
          <div className="border border-gray-200 rounded-md overflow-hidden">
            <SecurityBanner
              classification={classification || 'UNCLASSIFIED'}
              caveats={caveats || []}
              releasability={releasability || []}
              coi={coi || []}
            />
          </div>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          {/* Left Column */}
          <div className="space-y-6">
            {/* File Upload Section */}
            <div className="space-y-2">
              <label className="block text-sm font-medium text-gray-700">
                {t('documents:uploadForm.fileUpload')}*
              </label>
              
              <div 
                {...getRootProps()} 
                className={`relative mt-1 flex flex-col justify-center items-center px-6 py-8 border-2 border-dashed rounded-lg transition-all duration-200 ease-in-out ${
                  isDragActive || isDraggingOver
                    ? 'border-indigo-500 bg-indigo-50' 
                    : fileError 
                      ? 'border-red-300 bg-red-50' 
                      : file
                        ? 'border-green-300 bg-green-50'
                        : 'border-gray-300 hover:border-indigo-300 hover:bg-gray-50'
                }`}
                aria-describedby="file-upload-error"
              >
                <div className="space-y-3 text-center">
                  {file ? (
                    <div className="flex flex-col items-center">
                      <CheckCircleIcon className="h-12 w-12 text-green-500 mb-2" aria-hidden="true" />
                      <p className="text-sm font-medium text-gray-900">{t('documents:uploadForm.fileReady')}</p>
                    </div>
                  ) : (
                    <>
                      <ArrowUpTrayIcon className={`mx-auto h-12 w-12 ${isDragActive || isDraggingOver ? 'text-indigo-500' : 'text-gray-400'}`} aria-hidden="true" />
                      <div className="flex flex-col space-y-1 text-sm text-gray-600">
                        <span className="font-medium text-indigo-600 hover:text-indigo-500">
                          {t('documents:uploadForm.browseFiles')}
                        </span>
                        <span>{t('documents:uploadForm.dragAndDrop')}</span>
                        <input {...getInputProps()} name="file" id="file-upload" className="sr-only" />
                        <p className="text-xs text-gray-500">
                          {t('documents:uploadForm.fileTypes')}
                        </p>
                      </div>
                    </>
                  )}
                </div>
                
                {isDragActive && (
                  <div className="absolute inset-0 bg-indigo-50 bg-opacity-50 flex items-center justify-center rounded-lg">
                    <p className="text-indigo-500 font-medium">{t('documents:uploadForm.dropFileHere')}</p>
                  </div>
                )}
              </div>
              
              {fileError && (
                <p className="mt-2 text-sm text-red-600 flex items-center" id="file-upload-error">
                  <ExclamationCircleIcon className="h-4 w-4 mr-1 flex-shrink-0" />
                  <span>{fileError}</span>
                </p>
              )}

              {file && (
                <div className="mt-3 flex items-center p-3 bg-white rounded-lg border border-gray-200 shadow-sm">
                  <div className="mr-3">
                    {getFileIcon(file.name)}
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-medium text-gray-900 truncate">{file.name}</p>
                    <p className="text-xs text-gray-500">
                      {(file.size / 1024 / 1024).toFixed(2)} MB
                    </p>
                  </div>
                  <button
                    type="button"
                    onClick={removeFile}
                    className="ml-4 flex-shrink-0 p-1 text-gray-400 rounded-full hover:text-red-500 hover:bg-red-50 transition-colors"
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
                rules={{ required: t('documents:uploadForm.classificationRequired') }}
                render={({ field }) => (
                  <div>
                    <label htmlFor="classification" className="block text-sm font-medium text-gray-700">
                      {t('documents:uploadForm.classification')}*
                    </label>
                    <div className="mt-1 relative rounded-md shadow-sm">
                      <select
                        id="classification"
                        {...field}
                        className="block w-full rounded-md border-gray-300 py-2 pl-3 pr-10 text-base focus:border-indigo-500 focus:outline-none focus:ring-indigo-500 sm:text-sm text-gray-900"
                        aria-invalid={errors.classification ? 'true' : 'false'}
                        aria-describedby={errors.classification ? 'classification-error' : undefined}
                      >
                        <option value="">{t('documents:filters.allClassifications')}</option>
                        {getClassifications().map((option) => (
                          <option key={option.value} value={option.value} className="text-gray-900">
                            {option.label}
                          </option>
                        ))}
                      </select>
                      <div className="pointer-events-none absolute inset-y-0 right-0 flex items-center px-2 text-gray-700">
                        <ChevronUpDownIcon className="h-4 w-4" aria-hidden="true" />
                      </div>
                    </div>
                    {errors.classification && (
                      <p id="classification-error" className="mt-2 text-sm text-red-600 flex items-center">
                        <ExclamationCircleIcon className="h-4 w-4 mr-1 flex-shrink-0" />
                        <span>{errors.classification.message}</span>
                      </p>
                    )}
                  </div>
                )}
              />
            </div>
          </div>

          {/* Right Column */}
          <div className="space-y-6">
            {/* Multi-select Controls */}
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              {/* Caveats Multi-select */}
              <div>
                <Controller
                  name="caveats"
                  control={control}
                  render={({ field: { onChange, value } }) => (
                    <div>
                      <label htmlFor="caveats" className="block text-sm font-medium text-gray-700">
                        {t('documents:uploadForm.caveats')}
                      </label>
                      <div className="mt-1 relative rounded-md shadow-sm">
                        <select
                          id="caveats"
                          multiple
                          value={value}
                          onChange={(e) => {
                            const selectedOptions = Array.from(e.target.selectedOptions, (option) => option.value);
                            onChange(selectedOptions);
                          }}
                          className="block w-full rounded-md border-gray-300 py-2 pl-3 pr-10 text-base focus:border-indigo-500 focus:outline-none focus:ring-indigo-500 sm:text-sm min-h-[120px] text-gray-900"
                        >
                          {getCaveats().map((option) => (
                            <option key={option.value} value={option.value} className="text-gray-900">
                              {option.label}
                            </option>
                          ))}
                        </select>
                      </div>
                      <p className="mt-1 text-xs text-gray-600 font-medium">Hold Ctrl/Cmd to select multiple options</p>
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
                        {t('documents:uploadForm.coi')}
                      </label>
                      <div className="mt-1 relative rounded-md shadow-sm">
                        <select
                          id="coi"
                          multiple
                          value={value}
                          onChange={(e) => {
                            const selectedOptions = Array.from(e.target.selectedOptions, (option) => option.value);
                            onChange(selectedOptions);
                          }}
                          className="block w-full rounded-md border-gray-300 py-2 pl-3 pr-10 text-base focus:border-indigo-500 focus:outline-none focus:ring-indigo-500 sm:text-sm min-h-[120px] text-gray-900"
                        >
                          {getCOIs().map((option) => (
                            <option key={option.value} value={option.value} className="text-gray-900">
                              {option.label}
                            </option>
                          ))}
                        </select>
                      </div>
                      <p className="mt-1 text-xs text-gray-600 font-medium">Hold Ctrl/Cmd to select multiple options</p>
                    </div>
                  )}
                />
              </div>
            </div>

            {/* Releasability Multi-select - Full Width */}
            <div>
              <Controller
                name="releasability"
                control={control}
                render={({ field: { onChange, value } }) => (
                  <div>
                    <label htmlFor="releasability" className="block text-sm font-medium text-gray-700">
                      {t('documents:uploadForm.releasability')}
                    </label>
                    <div className="mt-1 relative rounded-md shadow-sm">
                      <select
                        id="releasability"
                        multiple
                        value={value}
                        onChange={(e) => {
                          const selectedOptions = Array.from(e.target.selectedOptions, (option) => option.value);
                          onChange(selectedOptions);
                        }}
                        className="block w-full rounded-md border-gray-300 py-2 pl-3 pr-10 text-base focus:border-indigo-500 focus:outline-none focus:ring-indigo-500 sm:text-sm min-h-[120px] text-gray-900"
                      >
                        {getReleasability().map((option) => (
                          <option key={option.value} value={option.value} className="text-gray-900">
                            {option.label}
                          </option>
                        ))}
                      </select>
                    </div>
                    <p className="mt-1 text-xs text-gray-600 font-medium">Hold Ctrl/Cmd to select multiple options</p>
                  </div>
                )}
              />
            </div>
          </div>
        </div>

        {/* Progress Bar */}
        {isUploading && (
          <div className="mt-6">
            <div className="w-full h-2 bg-gray-200 rounded-full overflow-hidden">
              <div
                className={`h-full ${uploadProgress < 100 ? 'bg-indigo-600' : 'bg-green-500'} transition-all duration-300 ease-out`}
                style={{ width: `${uploadProgress}%` }}
              ></div>
            </div>
            <div className="flex justify-between items-center mt-2">
              <p className="text-sm text-gray-600 font-medium">
                {uploadProgress < 100 ? t('documents:uploadForm.uploading') : t('documents:uploadForm.uploadComplete')}
              </p>
              <p className="text-sm font-medium text-gray-700">{uploadProgress}%</p>
            </div>
          </div>
        )}

        {/* Submit Button */}
        <div className="flex justify-end mt-8">
          <button
            type="submit"
            disabled={!file || isSubmitting || isUploading || !classification}
            className="px-5 py-2.5 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 disabled:bg-indigo-300 disabled:cursor-not-allowed transition-colors duration-200"
          >
            {isUploading ? t('documents:uploadForm.uploading') : t('documents:uploadForm.uploadDocument')}
          </button>
        </div>
      </form>
    </div>
  );
}