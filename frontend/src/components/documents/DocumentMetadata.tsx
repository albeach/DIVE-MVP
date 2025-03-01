// frontend/src/components/documents/DocumentMetadata.tsx
import { useTranslation } from 'next-i18next';
import { Document } from '@/types/document';
import { formatDate } from '@/utils/formatters';
import { Badge } from '@/components/ui/Badge';

interface DocumentMetadataProps {
  document: Document;
}

export function DocumentMetadata({ document }: DocumentMetadataProps) {
  const { t } = useTranslation(['common', 'documents']);
  
  return (
    <div className="bg-white shadow overflow-hidden rounded-lg">
      <dl>
        <div className="px-4 py-4 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6 bg-gray-50">
          <dt className="text-sm font-medium text-gray-500">
            {t('documents:metadata.classification')}
          </dt>
          <dd className="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2">
            <Badge 
              variant="clearance" 
              level={document.metadata.classification}
            >
              {document.metadata.classification}
            </Badge>
          </dd>
        </div>
        
        <div className="px-4 py-4 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
          <dt className="text-sm font-medium text-gray-500">
            {t('documents:metadata.uploadDate')}
          </dt>
          <dd className="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2">
            {formatDate(new Date(document.uploadDate))}
          </dd>
        </div>
        
        <div className="px-4 py-4 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6 bg-gray-50">
          <dt className="text-sm font-medium text-gray-500">
            {t('documents:metadata.releasability')}
          </dt>
          <dd className="mt-1 text-sm sm:mt-0 sm:col-span-2">
            {document.metadata.releasability && document.metadata.releasability.length > 0 ? (
              <div className="flex flex-wrap gap-2">
                {document.metadata.releasability.map((country) => (
                  <Badge key={country} variant="secondary">
                    {country}
                  </Badge>
                ))}
              </div>
            ) : (
              <span className="text-gray-500">—</span>
            )}
          </dd>
        </div>
        
        <div className="px-4 py-4 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
          <dt className="text-sm font-medium text-gray-500">
            {t('documents:metadata.caveats')}
          </dt>
          <dd className="mt-1 text-sm sm:mt-0 sm:col-span-2">
            {document.metadata.caveats && document.metadata.caveats.length > 0 ? (
              <div className="flex flex-wrap gap-2">
                {document.metadata.caveats.map((caveat) => (
                  <Badge key={caveat} variant="secondary">
                    {caveat}
                  </Badge>
                ))}
              </div>
            ) : (
              <span className="text-gray-500">—</span>
            )}
          </dd>
        </div>
        
        <div className="px-4 py-4 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6 bg-gray-50">
          <dt className="text-sm font-medium text-gray-500">
            {t('documents:metadata.coi')}
          </dt>
          <dd className="mt-1 text-sm sm:mt-0 sm:col-span-2">
            {document.metadata.coi && document.metadata.coi.length > 0 ? (
              <div className="flex flex-wrap gap-2">
                {document.metadata.coi.map((coi) => (
                  <Badge key={coi} variant="tertiary">
                    {coi}
                  </Badge>
                ))}
              </div>
            ) : (
              <span className="text-gray-500">—</span>
            )}
          </dd>
        </div>
        
        <div className="px-4 py-4 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
          <dt className="text-sm font-medium text-gray-500">
            {t('documents:metadata.creator')}
          </dt>
          <dd className="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2">
            <div>
              {document.metadata.creator.name}
            </div>
            <div className="text-sm text-gray-500">
              {document.metadata.creator.organization}, {document.metadata.creator.country}
            </div>
          </dd>
        </div>
        
        <div className="px-4 py-4 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6 bg-gray-50">
          <dt className="text-sm font-medium text-gray-500">
            {t('documents:metadata.fileInfo')}
          </dt>
          <dd className="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2">
            <div>
              {document.mimeType}
            </div>
            <div className="text-sm text-gray-500">
              {formatFileSize(document.size)}
            </div>
          </dd>
        </div>
      </dl>
    </div>
  );
}