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

  if (!isClient) {
    return null;
  }

  return (
    <QueryClientProvider client={queryClient}>
      <AuthProvider>
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