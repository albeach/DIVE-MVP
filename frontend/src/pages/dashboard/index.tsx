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
  const { t } = useTranslation(['common', 'translation']);

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

        {/* Main Application Section */}
        <div className="mb-10">
          <h2 className="text-xl font-semibold text-gray-800 mb-4">Main Application</h2>
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
        </div>

        {/* Admin Dashboards Section */}
        <div className="mb-10">
          <h2 className="text-xl font-semibold text-gray-800 mb-4">Admin Dashboards</h2>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {/* Grafana */}
            <div className="bg-white overflow-hidden shadow rounded-lg divide-y divide-gray-200">
              <div className="px-6 py-5 bg-orange-50">
                <h3 className="text-lg font-medium text-orange-800">Grafana</h3>
              </div>
              <div className="px-6 py-5">
                <p className="text-gray-700 mb-4">
                  Visualize system metrics and performance
                </p>
                <a 
                  href="https://grafana.dive25.local:8443"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
                >
                  Open Grafana
                </a>
              </div>
            </div>

            {/* Prometheus */}
            <div className="bg-white overflow-hidden shadow rounded-lg divide-y divide-gray-200">
              <div className="px-6 py-5 bg-red-50">
                <h3 className="text-lg font-medium text-red-800">Prometheus</h3>
              </div>
              <div className="px-6 py-5">
                <p className="text-gray-700 mb-4">
                  Monitor system metrics and alerts
                </p>
                <a 
                  href="https://prometheus.dive25.local:8443"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
                >
                  Open Prometheus
                </a>
              </div>
            </div>

            {/* Kong Admin */}
            <div className="bg-white overflow-hidden shadow rounded-lg divide-y divide-gray-200">
              <div className="px-6 py-5 bg-cyan-50">
                <h3 className="text-lg font-medium text-cyan-800">Kong Admin</h3>
              </div>
              <div className="px-6 py-5">
                <p className="text-gray-700 mb-4">
                  Manage API gateway and services
                </p>
                <a 
                  href="https://kong.dive25.local:8443/konga"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
                >
                  Open Konga
                </a>
              </div>
            </div>
          </div>
        </div>

        {/* Database Management Section */}
        <div className="mb-10">
          <h2 className="text-xl font-semibold text-gray-800 mb-4">Database Management</h2>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {/* MongoDB Express */}
            <div className="bg-white overflow-hidden shadow rounded-lg divide-y divide-gray-200">
              <div className="px-6 py-5 bg-green-50">
                <h3 className="text-lg font-medium text-green-800">MongoDB Express</h3>
              </div>
              <div className="px-6 py-5">
                <p className="text-gray-700 mb-4">
                  Manage MongoDB databases and collections
                </p>
                <a 
                  href="https://mongo-express.dive25.local:8443"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
                >
                  Open MongoDB Express
                </a>
              </div>
            </div>

            {/* LDAP Admin */}
            <div className="bg-white overflow-hidden shadow rounded-lg divide-y divide-gray-200">
              <div className="px-6 py-5 bg-indigo-50">
                <h3 className="text-lg font-medium text-indigo-800">LDAP Admin</h3>
              </div>
              <div className="px-6 py-5">
                <p className="text-gray-700 mb-4">
                  Manage LDAP directory users and groups
                </p>
                <a 
                  href="https://phpldapadmin.dive25.local:8443"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
                >
                  Open phpLDAPadmin
                </a>
              </div>
            </div>
          </div>
        </div>

        {/* Authentication Section */}
        <div className="mb-10">
          <h2 className="text-xl font-semibold text-gray-800 mb-4">Authentication & Security</h2>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {/* Keycloak Admin */}
            <div className="bg-white overflow-hidden shadow rounded-lg divide-y divide-gray-200">
              <div className="px-6 py-5 bg-blue-50">
                <h3 className="text-lg font-medium text-blue-800">Keycloak Admin</h3>
              </div>
              <div className="px-6 py-5">
                <p className="text-gray-700 mb-4">
                  Manage users, roles, and authentication
                </p>
                <a 
                  href="https://keycloak.dive25.local:8443/admin"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
                >
                  Open Keycloak Admin
                </a>
              </div>
            </div>

            {/* OPA Policy Admin */}
            <div className="bg-white overflow-hidden shadow rounded-lg divide-y divide-gray-200">
              <div className="px-6 py-5 bg-yellow-50">
                <h3 className="text-lg font-medium text-yellow-800">OPA Policies</h3>
              </div>
              <div className="px-6 py-5">
                <p className="text-gray-700 mb-4">
                  Manage authorization policies
                </p>
                <a 
                  href="https://opa.dive25.local:8443"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
                >
                  Access OPA
                </a>
              </div>
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
      ...(await serverSideTranslations(locale || 'en', ['common', 'translation'])),
    },
  };
};

// Wrap with auth HOC to ensure authentication
export default withAuth(Dashboard); 