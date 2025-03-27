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
import { defaultNamespaces, getTranslationFallbacks } from '@/utils/i18nHelper';

import { Button } from '@/components/ui/Button';
import LoginButton from '@/components/auth/LoginButton';
import { Card } from '@/components/ui/Card';
import { useAuth } from '@/context/auth-context';

const HomePage: NextPage = () => {
  const router = useRouter();
  const { t } = useTranslation(defaultNamespaces);
  
  // Helper function to get translations with fallbacks
  const translate = (keys: string[]) => {
    for (const key of keys) {
      const translation = t(key);
      if (translation && translation !== key) {
        return translation;
      }
    }
    return t(keys[0]);
  };
  
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
        <title>{translate(getTranslationFallbacks.appName)} - Secure Document Access System</title>
        <meta name="description" content="DIVE25 - Secure document sharing across organizational boundaries" />
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link rel="preconnect" href="https://fonts.gstatic.com" crossOrigin="anonymous" />
      </Head>

      {/* Hero Section */}
      <section className="relative min-h-screen flex items-center justify-center overflow-hidden">
        {/* Modern gradient background */}
        <div className="absolute inset-0 bg-gradient-to-br from-primary-900 via-primary-800 to-primary-700">
          {/* Mesh gradient overlay */}
          <div className="absolute inset-0 opacity-20 bg-[radial-gradient(circle_at_30%_20%,rgba(255,255,255,0.2)_0%,rgba(255,255,255,0)_60%)]"></div>
          
          {/* Animated subtle particles */}
          <div className="absolute inset-0">
            {[...Array(20)].map((_, i) => (
              <div 
                key={i}
                className="absolute rounded-full bg-white opacity-10"
                style={{
                  width: `${Math.random() * 8 + 4}px`,
                  height: `${Math.random() * 8 + 4}px`,
                  top: `${Math.random() * 100}%`,
                  left: `${Math.random() * 100}%`,
                  animation: `float ${Math.random() * 10 + 15}s linear infinite`,
                  animationDelay: `${Math.random() * 5}s`
                }}
              ></div>
            ))}
          </div>
        </div>

        <div className="container mx-auto px-6 relative z-10">
          <div className="flex flex-col lg:flex-row items-center justify-between gap-16">
            {/* Left content - Text */}
            <motion.div 
              className="text-left max-w-2xl"
              initial={{ opacity: 0, x: -20 }}
              animate={{ opacity: 1, x: 0 }}
              transition={{ duration: 0.6 }}
            >
              <motion.h1 
                className="text-5xl md:text-6xl lg:text-7xl font-extrabold mb-6 text-white leading-tight tracking-tight"
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: 0.2, duration: 0.6 }}
              >
                <span className="inline-block">Secure Document </span>
                <span className="inline-block bg-gradient-to-r from-white to-green-200 bg-clip-text text-transparent">
                  Access System
                </span>
              </motion.h1>

              <motion.p 
                className="text-xl md:text-2xl text-white/80 mb-8 leading-relaxed"
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: 0.4, duration: 0.6 }}
              >
                {translate(getTranslationFallbacks.pages.home.subtitle)}
              </motion.p>

              <motion.div 
                className="flex flex-wrap items-center gap-4"
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                transition={{ delay: 0.6, duration: 0.6 }}
              >
                {isAuthenticated ? (
                  <Button
                    variant="primary"
                    size="lg"
                    className="bg-white hover:bg-white/90 text-primary-900 font-medium transition duration-300 rounded-xl shadow-lg shadow-primary-900/20 px-8 py-4"
                    onClick={() => router.push('/documents')}
                  >
                    <span className="flex items-center">
                      <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                      </svg>
                      {translate(getTranslationFallbacks.pages.home.viewDocuments)}
                    </span>
                  </Button>
                ) : (
                  <>
                    <LoginButton
                      variant="primary"
                      size="lg"
                      className="bg-white hover:bg-white/90 text-primary-900 font-medium transition duration-300 rounded-xl shadow-lg shadow-primary-900/20 px-8 py-4"
                      label={translate(getTranslationFallbacks.auth.signIn)}
                    />
                    <Button
                      variant="secondary"
                      size="lg"
                      className="bg-transparent border-2 border-white/30 text-white hover:bg-white/10 hover:border-white/40 backdrop-blur-sm transition duration-300 rounded-xl px-8 py-4 shadow-lg shadow-primary-900/10"
                      onClick={() => router.push('/about')}
                    >
                      {translate(getTranslationFallbacks.pages.home.learnMore)}
                    </Button>
                  </>
                )}
                
                {/* Trust indicators */}
                <div className="flex items-center space-x-2 mt-8 text-white/60">
                  <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" />
                  </svg>
                  <span className="text-sm">Secure & Compliant</span>
                </div>
              </motion.div>
            </motion.div>
            
            {/* Right content - 3D illustration */}
            <motion.div
              className="relative w-full max-w-md lg:max-w-lg xl:max-w-xl"
              initial={{ opacity: 0, scale: 0.9 }}
              animate={{ opacity: 1, scale: 1 }}
              transition={{ delay: 0.3, duration: 0.8 }}
            >
              <div className="relative aspect-square w-full">
                {/* Hero image background glow */}
                <div className="absolute inset-0 rounded-full bg-primary-500/20 blur-3xl transform scale-75 -z-10"></div>
                
                {/* Hero image container with glassy effect */}
                <div className="relative w-full h-full rounded-3xl overflow-hidden backdrop-blur-sm border border-white/10 shadow-2xl">
                  <Image
                    src="/assets/documents-illustration.svg"
                    alt="Secure document access visualization"
                    fill
                    className="object-cover"
                    priority
                  />
                </div>
                
                {/* Decorative elements */}
                <div className="absolute -bottom-6 -right-6 w-32 h-32 rounded-full bg-primary-400/30 backdrop-blur-md border border-white/10"></div>
                <div className="absolute top-10 -left-10 w-20 h-20 rounded-lg bg-primary-300/20 backdrop-blur-sm border border-white/10 rotate-12"></div>
              </div>
            </motion.div>
          </div>
        </div>

        {/* Enhanced wave separator */}
        <div className="absolute bottom-0 left-0 right-0 overflow-hidden">
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1440 120" preserveAspectRatio="none" className="w-full h-20 md:h-24 lg:h-28 text-primary-50">
            <path 
              fill="currentColor" 
              fillOpacity="1" 
              d="M0,32L48,48C96,64,192,96,288,96C384,96,480,64,576,58.7C672,53,768,75,864,80C960,85,1056,75,1152,64C1248,53,1344,43,1392,37.3L1440,32L1440,120L1392,120C1344,120,1248,120,1152,120C1056,120,960,120,864,120C768,120,672,120,576,120C480,120,384,120,288,120C192,120,96,120,48,120L0,120Z"
            ></path>
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
            {translate(getTranslationFallbacks.pages.home.features.title)}
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
                  {translate(getTranslationFallbacks.pages.home.features.feature1.title)}
                </h3>
                <p className="text-gray-600 text-base leading-relaxed">
                  {translate(getTranslationFallbacks.pages.home.features.feature1.description)}
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
                  {translate(getTranslationFallbacks.pages.home.features.feature2.title)}
                </h3>
                <p className="text-gray-600 text-base leading-relaxed">
                  {translate(getTranslationFallbacks.pages.home.features.feature2.description)}
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
                  {translate(getTranslationFallbacks.pages.home.features.feature3.title)}
                </h3>
                <p className="text-gray-600 text-base leading-relaxed">
                  {translate(getTranslationFallbacks.pages.home.features.feature3.description)}
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
              {translate(getTranslationFallbacks.pages.home.cta.title)}
            </h2>
            <p className="text-xl text-gray-700 max-w-2xl mx-auto mb-10 leading-relaxed">
              {translate(getTranslationFallbacks.pages.home.cta.description)}
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
                    label={translate(getTranslationFallbacks.auth.getStarted)}
                  />
                </motion.div>
              </div>
            )}
            
            <p className="text-sm text-gray-500 bg-gray-50 p-4 rounded-lg inline-block">
              {translate(getTranslationFallbacks.pages.home.cta.securityNote)}
            </p>
            
            <div className="mt-12">
              <Link href="/diagnostics" className="text-primary-600 hover:text-primary-800 text-base inline-flex items-center group">
                <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5 mr-2 transition-transform duration-300 group-hover:rotate-12" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
                <span className="border-b border-primary-200 group-hover:border-primary-600 transition-colors duration-300">
                  {translate(getTranslationFallbacks.pages.home.cta.needHelp)}
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
              <p className="text-sm text-primary-200">&copy; {new Date().getFullYear()} {translate(getTranslationFallbacks.appName)}. {translate(getTranslationFallbacks.footer.rights)}</p>
            </div>
            <div className="flex space-x-6">
              <a href="#" className="text-primary-200 hover:text-white transition-colors duration-200 text-sm">
                {translate(getTranslationFallbacks.footer.privacy)}
              </a>
              <a href="#" className="text-primary-200 hover:text-white transition-colors duration-200 text-sm">
                {translate(getTranslationFallbacks.footer.terms)}
              </a>
              <a href="#" className="text-primary-200 hover:text-white transition-colors duration-200 text-sm">
                {translate(getTranslationFallbacks.footer.contact)}
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
      ...(await serverSideTranslations(locale || 'en', ['common', 'translation', 'profile', 'documents'])),
    },
  };
};

export default HomePage;