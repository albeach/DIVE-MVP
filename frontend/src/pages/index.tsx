// frontend/src/pages/index.tsx
import Head from 'next/head';
import { useTranslation } from 'next-i18next';
import { serverSideTranslations } from 'next-i18next/serverSideTranslations';
import { GetStaticProps } from 'next';
import Link from 'next/link';
import { useAuth } from '@/context/auth-context';
import { Button } from '@/components/ui/Button';

export default function Home() {
  const { t } = useTranslation('common');
  const { isAuthenticated, login } = useAuth();

  return (
    <>
      <Head>
        <title>DIVE25 - Document Access System</title>
        <meta name="description" content="DIVE25 Secure Document Access System" />
      </Head>

      <div className="flex flex-col items-center justify-center min-h-screen-navbar py-12 px-4 sm:px-6 lg:px-8">
        <div className="max-w-4xl w-full space-y-8 text-center">
          <div>
            <h1 className="text-4xl font-extrabold tracking-tight text-nato-blue sm:text-5xl md:text-6xl">
              <span className="block">DIVE25</span>
              <span className="block text-dive25-600">Document Access System</span>
            </h1>
            <p className="mt-6 text-xl text-gray-600 max-w-2xl mx-auto">
              {t('home.subtitle')}
            </p>
          </div>

          <div className="mt-10">
            {isAuthenticated ? (
              <div className="space-y-4">
                <p className="text-lg text-gray-600">
                  {t('home.welcomeBack')}
                </p>
                <div className="flex flex-col sm:flex-row space-y-4 sm:space-y-0 sm:space-x-4 justify-center">
                  <Button 
                    as={Link}
                    href="/documents"
                    variant="primary"
                    size="lg"
                  >
                    {t('home.viewDocuments')}
                  </Button>
                  <Button 
                    as={Link}
                    href="/documents/upload"
                    variant="secondary"
                    size="lg"
                  >
                    {t('home.uploadDocument')}
                  </Button>
                </div>
              </div>
            ) : (
              <div className="space-y-4">
                <p className="text-lg text-gray-600">
                  {t('home.loginPrompt')}
                </p>
                <Button 
                  onClick={login}
                  variant="primary"
                  size="lg"
                >
                  {t('login.signIn')}
                </Button>
              </div>
            )}
          </div>

          <div className="mt-12 border-t border-gray-200 pt-8">
            <p className="text-base text-gray-500">
              {t('home.securityNotice')}
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