// frontend/src/pages/index.tsx
import React, { useEffect } from 'react';
import { NextPage, GetStaticProps } from 'next';
import { useRouter } from 'next/router';
import Head from 'next/head';
import Link from 'next/link';
import Image from 'next/image';
import { useTranslation } from 'next-i18next';
import { serverSideTranslations } from 'next-i18next/serverSideTranslations';
import { motion } from 'framer-motion';

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
    <>
      <Head>
        <title>{t('app.name')} - Secure Document Access System</title>
        <meta name="description" content="DIVE25 - Secure document sharing across organizational boundaries" />
      </Head>

      {/* Hero Section */}
      <section className="relative min-h-screen flex items-center justify-center bg-gradient-to-br from-primary-900 via-primary-800 to-primary-700 text-white overflow-hidden">
        {/* Background decorative elements */}
        <div className="absolute inset-0 overflow-hidden opacity-10">
          <div className="absolute top-20 -right-40 w-80 h-80 rounded-full bg-primary-500 blur-3xl"></div>
          <div className="absolute -top-20 -left-20 w-80 h-80 rounded-full bg-primary-400 blur-3xl"></div>
          <div className="absolute bottom-10 right-20 w-60 h-60 rounded-full bg-primary-300 blur-3xl"></div>
        </div>

        <div className="container mx-auto px-4 relative z-10">
          <motion.div 
            className="text-center max-w-4xl mx-auto"
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.6 }}
          >
            <motion.div 
              className="mb-8"
              initial={{ opacity: 0, scale: 0.8 }}
              animate={{ opacity: 1, scale: 1 }}
              transition={{ delay: 0.2, duration: 0.6 }}
            >
              <div className="w-24 h-24 mx-auto bg-white/10 backdrop-blur-sm rounded-2xl p-3 border border-white/20 shadow-lg">
                <Image 
                  src="/assets/dive25-logo.svg" 
                  alt={t('app.name')} 
                  width={96} 
                  height={96}
                  className="transition-all duration-300"
                />
              </div>
            </motion.div>

            <motion.h1 
              className="text-4xl md:text-5xl font-bold mb-6"
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.3, duration: 0.6 }}
            >
              {t('app.name')}
            </motion.h1>

            <motion.p 
              className="text-xl md:text-2xl text-white/90 mb-8 max-w-2xl mx-auto"
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.4, duration: 0.6 }}
            >
              {t('pages.home.hero.subtitle')}
            </motion.p>

            <motion.div 
              className="flex flex-col sm:flex-row items-center justify-center gap-4"
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              transition={{ delay: 0.5, duration: 0.6 }}
            >
              {isAuthenticated ? (
                <Button
                  variant="primary"
                  size="lg"
                  className="bg-white/10 hover:bg-white/20 text-white border border-white/10 hover:border-white/20 backdrop-blur-sm shadow-lg transition-all duration-300 rounded-xl"
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
                    className="bg-white/10 hover:bg-white/20 text-white border border-white/10 hover:border-white/20 backdrop-blur-sm shadow-lg transition-all duration-300 rounded-xl px-8 py-4"
                    label={t('auth.sign_in')}
                  />
                  <Button
                    variant="secondary"
                    size="lg"
                    className="bg-transparent border-2 border-white text-white hover:bg-white/10 hover:border-white/20 backdrop-blur-sm transition-all duration-300 rounded-xl px-8 py-4"
                    onClick={() => router.push('/about')}
                  >
                    {t('pages.home.hero.learn_more')}
                  </Button>
                </>
              )}
            </motion.div>
          </motion.div>
        </div>

        {/* Wave separator */}
        <div className="absolute bottom-0 left-0 right-0">
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1440 100" fill="#edf7ed" preserveAspectRatio="none">
            <path d="M0,64L80,69.3C160,75,320,85,480,80C640,75,800,53,960,48C1120,43,1280,53,1360,58.7L1440,64L1440,100L1360,100C1280,100,1120,100,960,100C800,100,640,100,480,100C320,100,160,100,80,100L0,100Z"></path>
          </svg>
        </div>
      </section>

      {/* Features Section */}
      <section className="py-20 bg-primary-50 relative overflow-hidden">
        <div className="container mx-auto px-4">
          <motion.h2 
            className="text-3xl md:text-4xl font-bold text-center text-primary-900 mb-16"
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ duration: 0.5 }}
          >
            {t('pages.home.features.title')}
          </motion.h2>
          
          <div className="grid md:grid-cols-3 gap-8 lg:gap-12">
            {/* Feature 1 */}
            <motion.div
              initial={{ opacity: 0, y: 30 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ duration: 0.5, delay: 0.1 }}
            >
              <Card className="bg-white/90 backdrop-blur-sm p-8 rounded-xl shadow-md hover:shadow-xl transition-all duration-300 h-full border border-primary-100/50">
                <div className="text-primary-600 mb-6">
                  <div className="bg-primary-100 p-3 rounded-xl inline-block">
                    <svg xmlns="http://www.w3.org/2000/svg" className="h-10 w-10" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
                    </svg>
                  </div>
                </div>
                <h3 className="text-xl font-semibold mb-3 text-primary-900">
                  {t('pages.home.features.feature1.title')}
                </h3>
                <p className="text-gray-600 text-base leading-relaxed">
                  {t('pages.home.features.feature1.description')}
                </p>
              </Card>
            </motion.div>
            
            {/* Feature 2 */}
            <motion.div
              initial={{ opacity: 0, y: 30 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ duration: 0.5, delay: 0.2 }}
            >
              <Card className="bg-white/90 backdrop-blur-sm p-8 rounded-xl shadow-md hover:shadow-xl transition-all duration-300 h-full border border-primary-100/50">
                <div className="text-primary-600 mb-6">
                  <div className="bg-primary-100 p-3 rounded-xl inline-block">
                    <svg xmlns="http://www.w3.org/2000/svg" className="h-10 w-10" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                    </svg>
                  </div>
                </div>
                <h3 className="text-xl font-semibold mb-3 text-primary-900">
                  {t('pages.home.features.feature2.title')}
                </h3>
                <p className="text-gray-600 text-base leading-relaxed">
                  {t('pages.home.features.feature2.description')}
                </p>
              </Card>
            </motion.div>
            
            {/* Feature 3 */}
            <motion.div
              initial={{ opacity: 0, y: 30 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ duration: 0.5, delay: 0.3 }}
            >
              <Card className="bg-white/90 backdrop-blur-sm p-8 rounded-xl shadow-md hover:shadow-xl transition-all duration-300 h-full border border-primary-100/50">
                <div className="text-primary-600 mb-6">
                  <div className="bg-primary-100 p-3 rounded-xl inline-block">
                    <svg xmlns="http://www.w3.org/2000/svg" className="h-10 w-10" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z" />
                    </svg>
                  </div>
                </div>
                <h3 className="text-xl font-semibold mb-3 text-primary-900">
                  {t('pages.home.features.feature3.title')}
                </h3>
                <p className="text-gray-600 text-base leading-relaxed">
                  {t('pages.home.features.feature3.description')}
                </p>
              </Card>
            </motion.div>
          </div>
        </div>
      </section>
      
      {/* CTA Section */}
      <section className="py-24 bg-white border-t border-gray-100 relative overflow-hidden">
        {/* Background decorative elements */}
        <div className="absolute -bottom-32 -right-32 w-64 h-64 rounded-full bg-primary-100 opacity-70"></div>
        <div className="absolute -top-32 -left-32 w-64 h-64 rounded-full bg-primary-100 opacity-70"></div>
        
        <div className="container mx-auto px-4 text-center relative z-10">
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ duration: 0.5 }}
            className="max-w-3xl mx-auto"
          >
            <h2 className="text-3xl md:text-4xl font-bold text-primary-900 mb-6">
              {t('pages.home.cta.title')}
            </h2>
            <p className="text-xl text-gray-700 max-w-2xl mx-auto mb-10 leading-relaxed">
              {t('pages.home.cta.description')}
            </p>
            
            {!isAuthenticated && (
              <div className="mb-10">
                <motion.div
                  whileHover={{ scale: 1.05 }}
                  transition={{ type: "spring", stiffness: 400, damping: 10 }}
                >
                  <LoginButton
                    variant="primary"
                    size="lg"
                    className="bg-primary-600 hover:bg-primary-700 text-white shadow-lg rounded-xl px-10 py-4 font-medium"
                    label={t('auth.get_started')}
                  />
                </motion.div>
              </div>
            )}
            
            <p className="text-sm text-gray-500 bg-gray-50 p-4 rounded-lg inline-block">
              {t('pages.home.cta.security_note')}
            </p>
            
            <div className="mt-12">
              <Link href="/diagnostics" className="text-primary-600 hover:text-primary-800 text-base inline-flex items-center group">
                <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5 mr-2 transition-transform duration-300 group-hover:rotate-12" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
                <span className="border-b border-primary-200 group-hover:border-primary-600 transition-colors duration-300">
                  {t('pages.home.cta.need_help')}
                </span>
              </Link>
            </div>
          </motion.div>
        </div>
      </section>
      
      {/* Footer */}
      <footer className="bg-primary-900 text-white py-8">
        <div className="container mx-auto px-4">
          <div className="flex flex-col md:flex-row justify-between items-center">
            <div className="mb-4 md:mb-0">
              <p className="text-sm text-primary-200">&copy; {new Date().getFullYear()} {t('app.name')}. {t('footer.rights')}</p>
            </div>
            <div className="flex space-x-6">
              <a href="#" className="text-primary-200 hover:text-white transition-colors duration-200 text-sm">
                {t('footer.privacy')}
              </a>
              <a href="#" className="text-primary-200 hover:text-white transition-colors duration-200 text-sm">
                {t('footer.terms')}
              </a>
              <a href="#" className="text-primary-200 hover:text-white transition-colors duration-200 text-sm">
                {t('footer.contact')}
              </a>
            </div>
          </div>
        </div>
      </footer>
    </>
  );
};

export const getStaticProps: GetStaticProps = async ({ locale }) => {
  return {
    props: {
      ...(await serverSideTranslations(locale || 'en', ['common'])),
    },
  };
};

export default HomePage;