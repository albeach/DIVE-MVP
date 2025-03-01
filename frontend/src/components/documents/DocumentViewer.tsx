// frontend/src/components/documents/DocumentViewer.tsx
import { useState } from 'react';
import { useRouter } from 'next/router';
import { Document as DocumentType } from '@/types/document';
import { formatDate, formatFileSize } from '@/utils/formatters';

interface DocumentViewerProps {
  document: DocumentType;
}

export function DocumentViewer({ document }: DocumentViewerProps) {
  const router = useRouter();
  const [isLoading, setIsLoading] = useState(true);
  
  // Determine if the document is an image
  const isImage = document.mimeType.startsWith('image/');
  
  // Determine if the document is a PDF
  const isPdf = document.mimeType === 'application/pdf';
  
  // Create document preview URL
  const previewUrl = `/api/v1/documents/${document._id}/preview`;
  
  // Handle loading state for embedded content
  const handleLoad = () => {
    setIsLoading(false);
  };
  
  // Handle error in loading preview
  const handleError = () => {
    setIsLoading(false);
  };
  
  return (
    <div className="bg-white shadow overflow-hidden rounded-lg">
      <div className="px-4 py-5 sm:px-6 bg-gray-50 border-b border-gray-200">
        <h3 className="text-lg leading-6 font-medium text-gray-900">
          {document.filename}
        </h3>
        <p className="mt-1 max-w-2xl text-sm text-gray-500">
          {formatFileSize(document.size)} • {document.mimeType} • 
          Uploaded on {formatDate(new Date(document.uploadDate))}
        </p>
      </div>
      
      <div className="bg-white p-4 flex justify-center min-h-[400px]">
        {isLoading && (
          <div className="flex items-center justify-center w-full h-full">
            <svg className="animate-spin h-8 w-8 text-dive25-600" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
              <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
              <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
            </svg>
          </div>
        )}
        
        {isImage && (
          <img
            src={previewUrl}
            alt={document.filename}
            className="max-w-full max-h-[600px] object-contain"
            onLoad={handleLoad}
            onError={handleError}
          />
        )}
        
        {isPdf && (
          <iframe
            src={`${previewUrl}#toolbar=0`}
            className="w-full h-[600px] border-none"
            onLoad={handleLoad}
            onError={handleError}
          ></iframe>
        )}
        
        {!isImage && !isPdf && (
          <div className="flex flex-col items-center justify-center">
            <svg className="h-16 w-16 text-gray-400" fill="currentColor" viewBox="0 0 20 20">
              <path fillRule="evenodd" d="M4 4a2 2 0 012-2h4.586a1 1 0 01.707.293l4.414 4.414a1 1 0 01.293.707V16a2 2 0 01-2 2H6a2 2 0 01-2-2V4z" clipRule="evenodd" />
            </svg>
            <p className="mt-2 text-sm text-gray-500">
              Preview not available for this file type.
            </p>
          </div>
        )}
      </div>
    </div>
  );
}