// frontend/src/pages/documents/upload.tsx
import { useState } from 'react';
import Head from 'next/head';
import { useRouter } from 'next/router';
import { useTranslation } from 'next-i18next';
import { serverSideTranslations } from 'next-i18next/serverSideTranslations';
import { GetServerSideProps } from 'next';
import { withAuth } from '@/components/hoc/withAuth';
import { SecurityBanner } from '@/components/security/SecurityBanner';
import { DocumentUploadForm } from '@/components/documents/DocumentUploadForm';
import { Button } from '@/components/ui/Button';
import { ArrowLeftIcon } from '@heroicons/react/24/outline';
import Link from 'next/link';
import toast from 'react-hot-toast';
import { useDocumentUpload } from '@/hooks/useDocumentUpload';
import { DocumentUploadData } from '@/types/document';

function DocumentUpload() {
  const { t } = useTranslation(['common', 'documents']);
  const router = useRouter();
  const [isUploading, setIsUploading] = useState(false);
  const { uploadDocument } = useDocumentUpload();

  const handleUpload = async (data: DocumentUploadData) => {
    setIsUploading(true);
    try {
      await uploadDocument(data);
      toast.success(t('documents:uploadSuccess'));
      router.push('/documents');
    } catch (error) {
      console.error('Upload error:', error);
      toast.error(
        error instanceof Error 
          ? error.message 
          : t('documents:uploadError')
      );
    } finally {
      setIsUploading(false);
    }
  };

  return (
    <>
      <Head>
        <title>{t('documents:upload')} | DIVE25</title>
      </Head>

      <SecurityBanner />

      <div className="px-4 sm:px-6 lg:px-8 py-6">
        <div className="mb-6">
          <Button
            as={Link}
            href="/documents"
            variant="secondary"
            size="sm"
          >
            <ArrowLeftIcon className="h-4 w-4 mr-2" />
            {t('common:back')}
          </Button>
        </div>

        <div className="max-w-3xl mx-auto">
          <h1 className="text-2xl font-bold text-gray-900 mb-6">
            {t('documents:upload')}
          </h1>
          
          <DocumentUploadForm 
            onSubmit={handleUpload} 
            isUploading={isUploading} 
          />
        </div>
      </div>
    </>
  );
}

export const getServerSideProps: GetServerSideProps = async ({ locale }) => {
  return {
    props: {
      ...(await serverSideTranslations(locale || 'en', ['common', 'documents'])),
    },
  };
};

export default withAuth(DocumentUpload);