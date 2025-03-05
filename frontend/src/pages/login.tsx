import { useEffect } from 'react';
import { useRouter } from 'next/router';
import { useAuth } from '@/context/auth-context';
import Head from 'next/head';
import { useTranslation } from 'next-i18next';
import { serverSideTranslations } from 'next-i18next/serverSideTranslations';
import { GetStaticProps } from 'next';

export default function LoginPage() {
  const { login, isAuthenticated, isLoading } = useAuth();
  const router = useRouter();
  const { t } = useTranslation('common');
  
  // Redirect if already authenticated
  useEffect(() => {
    if (isAuthenticated && !isLoading) {
      router.push('/');
    }
  }, [isAuthenticated, isLoading, router]);
  
  // Initiate login
  const handleLogin = () => {
    login();
  };
  
  if (isLoading) {
    return <div className="flex items-center justify-center min-h-screen">
      <div className="animate-spin rounded-full h-12 w-12 border-t-2 border-b-2 border-blue-600"></div>
    </div>;
  }
  
  return (
    <>
      <Head>
        <title>{t('app.name')} - Login</title>
      </Head>
      
      <div className="flex items-center justify-center min-h-screen bg-gray-100">
        <div className="max-w-md w-full p-8 bg-white rounded-lg shadow-md">
          <div className="text-center mb-6">
            <div className="text-3xl font-bold text-blue-800">{t('app.name')}</div>
          </div>
          
          <h1 className="text-2xl font-bold text-center mb-4">
            {t('app.name')} Secure Document System
          </h1>
          
          <p className="text-center text-gray-600 mb-6">
            Sign in to access the secure document repository
          </p>
          
          <div className="flex flex-col items-center">
            <button 
              onClick={handleLogin}
              className="w-full py-2 px-4 bg-blue-600 hover:bg-blue-700 text-white font-medium rounded-md"
            >
              Sign in with Keycloak
            </button>
            
            <div className="mt-4 text-sm text-gray-500">
              This will redirect you to our secure authentication service
            </div>
          </div>
        </div>
      </div>
    </>
  );
}

export const getStaticProps: GetStaticProps = async ({ locale }) => {
  return {
    props: {
      ...(await serverSideTranslations(locale || 'en', ['common'])),
    },
  };
}; 