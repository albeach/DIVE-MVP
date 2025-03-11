// frontend/src/components/documents/DocumentList.tsx
import { useTranslation } from 'next-i18next';
import Link from 'next/link';
import { Document, PaginationInfo } from '@/types/document';
import { formatDate, formatFileSize } from '@/utils/formatters';
import { Badge } from '@/components/ui/Badge';
import { Pagination } from '@/components/ui/Pagination';
import { useState, useEffect } from 'react';
import { 
  DocumentIcon, 
  ExclamationCircleIcon,
  DocumentTextIcon,
  ArrowDownIcon,
  ArrowUpIcon,
  ArrowsUpDownIcon,
  PencilIcon,
  TrashIcon,
  EyeIcon,
  PhotoIcon,
  ChartBarSquareIcon
} from '@heroicons/react/24/outline';
import { twMerge } from 'tailwind-merge';

interface DocumentListProps {
  documents: Document[];
  pagination?: PaginationInfo;
  onPageChange: (page: number) => void;
  isLoading?: boolean;
  error?: Error | null;
  onRetry?: () => void;
}

export function DocumentList({ 
  documents, 
  pagination, 
  onPageChange, 
  isLoading = false,
  error = null,
  onRetry
}: DocumentListProps) {
  const { t } = useTranslation(['common', 'documents']);
  const [sortField, setSortField] = useState<string | null>(null);
  const [sortDirection, setSortDirection] = useState<'asc' | 'desc'>('desc');
  const [highlightedRow, setHighlightedRow] = useState<string | null>(null);

  // Handle sort click
  const handleSortClick = (field: string) => {
    if (sortField === field) {
      setSortDirection(sortDirection === 'asc' ? 'desc' : 'asc');
    } else {
      setSortField(field);
      setSortDirection('asc');
    }
  };

  // Get file type icon based on filename
  const getFileIcon = (filename: string) => {
    const extension = filename.split('.').pop()?.toLowerCase() || '';
    
    switch(extension) {
      case 'pdf':
        return <DocumentTextIcon className="h-5 w-5 text-red-500" />;
      case 'doc':
      case 'docx':
        return <DocumentTextIcon className="h-5 w-5 text-blue-500" />;
      case 'xls':
      case 'xlsx':
        return <ChartBarSquareIcon className="h-5 w-5 text-green-500" />;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return <PhotoIcon className="h-5 w-5 text-purple-500" />;
      default:
        return <DocumentIcon className="h-5 w-5 text-gray-500" />;
    }
  };

  // Convert internal sort direction to aria-sort attribute value
  const getAriaSortValue = (field: string): "ascending" | "descending" | "none" | undefined => {
    if (sortField !== field) return undefined;
    return sortDirection === 'asc' ? 'ascending' : 'descending';
  };

  // Render sort indicator
  const renderSortIndicator = (field: string) => {
    if (sortField !== field) {
      return <ArrowsUpDownIcon className="ml-1 h-4 w-4 text-gray-400" />;
    }
    
    return sortDirection === 'asc' 
      ? <ArrowUpIcon className="ml-1 h-4 w-4 text-indigo-500" />
      : <ArrowDownIcon className="ml-1 h-4 w-4 text-indigo-500" />;
  };

  // Loading state
  if (isLoading) {
    return (
      <div className="mt-6 flex justify-center items-center h-64">
        <div className="animate-pulse flex flex-col items-center">
          <div className="h-12 w-12 bg-dive25-200 rounded-full mb-4"></div>
          <div className="h-4 w-48 bg-dive25-100 rounded mb-2"></div>
          <div className="h-3 w-32 bg-dive25-50 rounded"></div>
        </div>
      </div>
    );
  }

  // Error state
  if (error) {
    return (
      <div className="mt-6 flex justify-center items-center h-64">
        <div className="text-center">
          <ExclamationCircleIcon className="h-12 w-12 text-red-500 mx-auto mb-4" />
          <h3 className="text-lg font-medium text-gray-900 mb-2">
            {t('documents:errorLoadingDocuments')}
          </h3>
          <p className="text-sm text-gray-500 mb-4">
            {error.message || t('documents:unknownError')}
          </p>
          {onRetry && (
            <button
              onClick={onRetry}
              className="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-dive25-600 hover:bg-dive25-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-dive25-500"
            >
              {t('common:retry')}
            </button>
          )}
        </div>
      </div>
    );
  }

  // Empty state
  if (documents.length === 0) {
    return (
      <div className="mt-6 flex justify-center items-center h-64 border-2 border-dashed border-gray-200 rounded-lg">
        <div className="text-center">
          <DocumentIcon className="h-12 w-12 text-gray-400 mx-auto mb-4" />
          <h3 className="text-lg font-medium text-gray-900 mb-2">
            {t('documents:noDocumentsFound')}
          </h3>
          <p className="text-sm text-gray-500">
            {t('documents:noDocumentsDescription')}
          </p>
        </div>
      </div>
    );
  }

  return (
    <div aria-live="polite">
      <div className="overflow-x-auto">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th 
                scope="col" 
                className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer hover:bg-gray-100 select-none"
                onClick={() => handleSortClick('filename')}
                aria-sort={getAriaSortValue('filename')}
              >
                <div className="flex items-center">
                  {t('documents:filename')}
                  {renderSortIndicator('filename')}
                </div>
              </th>
              <th 
                scope="col" 
                className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer hover:bg-gray-100 select-none"
                onClick={() => handleSortClick('classification')}
                aria-sort={getAriaSortValue('classification')}
              >
                <div className="flex items-center">
                  {t('documents:classification')}
                  {renderSortIndicator('classification')}
                </div>
              </th>
              <th 
                scope="col" 
                className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer hover:bg-gray-100 select-none"
                onClick={() => handleSortClick('uploadDate')}
                aria-sort={getAriaSortValue('uploadDate')}
              >
                <div className="flex items-center">
                  {t('documents:uploadDate')}
                  {renderSortIndicator('uploadDate')}
                </div>
              </th>
              <th 
                scope="col" 
                className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer hover:bg-gray-100 select-none"
                onClick={() => handleSortClick('size')}
                aria-sort={getAriaSortValue('size')}
              >
                <div className="flex items-center">
                  {t('documents:size')}
                  {renderSortIndicator('size')}
                </div>
              </th>
              <th 
                scope="col" 
                className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer hover:bg-gray-100 select-none"
                onClick={() => handleSortClick('creator')}
                aria-sort={getAriaSortValue('creator')}
              >
                <div className="flex items-center">
                  {t('documents:creator')}
                  {renderSortIndicator('creator')}
                </div>
              </th>
              <th scope="col" className="relative px-6 py-3">
                <span className="sr-only">{t('common:actions.title', 'Actions')}</span>
              </th>
            </tr>
          </thead>
          <tbody className="bg-white divide-y divide-gray-200">
            {documents.map((document) => (
              <tr 
                key={document._id} 
                className={twMerge(
                  "hover:bg-gray-50 transition-colors duration-150",
                  highlightedRow === document._id ? "bg-indigo-50" : ""
                )}
                onMouseEnter={() => setHighlightedRow(document._id)}
                onMouseLeave={() => setHighlightedRow(null)}
              >
                <td className="px-6 py-4 whitespace-nowrap">
                  <div className="flex items-center">
                    <div className="flex-shrink-0 mr-3">
                      {getFileIcon(document.filename)}
                    </div>
                    <Link 
                      href={`/documents/${document._id}`}
                      className="text-indigo-600 hover:text-indigo-900 font-medium truncate max-w-xs block"
                      aria-label={`${t('documents:view')} ${document.filename}`}
                    >
                      {document.filename}
                    </Link>
                  </div>
                </td>
                <td className="px-6 py-4 whitespace-nowrap">
                  <Badge 
                    variant="clearance" 
                    level={document.metadata.classification}
                    >
                      {document.metadata.classification}
                  </Badge>
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                  <time dateTime={new Date(document.uploadDate).toISOString()}>
                    {formatDate(new Date(document.uploadDate))}
                  </time>
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                  {formatFileSize(document.size)}
                </td>
                <td className="px-6 py-4 whitespace-nowrap">
                  <div className="flex items-center">
                    <div className="text-sm font-medium text-gray-900">
                      {document.metadata.creator.name}
                    </div>
                    <div className="ml-2 text-xs text-gray-500">
                      ({document.metadata.creator.country})
                    </div>
                  </div>
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                  <div className="flex justify-end space-x-3">
                    <Link
                      href={`/documents/${document._id}`}
                      className="text-indigo-600 hover:text-indigo-900 transition-colors"
                      title={t('common:actions.view', 'View')}
                    >
                      <EyeIcon className="h-5 w-5" />
                      <span className="sr-only">{t('common:actions.view')}</span>
                    </Link>
                    {/* Show these actions based on permissions if needed */}
                    {/* <button
                      className="text-gray-600 hover:text-blue-700 transition-colors"
                      title={t('common:actions.edit', 'Edit')}
                    >
                      <PencilIcon className="h-5 w-5" />
                      <span className="sr-only">{t('common:actions.edit')}</span>
                    </button>
                    <button
                      className="text-gray-600 hover:text-red-700 transition-colors"
                      title={t('common:actions.delete', 'Delete')}
                    >
                      <TrashIcon className="h-5 w-5" />
                      <span className="sr-only">{t('common:actions.delete')}</span>
                    </button> */}
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {pagination && (
        <div className="px-6 py-4 border-t border-gray-200 bg-gray-50">
          <Pagination
            currentPage={pagination.page}
            totalPages={pagination.totalPages}
            onPageChange={onPageChange}
          />
          {pagination.total > 0 && (
            <div className="mt-2 text-sm text-gray-500 text-center">
              {t('documents:showingItems', {
                start: (pagination.page - 1) * pagination.limit + 1,
                end: Math.min(pagination.page * pagination.limit, pagination.total),
                total: pagination.total
              })}
            </div>
          )}
        </div>
      )}
    </div>
  );
}