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
import { DocumentIcon } from '@heroicons/react/24/outline';
import { CheckCircleIcon } from '@heroicons/react/24/solid';
import toast from 'react-hot-toast';
import Link from 'next/link';

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
  const [uploadSuccess, setUploadSuccess] = useState(false);
  const [documentId, setDocumentId] = useState<string | null>(null);

  const handleUploadSuccess = (id: string) => {
    setDocumentId(id);
    setUploadSuccess(true);
    toast.success(t('documents:uploadSuccess'));
  };

  const handleUploadError = (error: Error) => {
    toast.error(t('documents:uploadError'));
    console.error('Upload error:', error);
  };

  return (
    <>
      <Head>
        <title>{t('documents:uploadTitle')} | DIVE25</title>
      </Head>

      <div className="min-h-screen bg-gray-50">
        <SecurityBanner />
        
        <main className="py-10">
          <div className="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8">
            {/* Header */}
            <div className="md:flex md:items-center md:justify-between mb-8">
              <div className="flex-1 min-w-0">
                <h1 className="text-2xl font-bold text-gray-900 sm:text-3xl">
                  {t('documents:upload')}
                </h1>
                <p className="mt-2 text-sm text-gray-600">
                  {t('documents:uploadDescription', 'Upload a document to the secure document repository')}
                </p>
              </div>
              <div className="mt-4 flex md:mt-0 md:ml-4">
                <Link 
                  href="/documents" 
                  className="inline-flex items-center px-4 py-2 border border-gray-300 bg-white rounded-md shadow-sm text-sm font-medium text-gray-700 hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
                >
                  {t('common:backToDocuments')}
                </Link>
              </div>
            </div>

            {/* Upload Form */}
            <div className="bg-white shadow-sm rounded-lg overflow-hidden mb-8">
              {uploadSuccess && documentId ? (
                <div className="p-6">
                  <div className="rounded-md bg-green-50 p-4 mb-6">
                    <div className="flex">
                      <div className="flex-shrink-0">
                        <CheckCircleIcon className="h-5 w-5 text-green-400" aria-hidden="true" />
                      </div>
                      <div className="ml-3">
                        <h3 className="text-sm font-medium text-green-800">
                          {t('documents:uploadSuccessTitle')}
                        </h3>
                        <div className="mt-2 text-sm text-green-700">
                          <p>
                            {t('documents:uploadSuccessMessage')}
                          </p>
                        </div>
                        <div className="mt-4">
                          <div className="-mx-2 -my-1.5 flex">
                            <button
                              type="button"
                              onClick={() => {
                                router.push(`/documents/${documentId}`);
                              }}
                              className="px-4 py-1.5 mr-3 bg-green-50 rounded-md text-sm font-medium text-green-800 hover:bg-green-100 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-green-500"
                            >
                              {t('documents:viewDocument')}
                            </button>
                            <button
                              type="button"
                              onClick={() => {
                                setUploadSuccess(false);
                                setDocumentId(null);
                              }}
                              className="px-4 py-1.5 bg-green-50 rounded-md text-sm font-medium text-green-800 hover:bg-green-100 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-green-500"
                            >
                              {t('documents:uploadAnother')}
                            </button>
                          </div>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              ) : (
                <DocumentUploadForm
                  onSuccess={handleUploadSuccess}
                  onError={handleUploadError}
                  resetAfterSubmit={false}
                />
              )}
            </div>

            {/* Help Section */}
            <div className="bg-white shadow-sm rounded-lg overflow-hidden">
              <div className="px-4 py-5 sm:p-6">
                <h3 className="text-lg leading-6 font-medium text-gray-900">
                  {t('documents:uploadHelpTitle', 'Upload Guidelines')}
                </h3>
                <div className="mt-2 max-w-xl text-sm text-gray-500">
                  <ul className="list-disc space-y-2 pl-5 mt-3">
                    <li>
                      {t('documents:uploadHelpSizeLimit', 'Maximum file size is 100MB')}
                    </li>
                    <li>
                      {t('documents:uploadHelpFormats', 'Supported formats include PDF, Word, Excel, PowerPoint, and common image types')}
                    </li>
                    <li>
                      {t('documents:uploadHelpClassification', 'Classification is required and will be displayed in the document banner')}
                    </li>
                    <li>
                      {t('documents:uploadHelpSecurity', 'Documents are secured according to their classification and access controls')}
                    </li>
                  </ul>
                </div>
              </div>
            </div>
          </div>
        </main>
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