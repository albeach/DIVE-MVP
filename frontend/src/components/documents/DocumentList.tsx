// frontend/src/components/documents/DocumentList.tsx
import { useTranslation } from 'next-i18next';
import Link from 'next/link';
import { Document, PaginationInfo } from '@/types/document';
import { formatDate, formatFileSize } from '@/utils/formatters';
import { Badge } from '@/components/ui/Badge';
import { Pagination } from '@/components/ui/Pagination';

interface DocumentListProps {
  documents: Document[];
  pagination?: PaginationInfo;
  onPageChange: (page: number) => void;
}

export function DocumentList({ documents, pagination, onPageChange }: DocumentListProps) {
  const { t } = useTranslation(['common', 'documents']);

  return (
    <div className="mt-6">
      <div className="overflow-x-auto">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                {t('documents:filename')}
              </th>
              <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                {t('documents:classification')}
              </th>
              <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                {t('documents:uploadDate')}
              </th>
              <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                {t('documents:size')}
              </th>
              <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                {t('documents:creator')}
              </th>
            </tr>
          </thead>
          <tbody className="bg-white divide-y divide-gray-200">
            {documents.map((document) => (
              <tr key={document._id} className="hover:bg-gray-50">
                <td className="px-6 py-4 whitespace-nowrap">
                  <Link 
                    href={`/documents/${document._id}`}
                    className="text-dive25-600 hover:text-dive25-900 font-medium"
                  >
                    {document.filename}
                  </Link>
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
                  {formatDate(new Date(document.uploadDate))}
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
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {pagination && (
        <div className="mt-6">
          <Pagination
            currentPage={pagination.page}
            totalPages={pagination.totalPages}
            onPageChange={onPageChange}
          />
        </div>
      )}
    </div>
  );
}