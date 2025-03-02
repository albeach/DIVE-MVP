// frontend/src/pages/documents/[id].tsx
import { useState } from 'react';
import { useRouter } from 'next/router';
import Head from 'next/head';
import Link from 'next/link';
import { useTranslation } from 'next-i18next';
import { serverSideTranslations } from 'next-i18next/serverSideTranslations';
import { GetServerSideProps } from 'next';
import { withAuth } from '@/components/hoc/withAuth';
import { useDocument } from '@/hooks/useDocument';
import { SecurityBanner } from '@/components/security/SecurityBanner';
import { DocumentViewer } from '@/components/documents/DocumentViewer';
import { DocumentMetadata } from '@/components/documents/DocumentMetadata';
import { Button } from '@/components/ui/Button';
import { Spinner } from '@/components/ui/Spinner';
import { ArrowLeftIcon, ArrowDownTrayIcon, PencilIcon, TrashIcon } from '@heroicons/react/24/outline';
import { useAuth } from '@/context/auth-context';
import toast from 'react-hot-toast';
import { apiClient } from '@/services/apiClient';

function DocumentDetail() {
  const { t } = useTranslation(['common', 'documents']);
  const router = useRouter();
  const { id } = router.query;
  const { user } = useAuth();
  const [isDeleting, setIsDeleting] = useState(false);
  
  // Fetch document details
  const { 
    data: document, 
    isLoading, 
    isError, 
    error 
  } = useDocument(id as string);

  // Check if current user is document owner or admin
  const canEdit = user && document && (
    document.metadata.creator.id === user.uniqueId || 
    (user.roles && user.roles.includes('admin'))
  );

  // Handle document download
  const handleDownload = async () => {
    try {
      const response = await apiClient.get(`/documents/${id}/download`, {
        responseType: 'blob'
      });
      
      // Create download link
      const url = window.URL.createObjectURL(new Blob([response.data]));
      const link = window.document.createElement('a');
      link.href = url;
      link.setAttribute('download', document?.filename || 'document');
      window.document.body.appendChild(link);
      link.click();
      
      // Cleanup
      link.parentNode?.removeChild(link);
      window.URL.revokeObjectURL(url);
    } catch (error) {
      console.error('Download error:', error);
      toast.error(t('errors.failedToDownloadDocument'));
    }
  };

  // Handle document deletion
  const handleDelete = async () => {
    if (!window.confirm(t('documents:confirmDelete'))) {
      return;
    }
    
    setIsDeleting(true);
    try {
      await apiClient.delete(`/documents/${id}`);
      toast.success(t('documents:deleteSuccess'));
      router.push('/documents');
    } catch (error) {
      console.error('Delete error:', error);
      toast.error(t('errors.failedToDeleteDocument'));
      setIsDeleting(false);
    }
  };

  if (isLoading) {
    return (
      <div className="flex justify-center my-12">
        <Spinner size="lg" />
      </div>
    );
  }

  if (isError) {
    return (
      <div className="rounded-md bg-red-50 p-4 my-6">
        <div className="flex">
          <div className="ml-3">
            <h3 className="text-sm font-medium text-red-800">
              {t('errors.failedToLoadDocument')}
            </h3>
            <div className="mt-2 text-sm text-red-700">
              <p>{error instanceof Error ? error.message : t('errors.unknownError')}</p>
            </div>
          </div>
        </div>
      </div>
    );
  }

  if (!document) {
    return (
      <div className="text-center my-12">
        <p className="text-gray-500">{t('documents:documentNotFound')}</p>
      </div>
    );
  }

  return (
    <>
      <Head>
        <title>{document.filename} | DIVE25</title>
      </Head>

      <SecurityBanner 
        classification={document.metadata.classification}
        caveats={document.metadata.caveats}
      />

      <div className="px-4 sm:px-6 lg:px-8 py-6">
        <div className="mb-6 flex items-center justify-between">
          <Button
            as={Link}
            href="/documents"
            variant="secondary"
            size="sm"
          >
            <ArrowLeftIcon className="h-4 w-4 mr-2" />
            {t('common:back')}
          </Button>
          
          <div className="flex gap-2">
            <Button
              onClick={handleDownload}
              variant="primary"
              size="sm"
            >
              <ArrowDownTrayIcon className="h-4 w-4 mr-2" />
              {t('documents:download')}
            </Button>
            
            {canEdit && (
              <>
                <Button
                  as={Link}
                  href={`/documents/${id}/edit`}
                  variant="secondary"
                  size="sm"
                >
                  <PencilIcon className="h-4 w-4 mr-2" />
                  {t('common:edit')}
                </Button>
                
                <Button
                  onClick={handleDelete}
                  variant="danger"
                  size="sm"
                  isLoading={isDeleting}
                >
                  <TrashIcon className="h-4 w-4 mr-2" />
                  {t('common:delete')}
                </Button>
              </>
            )}
          </div>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <div className="lg:col-span-2">
            <DocumentViewer document={document} />
          </div>
          
          <div>
            <DocumentMetadata document={document} />
          </div>
        </div>
      </div>
    </>
  );
}

export const getServerSideProps: GetServerSideProps = async ({ locale, params }) => {
  // Check if the id parameter exists
  if (!params?.id) {
    return {
      notFound: true
    };
  }

  return {
    props: {
      ...(await serverSideTranslations(locale || 'en', ['common', 'documents'])),
    },
  };
};

export default withAuth(DocumentDetail);