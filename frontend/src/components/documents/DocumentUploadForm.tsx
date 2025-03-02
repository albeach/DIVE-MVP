// frontend/src/components/documents/DocumentUploadForm.tsx
import React, { useState } from 'react';
import { useTranslation } from 'next-i18next';
import { useDropzone } from 'react-dropzone';
import { useForm, Controller } from 'react-hook-form';
import { DocumentUploadData } from '@/types/document';
import { Button } from '@/components/ui/Button';
import { Input } from '@/components/ui/Input';
import { Select } from '@/components/ui/Select';
import { Badge } from '@/components/ui/Badge';
import { SecurityBanner } from '@/components/security/SecurityBanner';
import { CloudArrowUpIcon, DocumentIcon, XMarkIcon } from '@heroicons/react/24/outline';

interface DocumentUploadFormProps {
  onSubmit: (data: DocumentUploadData) => Promise<void>;
  isUploading: boolean;
}

export function DocumentUploadForm({ onSubmit, isUploading }: DocumentUploadFormProps) {
  const { t } = useTranslation(['common', 'documents']);
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const [previewClassification, setPreviewClassification] = useState('UNCLASSIFIED');
  const [previewCaveats, setPreviewCaveats] = useState<string[]>([]);
  
  const { register, handleSubmit, control, watch, formState: { errors } } = useForm<DocumentUploadData>();
  
  // Watch form values for banner preview
  const watchClassification = watch('classification', 'UNCLASSIFIED');
  const watchCaveats = watch('caveats', []);
  
  // Update banner preview when form values change
  React.useEffect(() => {
    setPreviewClassification(watchClassification);
    setPreviewCaveats(watchCaveats || []);
  }, [watchClassification, watchCaveats]);
  
  // Handle file upload with react-dropzone
  const { getRootProps, getInputProps, isDragActive } = useDropzone({
    accept: {
      'application/pdf': ['.pdf'],
      'application/msword': ['.doc'],
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document': ['.docx'],
      'application/vnd.ms-excel': ['.xls'],
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': ['.xlsx'],
      'application/vnd.ms-powerpoint': ['.ppt'],
      'application/vnd.openxmlformats-officedocument.presentationml.presentation': ['.pptx'],
      'text/plain': ['.txt'],
      'image/jpeg': ['.jpg', '.jpeg'],
      'image/png': ['.png']
    },
    maxSize: 10 * 1024 * 1024, // 10MB
    multiple: false,
    onDrop: (acceptedFiles) => {
      if (acceptedFiles.length > 0) {
        setSelectedFile(acceptedFiles[0]);
      }
    }
  });
  
  const onFormSubmit = (data: DocumentUploadData) => {
    if (!selectedFile) {
      return;
    }
    
    const uploadData: DocumentUploadData = {
      ...data,
      file: selectedFile
    };
    
    onSubmit(uploadData);
  };
  
  const removeFile = () => {
    setSelectedFile(null);
  };
  
  // Classifications for the dropdown
  const classifications = [
    { value: 'UNCLASSIFIED', label: 'UNCLASSIFIED' },
    { value: 'RESTRICTED', label: 'RESTRICTED' },
    { value: 'CONFIDENTIAL', label: 'CONFIDENTIAL' },
    { value: 'NATO CONFIDENTIAL', label: 'NATO CONFIDENTIAL' },
    { value: 'SECRET', label: 'SECRET' },
    { value: 'NATO SECRET', label: 'NATO SECRET' },
    { value: 'TOP SECRET', label: 'TOP SECRET' },
    { value: 'COSMIC TOP SECRET', label: 'COSMIC TOP SECRET' },
  ];
  
  // Available caveats
  const availableCaveats = [
    { value: 'FVEY', label: 'FVEY' },
    { value: 'NATO', label: 'NATO' },
    { value: 'EU', label: 'EU' },
    { value: 'NOFORN', label: 'NOFORN' },
    { value: 'ORCON', label: 'ORCON' },
    { value: 'PROPIN', label: 'PROPIN' },
  ];
  
  // Available Communities of Interest
  const availableCOIs = [
    { value: 'OpAlpha', label: 'Operation Alpha' },
    { value: 'OpBravo', label: 'Operation Bravo' },
    { value: 'OpGamma', label: 'Operation Gamma' },
    { value: 'MissionX', label: 'Mission X' },
    { value: 'MissionZ', label: 'Mission Z' },
  ];
  
  // Available countries for releasability
  const availableCountries = [
    { value: 'USA', label: 'USA' },
    { value: 'GBR', label: 'United Kingdom' },
    { value: 'CAN', label: 'Canada' },
    { value: 'AUS', label: 'Australia' },
    { value: 'NZL', label: 'New Zealand' },
    { value: 'FVEY', label: 'Five Eyes' },
    { value: 'NATO', label: 'NATO' },
    { value: 'EU', label: 'European Union' },
  ];
  
  return (
    <form onSubmit={handleSubmit(onFormSubmit)}>
      <div className="space-y-6">
        {/* Security Banner Preview */}
        <div className="mb-6">
          <h3 className="text-sm font-medium text-gray-700 mb-2">
            {t('documents:uploadForm.bannerPreview')}
          </h3>
          <SecurityBanner 
            classification={previewClassification} 
            caveats={previewCaveats}
          />
        </div>
        
        {/* File Upload Section */}
        <div>
          <h3 className="text-sm font-medium text-gray-700 mb-2">
            {t('documents:uploadForm.fileUpload')}
          </h3>
          
          {!selectedFile ? (
            <div
              {...getRootProps()}
              className={`border-2 border-dashed rounded-md p-6 text-center cursor-pointer ${
                isDragActive ? 'border-dive25-500 bg-dive25-50' : 'border-gray-300 hover:border-dive25-500'
              }`}
            >
              <input {...getInputProps()} />
              <CloudArrowUpIcon className="mx-auto h-12 w-12 text-gray-400" />
              <p className="mt-2 text-sm text-gray-600">
                {isDragActive
                  ? t('documents:uploadForm.dropFileHere')
                  : t('documents:uploadForm.dragAndDrop')}
              </p>
              <p className="mt-1 text-xs text-gray-500">
                {t('documents:uploadForm.fileTypes')}
              </p>
              <p className="mt-1 text-xs text-gray-500">
                {t('documents:uploadForm.fileSize')}
              </p>
            </div>
          ) : (
            <div className="flex items-center justify-between p-4 border rounded-md">
              <div className="flex items-center">
                <DocumentIcon className="h-8 w-8 text-dive25-500 mr-3" />
                <div>
                  <p className="text-sm font-medium">{selectedFile.name}</p>
                  <p className="text-xs text-gray-500">
                    {(selectedFile.size / 1024 / 1024).toFixed(2)} MB
                  </p>
                </div>
              </div>
              <Button
                type="button"
                variant="ghost"
                onClick={removeFile}
              >
                <XMarkIcon className="h-5 w-5 text-gray-500" />
              </Button>
            </div>
          )}
          
          {!selectedFile && (
            <p className="mt-2 text-sm text-red-600">
              {t('documents:uploadForm.fileRequired')}
            </p>
          )}
        </div>
        
        {/* Classification Section */}
        <div>
          <h3 className="text-sm font-medium text-gray-700 mb-2">
            {t('documents:uploadForm.securityMarkings')}
          </h3>
          
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div>
              <label htmlFor="classification" className="block text-sm font-medium text-gray-700">
                {t('documents:uploadForm.classification')} *
              </label>
              <Controller
                name="classification"
                control={control}
                defaultValue="UNCLASSIFIED"
                rules={{ required: true }}
                render={({ field }) => (
                  <Select
                    id="classification"
                    {...field}
                    options={classifications}
                    error={errors.classification ? t('documents:uploadForm.classificationRequired') : undefined}
                  />
                )}
              />
            </div>
            
            <div>
              <label htmlFor="caveats" className="block text-sm font-medium text-gray-700">
                {t('documents:uploadForm.caveats')}
              </label>
              <Controller
                name="caveats"
                control={control}
                defaultValue={[]}
                render={({ field }) => (
                  <Select
                    id="caveats"
                    {...field}
                    options={availableCaveats}
                    multiple
                  />
                )}
              />
            </div>
            
            <div>
              <label htmlFor="releasability" className="block text-sm font-medium text-gray-700">
                {t('documents:uploadForm.releasability')}
              </label>
              <Controller
                name="releasability"
                control={control}
                defaultValue={[]}
                render={({ field }) => (
                  <Select
                    id="releasability"
                    {...field}
                    options={availableCountries}
                    multiple
                  />
                )}
              />
            </div>
            
            <div>
              <label htmlFor="coi" className="block text-sm font-medium text-gray-700">
                {t('documents:uploadForm.coi')}
              </label>
              <Controller
                name="coi"
                control={control}
                defaultValue={[]}
                render={({ field }) => (
                  <Select
                    id="coi"
                    {...field}
                    options={availableCOIs}
                    multiple
                  />
                )}
              />
            </div>
          </div>
        </div>
        
        {/* Submit Button */}
        <div className="flex justify-end pt-6 border-t border-gray-200">
          <Button
            type="submit"
            variant="primary"
            disabled={!selectedFile || isUploading}
            isLoading={isUploading}
          >
            {t('documents:uploadForm.uploadDocument')}
          </Button>
        </div>
      </div>
    </form>
  );
}