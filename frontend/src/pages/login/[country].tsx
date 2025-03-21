import { useRouter } from 'next/router';
import React, { useEffect, useState } from 'react';
import { Spinner } from '@/components/ui/Spinner';
import { createIdpRedirectUrl } from '@/lib/keycloak';

export default function DirectLogin() {
  const router = useRouter();
  const { country } = router.query;
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    // Only run once router is ready and we have the country parameter
    if (!router.isReady || !country) return;
    
    try {
      console.log(`Direct login: Initiating login for country: ${country}`);
      
      // Store current location for post-login redirect if needed
      const currentPath = sessionStorage.getItem('auth_redirect');
      if (!currentPath) {
        sessionStorage.setItem('auth_redirect', '/dashboard');
      }
      
      // Get the country ID from the URL parameter
      const countryId = typeof country === 'string' ? country : '';
      
      if (!countryId) {
        setError('Invalid country parameter');
        setIsLoading(false);
        return;
      }
      
      // Use the utility function to get a consistent URL
      const authUrl = createIdpRedirectUrl(countryId);
      
      console.log(`Direct login: Redirecting to IdP URL: ${authUrl}`);
      
      // Use direct browser redirect for maximum compatibility
      window.location.href = authUrl;
    } catch (err) {
      console.error('Direct login error:', err);
      setError('Failed to redirect to login. Please try again.');
      setIsLoading(false);
    }
  }, [router.isReady, country, router.query]);

  return (
    <div className="flex flex-col items-center justify-center min-h-screen bg-gray-100">
      <div className="bg-white p-8 rounded-lg shadow-md max-w-md w-full text-center">
        {isLoading ? (
          <>
            <h1 className="text-2xl font-bold mb-6">Starting Login Process</h1>
            <div className="flex justify-center mb-4">
              <Spinner size="lg" />
            </div>
            <p className="text-gray-600">
              Connecting to authentication service...
            </p>
          </>
        ) : (
          <>
            <h1 className="text-2xl font-bold mb-6">Authentication Error</h1>
            <p className="text-red-600 mb-6">{error}</p>
            <button
              className="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700 transition-colors"
              onClick={() => router.push('/')}
            >
              Return to Home
            </button>
          </>
        )}
      </div>
    </div>
  );
} 