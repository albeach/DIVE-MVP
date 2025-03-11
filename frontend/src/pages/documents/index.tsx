// frontend/src/pages/documents/index.tsx
import { useEffect, useState } from 'react';
import Head from 'next/head';
import { useTranslation } from 'next-i18next';
import { serverSideTranslations } from 'next-i18next/serverSideTranslations';
import { GetServerSideProps } from 'next';
import { useDocuments } from '@/hooks/useDocuments';
import { DocumentList } from '@/components/documents/DocumentList';
import { DocumentFilter } from '@/components/documents/DocumentFilter';
import { Button } from '@/components/ui/Button';
import { Spinner } from '@/components/ui/Spinner';
import { withAuth } from '@/components/hoc/withAuth';
import { SecurityBanner } from '@/components/security/SecurityBanner';
import { DocumentFilterParams } from '@/types/document';
import Link from 'next/link';
import { PlusIcon, ArrowPathIcon, DocumentIcon, ExclamationCircleIcon } from '@heroicons/react/24/outline';

function Documents() {
  const { t } = useTranslation(['common', 'documents']);
  const [filters, setFilters] = useState<DocumentFilterParams>({
    page: 1,
    limit: 10,
    sort: { uploadDate: -1 }
  });
  const [refreshKey, setRefreshKey] = useState(0);

  const { 
    data, 
    isLoading, 
    isError, 
    error,
    refetch
  } = useDocuments(filters);

  // Reset to first page when filters change (except pagination)
  useEffect(() => {
    setFilters(prevFilters => ({
      ...prevFilters,
      page: 1
    }));
  }, [
    filters.classification,
    filters.country, 
    filters.fromDate, 
    filters.toDate, 
    filters.search
  ]);

  const handleFilterChange = (newFilters: Partial<DocumentFilterParams>) => {
    setFilters(prevFilters => ({
      ...prevFilters,
      ...newFilters
    }));
  };

  const handlePageChange = (newPage: number) => {
    setFilters(prevFilters => ({
      ...prevFilters,
      page: newPage
    }));
    // Scroll to the top of the document list
    const documentList = document.getElementById('document-list');
    if (documentList) {
      documentList.scrollIntoView({ behavior: 'smooth' });
    }
  };

  const handleRefresh = () => {
    setRefreshKey(prev => prev + 1);
    refetch();
  };

  const totalDocuments = data?.pagination?.total || 0;
  const hasFilters = !!(filters.classification || filters.country || filters.fromDate || filters.toDate || filters.search);

  return (
    <>
      <Head>
        <title>{t('documents:title')} | DIVE25</title>
      </Head>

      <SecurityBanner />

      <div className="min-h-screen bg-gray-50 pb-12">
        <div className="bg-white shadow-sm border-b border-gray-200">
          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
            <div className="sm:flex sm:items-center sm:justify-between">
              <div>
                <h1 className="text-2xl font-bold text-gray-900">{t('documents:title')}</h1>
                {totalDocuments > 0 && (
                  <p className="mt-1 text-sm text-gray-500">
                    {t('documents:totalDocuments', { count: totalDocuments })}
                  </p>
                )}
              </div>
              <div className="mt-4 sm:mt-0 flex space-x-3">
                <Button
                  onClick={handleRefresh}
                  variant="secondary"
                  className="rounded-md"
                  disabled={isLoading}
                >
                  <ArrowPathIcon className={`h-5 w-5 mr-2 ${isLoading ? 'animate-spin' : ''}`} />
                  {t('common:actions.refresh')}
                </Button>
                <Button
                  as={Link}
                  href="/documents/upload"
                  variant="primary"
                  className="rounded-md"
                >
                  <PlusIcon className="h-5 w-5 mr-2" />
                  {t('documents:upload')}
                </Button>
              </div>
            </div>
          </div>
        </div>

        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
          <DocumentFilter 
            filters={filters} 
            onFilterChange={handleFilterChange} 
          />

          <div id="document-list" className="mt-6">
            {isLoading ? (
              <div className="bg-white rounded-lg shadow px-6 py-12 flex flex-col items-center justify-center">
                <Spinner size="lg" />
                <p className="mt-4 text-sm text-gray-500">{t('common:messages.loading')}</p>
              </div>
            ) : isError ? (
              <div className="bg-white rounded-lg shadow px-6 py-12">
                <div className="rounded-md bg-red-50 p-4">
                  <div className="flex">
                    <div className="flex-shrink-0">
                      <ExclamationCircleIcon className="h-5 w-5 text-red-400" aria-hidden="true" />
                    </div>
                    <div className="ml-3">
                      <h3 className="text-sm font-medium text-red-800">
                        {t('documents:errorLoadingDocuments', 'Error loading documents')}
                      </h3>
                      <div className="mt-2 text-sm text-red-700">
                        <p>{error instanceof Error ? error.message : t('common:messages.error')}</p>
                      </div>
                      <div className="mt-4">
                        <Button
                          onClick={handleRefresh}
                          variant="primary"
                          size="sm"
                          className="rounded-md"
                        >
                          {t('common:actions.retry')}
                        </Button>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            ) : data?.documents.length === 0 ? (
              <div className="bg-white rounded-lg shadow px-6 py-12 text-center">
                <DocumentIcon className="mx-auto h-12 w-12 text-gray-400" />
                <h3 className="mt-2 text-sm font-medium text-gray-900">
                  {hasFilters 
                    ? t('documents:noDocumentsFoundFiltered', 'No documents match your filters') 
                    : t('documents:noDocumentsFound')}
                </h3>
                <p className="mt-1 text-sm text-gray-500">
                  {hasFilters 
                    ? t('documents:tryAdjustingFilters', 'Try adjusting your filters or uploading a new document.')
                    : t('documents:getStartedUploading', 'Get started by uploading your first document.')}
                </p>
                <div className="mt-6">
                  {hasFilters ? (
                    <Button
                      onClick={() => handleFilterChange({
                        classification: undefined,
                        country: undefined,
                        fromDate: undefined,
                        toDate: undefined,
                        search: undefined
                      })}
                      variant="secondary"
                      className="rounded-md"
                    >
                      {t('documents:clearAllFilters', 'Clear all filters')}
                    </Button>
                  ) : (
                    <Button
                      as={Link}
                      href="/documents/upload"
                      variant="primary"
                      className="rounded-md"
                    >
                      <PlusIcon className="h-5 w-5 mr-2" />
                      {t('documents:upload')}
                    </Button>
                  )}
                </div>
              </div>
            ) : (
              <div className="bg-white rounded-lg shadow">
                <DocumentList
                  documents={data?.documents || []}
                  pagination={data?.pagination}
                  onPageChange={handlePageChange}
                />
              </div>
            )}
          </div>
        </div>
      </div>
    </>
  );
}

export const getServerSideProps: GetServerSideProps = async ({ locale, req }) => {
  // Server-side authentication check would go here
  // if using getServerSideProps for authenticated routes

  return {
    props: {
      ...(await serverSideTranslations(locale || 'en', ['common', 'documents'])),
    },
  };
};

export default withAuth(Documents);