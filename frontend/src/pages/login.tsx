import { useEffect } from 'react';
import { useRouter } from 'next/router';
import { useAuth } from '@/context/auth-context';
import Head from 'next/head';
import Image from 'next/image';
import { useTranslation } from 'next-i18next';
import { serverSideTranslations } from 'next-i18next/serverSideTranslations';
import { GetStaticProps } from 'next';

export default function LoginPage() {
  const { login, isAuthenticated, isLoading } = useAuth();
  const router = useRouter();
  const { t } = useTranslation(['common', 'translation']);
  
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
    return (
      <div className="flex items-center justify-center min-h-screen bg-gradient-to-r from-primary-900 to-primary-800">
        <div className="animate-spin rounded-full h-12 w-12 border-t-2 border-b-2 border-white"></div>
      </div>
    );
  }
  
  return (
    <>
      <Head>
        <title>{t('app.name')} - Login</title>
      </Head>
      
      <div className="flex items-center justify-center min-h-screen bg-gradient-to-br from-primary-900 via-primary-800 to-primary-700 text-white">
        {/* Background decorative elements */}
        <div className="absolute inset-0 overflow-hidden opacity-10">
          <div className="absolute top-20 -right-40 w-80 h-80 rounded-full bg-primary-500 blur-3xl"></div>
          <div className="absolute -top-20 -left-20 w-80 h-80 rounded-full bg-primary-400 blur-3xl"></div>
          <div className="absolute bottom-10 right-20 w-60 h-60 rounded-full bg-primary-300 blur-3xl"></div>
        </div>
        
        <div className="max-w-md w-full p-8 bg-white/10 backdrop-blur-md border border-white/20 rounded-md shadow-xl relative z-10">
          <div className="text-center mb-8">
            <div className="flex justify-center mb-4">
              <div className="w-16 h-16 relative overflow-hidden rounded-md bg-white/10 p-2 backdrop-blur-sm border border-white/20 shadow-md">
                <Image 
                  src="/assets/dive25-logo.svg" 
                  alt={t('app.name')} 
                  width={48} 
                  height={48}
                  className="transition-all duration-300"
                />
              </div>
            </div>
            <h1 className="text-3xl font-bold text-white mb-2">
              {t('app.name')}
            </h1>
            <h2 className="text-xl font-medium text-white/90">
              Secure Document System
            </h2>
          </div>
          
          <div className="bg-white/5 backdrop-blur-sm border border-white/10 rounded-md p-5 mb-6">
            <p className="text-center text-white/90 text-base mb-0">
              Sign in to access the secure document repository
            </p>
          </div>
          
          <div className="flex flex-col items-center">
            <button 
              onClick={handleLogin}
              className="w-full py-3 px-4 bg-white/10 hover:bg-white/20 text-white font-medium rounded-md border border-white/10 hover:border-white/20 transition-all duration-300 shadow-md backdrop-blur-sm text-base"
            >
              <div className="flex items-center justify-center">
                <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
                </svg>
                Sign in with Keycloak
              </div>
            </button>
            
            <div className="mt-5 text-sm text-white/70 bg-white/5 backdrop-blur-sm border border-white/10 rounded-md p-3 text-center">
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
      ...(await serverSideTranslations(locale || 'en', ['common', 'translation'])),
    },
  };
}; 