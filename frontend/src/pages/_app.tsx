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
  }, []);

  // Basic public routes that don't require authentication
  const isPublicRoute = [
    '/',
    '/login',
    '/logout',
    '/unauthorized',
    '/404',
    '/500',
  ].includes(router.pathname);

  // Determine if this route requires auth initialization
  // Use highly specific paths to minimize Keycloak initialization
  const requiresAuth = router.pathname.startsWith('/auth/') || 
                     router.pathname.startsWith('/api/auth/') ||
                     router.pathname === '/profile' ||
                     router.pathname === '/callback' ||
                     router.pathname === '/logout' ||
                     router.pathname.startsWith('/documents/') ||
                     router.pathname.startsWith('/admin/');
                     
  // Completely skip auth for home page to prevent any iframe checks
  const skipAuthCompletely = router.pathname === '/';

  if (!isClient) {
    return null;
  }

  return (
    <QueryClientProvider client={queryClient}>
      {skipAuthCompletely ? (
        // No auth provider for home page to prevent any Keycloak initialization
        <Layout isPublicRoute={true}>
          <Component {...pageProps} />
          <Toaster position="top-right" />
        </Layout>
      ) : (
        // Normal auth provider for other pages
        <AuthProvider autoInitialize={requiresAuth}>
          <Layout isPublicRoute={isPublicRoute}>
            <Component {...pageProps} />
          </Layout>
          <Toaster position="top-right" />
        </AuthProvider>
      )}
      {process.env.NODE_ENV === 'development' && <ReactQueryDevtools initialIsOpen={false} />}
    </QueryClientProvider>
  );
}

export default appWithTranslation(App);