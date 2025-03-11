import { useEffect } from 'react';
import { GetServerSideProps } from 'next';
import Head from 'next/head';
import Link from 'next/link';
import { useRouter } from 'next/router';
import { useTranslation } from 'next-i18next';
import { serverSideTranslations } from 'next-i18next/serverSideTranslations';
import { useAuth } from '@/context/auth-context';
import { Button } from '@/components/ui/Button';
import { withAuth } from '@/components/hoc/withAuth';

function Dashboard() {
  const { user, isAuthenticated, isLoading } = useAuth();
  const router = useRouter();
  const { t } = useTranslation('common');

  // Redirect to login if not authenticated
  useEffect(() => {
    if (!isLoading && !isAuthenticated) {
      router.push('/login');
    }
  }, [isAuthenticated, isLoading, router]);

  // Show loading state
  if (isLoading) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="animate-spin rounded-full h-12 w-12 border-t-2 border-b-2 border-blue-600"></div>
      </div>
    );
  }

  return (
    <>
      <Head>
        <title>{t('app.name')} - Dashboard</title>
      </Head>

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-10">
        <div className="mb-8">
          <h1 className="text-3xl font-bold text-gray-900">Dashboard</h1>
          <p className="text-gray-500 mt-2">Welcome back, {user?.givenName || user?.username || 'User'}</p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {/* Documents Card */}
          <div className="bg-white overflow-hidden shadow rounded-lg divide-y divide-gray-200">
            <div className="px-6 py-5 bg-blue-50">
              <h3 className="text-lg font-medium text-blue-800">Documents</h3>
            </div>
            <div className="px-6 py-5">
              <p className="text-gray-700 mb-4">
                Access and manage your secure documents
              </p>
              <Button 
                as={Link}
                href="/documents"
                variant="primary"
              >
                View Documents
              </Button>
            </div>
          </div>

          {/* Upload Card */}
          <div className="bg-white overflow-hidden shadow rounded-lg divide-y divide-gray-200">
            <div className="px-6 py-5 bg-green-50">
              <h3 className="text-lg font-medium text-green-800">Upload</h3>
            </div>
            <div className="px-6 py-5">
              <p className="text-gray-700 mb-4">
                Upload new documents to the system
              </p>
              <Button 
                as={Link}
                href="/documents/upload"
                variant="secondary"
              >
                Upload Document
              </Button>
            </div>
          </div>

          {/* Profile Card */}
          <div className="bg-white overflow-hidden shadow rounded-lg divide-y divide-gray-200">
            <div className="px-6 py-5 bg-purple-50">
              <h3 className="text-lg font-medium text-purple-800">Profile</h3>
            </div>
            <div className="px-6 py-5">
              <p className="text-gray-700 mb-4">
                View and update your profile information
              </p>
              <Button 
                as={Link}
                href="/profile"
                variant="tertiary"
              >
                View Profile
              </Button>
            </div>
          </div>
        </div>

        {/* User Security Information */}
        {user && (
          <div className="mt-8 bg-white shadow overflow-hidden sm:rounded-lg">
            <div className="px-4 py-5 sm:px-6">
              <h3 className="text-lg leading-6 font-medium text-gray-900">
                Security Information
              </h3>
              <p className="mt-1 max-w-2xl text-sm text-gray-500">
                Your access credentials and permissions
              </p>
            </div>
            <div className="border-t border-gray-200">
              <dl>
                <div className="bg-gray-50 px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
                  <dt className="text-sm font-medium text-gray-500">Clearance</dt>
                  <dd className="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2">
                    {user.clearance || 'None'}
                  </dd>
                </div>
                <div className="bg-white px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
                  <dt className="text-sm font-medium text-gray-500">Country of Affiliation</dt>
                  <dd className="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2">
                    {user.countryOfAffiliation || 'Not Specified'}
                  </dd>
                </div>
                <div className="bg-gray-50 px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
                  <dt className="text-sm font-medium text-gray-500">Organization</dt>
                  <dd className="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2">
                    {user.organization || 'Not Specified'}
                  </dd>
                </div>
                <div className="bg-white px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
                  <dt className="text-sm font-medium text-gray-500">Roles</dt>
                  <dd className="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2">
                    {user.roles?.join(', ') || 'None'}
                  </dd>
                </div>
              </dl>
            </div>
          </div>
        )}
      </div>
    </>
  );
}

export const getServerSideProps: GetServerSideProps = async ({ locale }) => {
  return {
    props: {
      ...(await serverSideTranslations(locale || 'en', ['common'])),
    },
  };
};

// Wrap with auth HOC to ensure authentication
export default withAuth(Dashboard); 