// frontend/src/pages/index.tsx
import React from 'react';
import { NextPage } from 'next';
import { useRouter } from 'next/router';
import Head from 'next/head';
import Link from 'next/link';
import Image from 'next/image';
import { useTranslation } from 'next-i18next';
import { serverSideTranslations } from 'next-i18next/serverSideTranslations';

import { Button } from '@/components/ui/Button';
import LoginButton from '@/components/auth/LoginButton';
import { Card } from '@/components/ui/Card';
import { useAuth } from '@/context/auth-context';

const HomePage: NextPage = () => {
  const router = useRouter();
  const { t } = useTranslation('common');
  
  // Safe auth usage with fallback for landing page
  let isAuthenticated = false;
  try {
    const { isAuthenticated: authState } = useAuth();
    isAuthenticated = authState;
  } catch (error) {
    console.warn('Auth context not available on landing page');
  }

  return (
    <div className="min-h-screen bg-white">
      <Head>
        <title>{t('app.name')} | {t('pages.home.title')}</title>
        <meta name="description" content={t('pages.home.description')} />
      </Head>

      <main>
        {/* Hero Section */}
        <section className="bg-gradient-to-b from-primary-900 via-primary-800 to-primary-700 text-white">
          <div className="container mx-auto px-4 py-16 md:py-24 lg:py-32">
            <div className="max-w-4xl mx-auto text-center">
              <h1 className="text-4xl md:text-5xl lg:text-6xl font-bold text-white mb-6 tracking-tight">
                {t('app.name')}
              </h1>
              <p className="text-xl md:text-2xl text-primary-50 mb-8 leading-relaxed">
                {t('pages.home.hero.subtitle')}
              </p>
              <div className="flex flex-col sm:flex-row items-center justify-center gap-4">
                {isAuthenticated ? (
                  <Button
                    variant="primary"
                    size="lg"
                    className="bg-white text-primary-800 hover:bg-primary-50 shadow-md"
                    onClick={() => router.push('/documents')}
                  >
                    <span className="flex items-center">
                      <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                      </svg>
                      {t('pages.home.hero.document_cta')}
                    </span>
                  </Button>
                ) : (
                  <>
                    <LoginButton
                      variant="primary"
                      size="lg"
                      className="bg-white text-primary-800 hover:bg-primary-50 shadow-md"
                      label={t('auth.sign_in')}
                    />
                    <Button
                      variant="secondary"
                      size="lg"
                      className="bg-transparent border-2 border-white text-white hover:bg-primary-800/20 hover:border-primary-50"
                      onClick={() => router.push('/about')}
                    >
                      {t('pages.home.hero.learn_more')}
                    </Button>
                  </>
                )}
              </div>
            </div>
          </div>
        </section>

        {/* Features Section */}
        <section className="py-16 bg-primary-50">
          <div className="container mx-auto px-4">
            <h2 className="text-3xl md:text-4xl font-bold text-center text-primary-900 mb-12">
              {t('pages.home.features.title')}
            </h2>
            
            <div className="grid md:grid-cols-3 gap-8">
              {/* Feature 1 */}
              <Card className="bg-white p-6 rounded-lg shadow-md hover:shadow-lg transition-shadow duration-300">
                <div className="text-primary-600 mb-4">
                  <svg xmlns="http://www.w3.org/2000/svg" className="h-12 w-12" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
                  </svg>
                </div>
                <h3 className="text-xl font-semibold mb-2 text-primary-900">
                  {t('pages.home.features.feature1.title')}
                </h3>
                <p className="text-gray-600 text-base">
                  {t('pages.home.features.feature1.description')}
                </p>
              </Card>
              
              {/* Feature 2 */}
              <Card className="bg-white p-6 rounded-lg shadow-md hover:shadow-lg transition-shadow duration-300">
                <div className="text-primary-600 mb-4">
                  <svg xmlns="http://www.w3.org/2000/svg" className="h-12 w-12" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                  </svg>
                </div>
                <h3 className="text-xl font-semibold mb-2 text-primary-900">
                  {t('pages.home.features.feature2.title')}
                </h3>
                <p className="text-gray-600 text-base">
                  {t('pages.home.features.feature2.description')}
                </p>
              </Card>
              
              {/* Feature 3 */}
              <Card className="bg-white p-6 rounded-lg shadow-md hover:shadow-lg transition-shadow duration-300">
                <div className="text-primary-600 mb-4">
                  <svg xmlns="http://www.w3.org/2000/svg" className="h-12 w-12" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z" />
                  </svg>
                </div>
                <h3 className="text-xl font-semibold mb-2 text-primary-900">
                  {t('pages.home.features.feature3.title')}
                </h3>
                <p className="text-gray-600 text-base">
                  {t('pages.home.features.feature3.description')}
                </p>
              </Card>
            </div>
          </div>
        </section>
        
        {/* CTA Section */}
        <section className="py-16 bg-white border-t border-gray-100">
          <div className="container mx-auto px-4 text-center">
            <h2 className="text-3xl font-bold text-primary-900 mb-6">
              {t('pages.home.cta.title')}
            </h2>
            <p className="text-xl text-gray-700 max-w-2xl mx-auto mb-8">
              {t('pages.home.cta.description')}
            </p>
            
            {!isAuthenticated && (
              <div className="mb-8">
                <LoginButton
                  variant="primary"
                  size="lg"
                  className="bg-primary-600 hover:bg-primary-700 text-white shadow-md"
                  label={t('auth.get_started')}
                />
              </div>
            )}
            
            <p className="text-sm text-gray-500">
              {t('pages.home.cta.security_note')}
            </p>
            
            <div className="mt-12">
              <Link href="/diagnostics" className="text-primary-600 hover:text-primary-800 text-base inline-flex items-center">
                <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
                {t('pages.home.cta.need_help')}
              </Link>
            </div>
          </div>
        </section>
      </main>
    </div>
  );
};

export async function getStaticProps({ locale }: { locale: string }) {
  return {
    props: {
      ...(await serverSideTranslations(locale, ['common'])),
    },
  };
}

export default HomePage;