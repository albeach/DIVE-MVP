// frontend/src/pages/_app.tsx
import React from 'react';
import '@/styles/globals.css';
import '@/styles/keycloak-theme.css';
import { AppProps } from 'next/app';
import { useRouter } from 'next/router';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { ReactQueryDevtools } from '@tanstack/react-query-devtools';
import { Toaster } from 'react-hot-toast';
import { appWithTranslation } from 'next-i18next';
import { AuthProvider } from '@/context/auth-context';
import { Layout } from '@/components/layout/Layout';
import { useEffect, useState } from 'react';
// Import i18n initialization
import '@/utils/i18n';
// Import i18n helper
import { appNamespaces } from '@/utils/i18nHelper';
import Head from 'next/head';

function App({ Component, pageProps }: AppProps) {
  const router = useRouter();
  const [queryClient] = useState(() => new QueryClient({
    defaultOptions: {
      queries: {
        retry: 1,
        refetchOnWindowFocus: false,
      },
    },
  }));

  // Prevent hydration errors from localStorage or sessionStorage access
  const [isClient, setIsClient] = useState(false);
  useEffect(() => {
    setIsClient(true);
    
    // Log environment variables in development for debugging
    if (process.env.NODE_ENV === 'development') {
      console.log('Keycloak Config:', {
        NEXT_PUBLIC_KEYCLOAK_URL: process.env.NEXT_PUBLIC_KEYCLOAK_URL,
        NEXT_PUBLIC_KEYCLOAK_REALM: process.env.NEXT_PUBLIC_KEYCLOAK_REALM,
        NEXT_PUBLIC_KEYCLOAK_CLIENT_ID: process.env.NEXT_PUBLIC_KEYCLOAK_CLIENT_ID
      });
      
      // Debug i18n loading
      console.log('i18n Namespaces:', appNamespaces);
      // Get information about i18n config from env
      console.log('i18n ENV Config:', process.env.i18n);
    }
  }, []);

  // Add effect to inject the CSS fix
  useEffect(() => {
    // Function to fix CSS CORS issues
    const fixCssIssue = () => {
      // The CSS file that's having CORS issues
      const cssFile = 'cf2f07e87a7c6988.css';
      
      // Check if we need to add the CSS (avoid duplicates)
      const existingLinks = document.querySelectorAll(`link[href*="${cssFile}"]`);
      if (existingLinks.length > 0) return;
      
      // Create link element with our proxy
      const link = document.createElement('link');
      link.rel = 'stylesheet';
      link.type = 'text/css';
      link.href = `/api/proxy/css?file=${cssFile}`;
      
      // Append to document head
      document.head.appendChild(link);
      console.log('DIVE25: Applied CSS CORS fix');
    };
    
    // Apply the fix
    fixCssIssue();
    
    // Add a global error handler to detect CORS issues
    const originalOnError = window.onerror;
    window.onerror = function(message, source, lineno, colno, error) {
      // Check if the error is CORS related
      if (typeof message === 'string' && 
          (message.includes('CORS') || message.includes('cross-origin'))) {
        console.warn('DIVE25: Detected potential CORS error, applying fix:', message);
        fixCssIssue();
      }
      
      // Call original handler if it exists
      if (originalOnError) {
        return originalOnError.call(this, message, source, lineno, colno, error);
      }
      
      return false;
    };
    
    // Also listen for specific security policy violations
    window.addEventListener('securitypolicyviolation', (e) => {
      console.warn('DIVE25: Security policy violation:', e.violatedDirective);
      fixCssIssue();
    });
    
    return () => {
      // Clean up event listeners
      window.onerror = originalOnError;
    };
  }, []);

  // Basic public routes that don't require authentication
  const isPublicRoute = [
    '/',
    '/login',
    '/logout',
    '/unauthorized',
    '/404',
    '/500',
    '/country-select',
  ].includes(router.pathname);
  
  // Check if we're on the landing page or country selection page or accessing Keycloak URLs
  const isPublicPage = router.pathname === '/' || 
                       router.pathname === '/country-select' ||
                       router.pathname.includes('/broker/') ||
                       router.pathname.includes('/realms/');
  
  // Only auto-initialize auth if not on public pages
  const shouldAutoInitialize = !isPublicPage;

  if (!isClient) {
    return null;
  }

  return (
    <QueryClientProvider client={queryClient}>
      <Head>
        {/* Safe fallback approach: add a preconnect for the origin */}
        <link rel="preconnect" href="https://dive25.local:8443" crossOrigin="anonymous" />
      </Head>
      {/* Use AuthProvider with conditional auto-initialization */}
      <AuthProvider autoInitialize={shouldAutoInitialize}>
        <Layout isPublicRoute={isPublicRoute}>
          <Component {...pageProps} />
        </Layout>
        <Toaster position="top-right" />
      </AuthProvider>
      {process.env.NODE_ENV === 'development' && <ReactQueryDevtools initialIsOpen={false} />}
    </QueryClientProvider>
  );
}

export default appWithTranslation(App);