// frontend/src/components/documents/DocumentViewer.tsx
import { useState, useEffect } from 'react';
import { useRouter } from 'next/router';
import { Document as DocumentType } from '@/types/document';
import { formatDate, formatFileSize } from '@/utils/formatters';
import Link from 'next/link';
import { useAuth } from '@/context/auth-context';

interface DocumentViewerProps {
  document: DocumentType;
}

export function DocumentViewer({ document }: DocumentViewerProps) {
  const router = useRouter();
  const [isLoading, setIsLoading] = useState(true);
  const [hasError, setHasError] = useState(false);
  const { getAuthHeaders } = useAuth();
  const [previewUrl, setPreviewUrl] = useState('');
  const [downloadUrl, setDownloadUrl] = useState('');
  
  // Determine if the document is an image
  const isImage = document.mimeType.startsWith('image/');
  
  // Determine if the document is a PDF
  const isPdf = document.mimeType === 'application/pdf';
  
  // Initialize URLs in useEffect since window is only available client-side
  useEffect(() => {
    // Get base URL from window
    const baseUrl = window?.location?.origin || '';
    // Create document preview URL
    setPreviewUrl(`${baseUrl}/api/v1/documents/${document._id}/preview`);
    setDownloadUrl(`${baseUrl}/api/v1/documents/${document._id}/download`);
  }, [document._id]);
  
  // Handle loading state for embedded content
  const handleLoad = () => {
    setIsLoading(false);
    setHasError(false);
  };
  
  // Handle error in loading preview
  const handleError = () => {
    console.error('Error loading document preview:', document._id);
    setIsLoading(false);
    setHasError(true);
  };
  
  // Open document in new tab as a fallback
  const handleViewDocument = () => {
    if (downloadUrl) window.open(downloadUrl, '_blank');
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
      
      <div className="bg-white p-4 flex flex-col justify-center items-center min-h-[400px] max-h-[600px] overflow-auto">
        {isLoading && !hasError && (
          <div className="flex items-center justify-center w-full h-full">
            <svg className="animate-spin h-8 w-8 text-primary-600" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
              <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
              <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
            </svg>
          </div>
        )}
        
        {hasError && (
          <div className="flex flex-col items-center justify-center w-full h-full">
            <svg className="h-16 w-16 text-red-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
            </svg>
            <p className="mt-2 text-sm text-gray-500">
              Error loading document preview. Please try downloading the document instead.
            </p>
            <div className="flex space-x-4 mt-4">
              <button
                onClick={handleViewDocument}
                className="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-primary-600 hover:bg-primary-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-primary-500"
              >
                <svg className="mr-2 h-5 w-5" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                </svg>
                View in New Tab
              </button>
              <Link
                href={downloadUrl}
                className="inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-primary-500"
              >
                <svg className="mr-2 h-5 w-5" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
                </svg>
                Download
              </Link>
            </div>
          </div>
        )}
        
        {isImage && !hasError && (
          <img
            src={previewUrl}
            alt={document.filename}
            className="max-w-full max-h-[500px] object-contain"
            onLoad={handleLoad}
            onError={handleError}
          />
        )}
        
        {isPdf && !hasError && (
          <div className="w-full h-[500px]">
            {/* We use a direct object tag instead of iframe to prevent sandbox issues */}
            <object
              data={previewUrl}
              type="application/pdf"
              className="w-full h-full"
              onLoad={handleLoad}
              onError={handleError}
            >
              <div className="flex flex-col items-center justify-center p-6">
                <p className="text-gray-600 mb-4">Your browser doesn't support PDF preview.</p>
                <div className="flex space-x-4">
                  <button
                    onClick={handleViewDocument}
                    className="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-primary-600 hover:bg-primary-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-primary-500"
                  >
                    <svg className="mr-2 h-5 w-5" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                    </svg>
                    Open PDF
                  </button>
                  <Link
                    href={downloadUrl}
                    className="inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-primary-500"
                  >
                    <svg className="mr-2 h-5 w-5" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
                    </svg>
                    Download
                  </Link>
                </div>
              </div>
            </object>
          </div>
        )}
        
        {!isImage && !isPdf && !hasError && !isLoading && (
          <div className="flex flex-col items-center justify-center">
            <svg className="h-16 w-16 text-gray-400" fill="currentColor" viewBox="0 0 20 20">
              <path fillRule="evenodd" d="M4 4a2 2 0 012-2h4.586a1 1 0 01.707.293l4.414 4.414a1 1 0 01.293.707V16a2 2 0 01-2 2H6a2 2 0 01-2-2V4z" clipRule="evenodd" />
            </svg>
            <p className="mt-2 text-sm text-gray-500">
              Preview not available for this file type.
            </p>
            <div className="flex space-x-4 mt-4">
              <button
                onClick={handleViewDocument}
                className="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-primary-600 hover:bg-primary-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-primary-500"
              >
                <svg className="mr-2 h-5 w-5" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                </svg>
                View Document
              </button>
              <Link
                href={downloadUrl}
                className="inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-primary-500"
              >
                <svg className="mr-2 h-5 w-5" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
                </svg>
                Download
              </Link>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}