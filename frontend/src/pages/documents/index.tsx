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
import { PlusIcon } from '@heroicons/react/24/outline';

function Documents() {
  const { t } = useTranslation(['common', 'documents']);
  const [filters, setFilters] = useState<DocumentFilterParams>({
    page: 1,
    limit: 10,
    sort: { uploadDate: -1 }
  });

  const { 
    data, 
    isLoading, 
    isError, 
    error 
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
  };

  return (
    <>
      <Head>
        <title>{t('documents:title')} | DIVE25</title>
      </Head>

      <SecurityBanner />

      <div className="px-4 sm:px-6 lg:px-8 py-6">
        <div className="sm:flex sm:items-center sm:justify-between">
          <h1 className="text-2xl font-bold text-gray-900">{t('documents:title')}</h1>
          <Button
            as={Link}
            href="/documents/upload"
            variant="primary"
            className="mt-3 sm:mt-0"
          >
            <PlusIcon className="h-5 w-5 mr-2" />
            {t('documents:upload')}
          </Button>
        </div>

        <DocumentFilter 
          filters={filters} 
          onFilterChange={handleFilterChange} 
        />

        {isLoading ? (
          <div className="flex justify-center my-12">
            <Spinner size="lg" />
          </div>
        ) : isError ? (
          <div className="rounded-md bg-red-50 p-4 my-6">
            <div className="flex">
              <div className="ml-3">
                <h3 className="text-sm font-medium text-red-800">
                  {t('errors.failedToLoadDocuments')}
                </h3>
                <div className="mt-2 text-sm text-red-700">
                  <p>{error instanceof Error ? error.message : t('errors.unknownError')}</p>
                </div>
              </div>
            </div>
          </div>
        ) : data?.documents.length === 0 ? (
          <div className="text-center my-12">
            <p className="mt-1 text-gray-500">
              {t('documents:noDocumentsFound')}
            </p>
          </div>
        ) : (
          <DocumentList
            documents={data?.documents || []}
            pagination={data?.pagination}
            onPageChange={handlePageChange}
          />
        )}
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