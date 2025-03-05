// frontend/src/pages/documents/upload.tsx
import { useState } from 'react';
import { useRouter } from 'next/router';
import Head from 'next/head';
import { useTranslation } from 'next-i18next';
import { serverSideTranslations } from 'next-i18next/serverSideTranslations';
import { GetServerSideProps } from 'next';
import { withAuth } from '@/components/hoc/withAuth';
import { SecurityBanner } from '@/components/security/SecurityBanner';
import { DocumentUploadForm } from '@/components/documents/DocumentUploadForm';
import toast from 'react-hot-toast';

// Define the document upload data interface
interface DocumentUploadData {
  file: File;
  title: string;
  description: string;
  classification: string;
}

function DocumentUpload() {
  const { t } = useTranslation(['common', 'documents']);
  const router = useRouter();

  return (
    <>
      <Head>
        <title>{t('documents:uploadTitle')} | DIVE25</title>
      </Head>

      <div className="container mx-auto px-4 py-8">
        <SecurityBanner />
        
        <div className="max-w-3xl mx-auto">
          <h1 className="text-2xl font-bold mb-6">
            {t('documents:upload')}
          </h1>
          
          <DocumentUploadForm 
            onSuccess={(documentId) => {
              toast.success(t('documents:uploadSuccess'));
              router.push(`/documents/${documentId}`);
            }}
            onError={(error) => {
              toast.error(t('documents:uploadError'));
              console.error('Upload error:', error);
            }}
            resetAfterSubmit={true}
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