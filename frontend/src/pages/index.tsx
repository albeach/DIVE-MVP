// frontend/src/pages/index.tsx
import Head from 'next/head';
import { GetStaticProps } from 'next';
import Link from 'next/link';
import { useAuth } from '@/context/auth-context';
import { Button } from '@/components/ui/Button';
import { useRouter } from 'next/router';
import { useTranslation } from 'next-i18next';
import { serverSideTranslations } from 'next-i18next/serverSideTranslations';

export default function Home() {
  const router = useRouter();
  const { t } = useTranslation('common');
  
  // Default to unauthenticated state
  let isAuthenticated = false;
  let login = () => {
    console.warn('Auth context not available, using fallback login function');
    // Redirect to the login page instead of calling an API endpoint
    router.push('/login');
  };
  
  // Try to use auth context, but fall back to unauthenticated state if not available
  try {
    const auth = useAuth();
    isAuthenticated = auth.isAuthenticated;
    login = auth.login;
  } catch (error) {
    console.warn('Auth context not available in Home page, using fallback auth state');
  }

  return (
    <>
      <Head>
        <title>{t('app.name')} - {t('messages.welcome')}</title>
        <meta name="description" content={t('app.description')} />
      </Head>

      <div className="flex flex-col items-center justify-center min-h-screen-navbar py-12 px-4 sm:px-6 lg:px-8">
        <div className="max-w-4xl w-full space-y-8 text-center">
          <div>
            <h1 className="text-4xl font-extrabold tracking-tight text-blue-800 sm:text-5xl md:text-6xl">
              <span className="block">{t('app.name')}</span>
              <span className="block text-blue-600">{t('app.description')}</span>
            </h1>
            <p className="mt-6 text-xl text-gray-600 max-w-2xl mx-auto">
              {t('app.description')}
            </p>
          </div>

          <div className="mt-10">
            {isAuthenticated ? (
              <div className="space-y-4">
                <p className="text-lg text-gray-600">
                  {t('messages.welcome')}
                </p>
                <div className="flex flex-col sm:flex-row space-y-4 sm:space-y-0 sm:space-x-4 justify-center">
                  <Button 
                    as={Link}
                    href="/documents"
                    variant="primary"
                    size="lg"
                  >
                    {t('navigation.documents')}
                  </Button>
                  <Button 
                    as={Link}
                    href="/documents/upload"
                    variant="secondary"
                    size="lg"
                  >
                    {t('actions.upload')}
                  </Button>
                </div>
              </div>
            ) : (
              <div className="space-y-4">
                <p className="text-lg text-gray-600">
                  Sign in to access the secure document repository
                </p>
                <Button 
                  onClick={login}
                  variant="primary"
                  size="lg"
                >
                  Sign In
                </Button>
              </div>
            )}
          </div>

          <div className="mt-12 border-t border-gray-200 pt-8">
            <p className="text-base text-gray-500">
              This system requires authentication and proper clearance to access documents.
            </p>
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