import React, { useState, useEffect } from 'react';
import { Spinner } from '@/components/ui/Spinner';
import toast from 'react-hot-toast';
import { createLogger } from '@/utils/logger';
import Head from 'next/head';
import { createIdpRedirectUrl } from '@/lib/keycloak';

// Create a logger for debugging
const logger = createLogger('CountrySelector');

// Constants for the country list
const COUNTRIES = [
  { id: 'usa-oidc', name: 'United States', flag: '🇺🇸' },
  { id: 'uk-oidc', name: 'United Kingdom', flag: '🇬🇧' },
  { id: 'canada-oidc', name: 'Canada', flag: '🇨🇦' },
  { id: 'australia-oidc', name: 'Australia', flag: '🇦🇺' },
  { id: 'newzealand-oidc', name: 'New Zealand', flag: '🇳🇿' }
];

export const CountrySelector: React.FC = () => {
  const [isLoading, setIsLoading] = useState<string | null>(null);
  const [debugInfo, setDebugInfo] = useState<string>('Loading...');
  const [isMounted, setIsMounted] = useState(false);
  const [showDebug, setShowDebug] = useState(true); // Always show debug by default
  const [urlInfo, setUrlInfo] = useState<any>({});
  
  // Use a separate useEffect for styles to avoid layout shifts
  useEffect(() => {
    // This ensures we don't cause layout shifts after hydration
    document.body.classList.add('country-selector-ready');
  }, []);
  
  // Handle component mount for reliable initial styling
  useEffect(() => {
    logger.info('CountrySelector mounted');
    console.log('===DIVE25 DEBUG: CountrySelector mounted===');
    
    // This ensures we only render the content after mounting on client
    setIsMounted(true);
    
    // Log environment info for debugging
    const env = {
      origin: typeof window !== 'undefined' ? window.location.origin : 'unknown',
      path: typeof window !== 'undefined' ? window.location.pathname : 'unknown',
      href: typeof window !== 'undefined' ? window.location.href : 'unknown',
      userAgent: typeof window !== 'undefined' ? window.navigator.userAgent : 'unknown',
      // Add all env variables that might be relevant
      NEXT_PUBLIC_KEYCLOAK_URL: process.env.NEXT_PUBLIC_KEYCLOAK_URL,
      NEXT_PUBLIC_KEYCLOAK_REALM: process.env.NEXT_PUBLIC_KEYCLOAK_REALM,
      NEXT_PUBLIC_KEYCLOAK_CLIENT_ID: process.env.NEXT_PUBLIC_KEYCLOAK_CLIENT_ID,
      NEXT_PUBLIC_KONG_URL: process.env.NEXT_PUBLIC_KONG_URL,
      NEXT_PUBLIC_FRONTEND_URL: process.env.NEXT_PUBLIC_FRONTEND_URL
    };
    
    setDebugInfo(`Component mounted at ${new Date().toISOString()}\nEnvironment: ${JSON.stringify(env, null, 2)}`);
    console.log('DIVE25 DEBUG: Environment info', env);
    
    return () => {
      logger.debug('CountrySelector unmounted');
    };
  }, []);
  
  // Direct login method
  const handleCountrySelect = (countryId: string) => {
    try {
      // Create a timestamp for tracking
      const timestamp = new Date().toISOString();
      console.log(`===DIVE25 DEBUG: Country selected at ${timestamp}===`);
      console.log(`Country selected: ${countryId}`);
      
      setIsLoading(countryId);
      setDebugInfo(prev => `${prev}\n\n${timestamp}: Country selected: ${countryId}`);
      
      // Show loading toast
      toast.loading(`Connecting to ${countryId} login service...`, { id: 'login-redirect' });
      
      try {
        // Use the utility function to get a consistent URL
        let authUrl = createIdpRedirectUrl(countryId);
        
        // CRITICAL FIX: Force the redirect_uri to include /auth/callback
        // This is a safety measure to ensure the correct redirect URI regardless of other code
        const urlObj = new URL(authUrl);
        const currentRedirectUri = urlObj.searchParams.get('redirect_uri');
        
        if (currentRedirectUri) {
          console.log(`DIVE25 DEBUG: Original redirect_uri: ${currentRedirectUri}`);
          
          // Check if the redirect_uri is missing the /auth/ prefix
          if (!currentRedirectUri.includes('/auth/callback') && currentRedirectUri.includes('/callback')) {
            // Replace /callback with /auth/callback
            const fixedRedirectUri = currentRedirectUri.replace('/callback', '/auth/callback');
            
            // Or directly set the correct value if the replace failed for any reason
            const kongUrl = process.env.NEXT_PUBLIC_KONG_URL || 'https://dive25.local:8443';
            const forcedRedirectUri = `${kongUrl}/auth/callback`;
            
            const finalRedirectUri = fixedRedirectUri.includes('/auth/callback') 
              ? fixedRedirectUri 
              : forcedRedirectUri;
              
            console.log(`DIVE25 DEBUG: Fixed redirect_uri: ${finalRedirectUri}`);
            
            // Apply the fixed redirect URI
            urlObj.searchParams.set('redirect_uri', finalRedirectUri);
            authUrl = urlObj.toString();
            
            console.log(`DIVE25 DEBUG: Fixed auth URL: ${authUrl}`);
            setDebugInfo(prev => `${prev}\n\n${timestamp}: REDIRECT URI FIXED:\nFrom: ${currentRedirectUri}\nTo: ${finalRedirectUri}`);
          }
        }
        
        // Add additional debug logging to help troubleshoot
        const params = Object.fromEntries(urlObj.searchParams.entries());
        logger.debug(`Redirect URL parameters:`, params);
        console.log('DIVE25 DEBUG: Final Redirect URL parameters:', params);
        
        setUrlInfo({
          fullUrl: authUrl,
          baseUrl: urlObj.origin + urlObj.pathname,
          params: params,
          timestamp: timestamp
        });
        
        setDebugInfo(prev => 
          `${prev}\n\n${timestamp}: Redirect URL created:` +
          `\nFull URL: ${authUrl}` +
          `\nBase: ${urlObj.origin + urlObj.pathname}` +
          `\nParameters: ${JSON.stringify(params, null, 2)}`
        );
        
        // Add a short timeout before redirect to allow UI to update
        setTimeout(() => {
          try {
            toast.dismiss('login-redirect');
            // Use window.location.replace for a clean redirect that replaces the current page in history
            if (typeof window !== 'undefined') {
              // Store that we're redirecting to avoid initialization attempts
              sessionStorage.setItem('redirecting_to_idp', 'true');
              sessionStorage.setItem('redirect_debug_info', JSON.stringify({
                countryId,
                authUrl,
                params,
                timestamp
              }));
              console.log(`DIVE25 DEBUG: Redirecting to ${authUrl} at ${new Date().toISOString()}`);
              
              // Use replace instead of assign for a cleaner navigation
              window.location.replace(authUrl);
            }
          } catch (redirectError) {
            const errorMsg = `Redirect error: ${redirectError instanceof Error ? redirectError.message : String(redirectError)}`;
            console.error('DIVE25 DEBUG: ' + errorMsg);
            setDebugInfo(prev => `${prev}\n\n${new Date().toISOString()}: ${errorMsg}`);
            toast.error('Failed to redirect. See debug info.');
            setIsLoading(null);
          }
        }, 1000); // Longer timeout to ensure debug info is displayed
      } catch (urlError) {
        const errorMsg = `Error creating URL: ${urlError instanceof Error ? urlError.message : String(urlError)}`;
        console.error('DIVE25 DEBUG: ' + errorMsg);
        setDebugInfo(prev => `${prev}\n\n${new Date().toISOString()}: ${errorMsg}`);
        toast.dismiss('login-redirect');
        toast.error('Failed to create authentication URL. See debug info.');
        setIsLoading(null);
      }
    } catch (error) {
      const errorMsg = `Country selection error: ${error instanceof Error ? error.message : String(error)}`;
      logger.error(errorMsg);
      console.error('DIVE25 DEBUG: ' + errorMsg);
      setDebugInfo(prev => `${prev}\n\n${new Date().toISOString()}: ${errorMsg}`);
      toast.dismiss('login-redirect');
      toast.error('Failed to process your selection. Check debug info.');
      setIsLoading(null);
    }
  };
  
  // Helper to format the debug info nicely
  const formatDebugUrl = () => {
    if (!urlInfo.fullUrl) return null;
    
    return (
      <div className="mt-6 p-4 bg-gray-800 text-white rounded-md overflow-x-auto">
        <h3 className="text-lg font-semibold mb-2">Authentication URL Details</h3>
        <p className="mb-1"><strong>Time:</strong> {urlInfo.timestamp}</p>
        <p className="mb-1"><strong>Base URL:</strong> {urlInfo.baseUrl}</p>
        <div className="mb-1">
          <p><strong>Parameters:</strong></p>
          <ul className="list-disc pl-6">
            {Object.entries(urlInfo.params || {}).map(([key, value]) => (
              <li key={key}><strong>{key}:</strong> {String(value)}</li>
            ))}
          </ul>
        </div>
        <p className="mt-2"><strong>Full URL:</strong></p>
        <code className="block p-2 bg-gray-900 rounded mt-1 whitespace-normal break-all text-xs">
          {urlInfo.fullUrl}
        </code>
      </div>
    );
  };
  
  // Use SSR-safe rendering approach to prevent flash of unstyled content
  if (typeof window === 'undefined') {
    // Server-side render a minimal loading state
    return <div className="flex items-center justify-center min-h-screen">Loading...</div>;
  }
  
  // Don't render anything until mounted to prevent flash of unstyled content
  if (!isMounted) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <Spinner size="lg" />
      </div>
    );
  }
  
  return (
    <>
      <Head>
        <style dangerouslySetInnerHTML={{ 
          __html: `
            /* Critical styles for immediate rendering */
            body:not(.country-selector-ready) {
              visibility: hidden;
            }
            .country-select-container {
              display: flex; 
              flex-direction: column;
              align-items: center;
              justify-content: center;
              min-height: 100vh;
              background-color: #f1f5f9;
              padding: 1rem;
            }
            .country-select-card {
              background-color: white;
              border-radius: 0.5rem;
              box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06);
              padding: 2rem;
              max-width: 28rem;
              width: 100%;
            }
            .country-button {
              display: flex;
              align-items: center;
              width: 100%;
              padding: 1rem;
              border: 1px solid #e2e8f0;
              border-radius: 0.375rem;
              transition: background-color 0.2s;
              margin-bottom: 0.75rem;
              cursor: pointer;
            }
            .country-button:hover:not(:disabled) {
              background-color: #f1f5f9;
            }
            .country-button-loading {
              background-color: #e0f2fe;
              border-color: #93c5fd;
            }
            .country-flag {
              font-size: 1.5rem;
              margin-right: 0.75rem;
            }
            .country-name {
              font-weight: 500;
            }
          `
        }} />
      </Head>
      <div className="country-select-container">
        <div className="country-select-card">
          <h1 className="text-2xl font-bold mb-6 text-center">Select Your Country</h1>
          <p className="text-gray-600 mb-6 text-center">
            Please select your country to continue to the appropriate login service.
          </p>
          <div className="space-y-3">
            {COUNTRIES.map((country) => (
              <button
                key={country.id}
                className={`country-button ${isLoading === country.id ? 'country-button-loading' : ''}`}
                onClick={() => handleCountrySelect(country.id)}
                disabled={isLoading !== null}
              >
                <span className="country-flag">{country.flag}</span>
                <span className="country-name">{country.name}</span>
                {isLoading === country.id && (
                  <Spinner size="sm" className="ml-auto" />
                )}
              </button>
            ))}
          </div>
          
          {/* Always show debug panel with toggle */}
          <div className="mt-8">
            <div className="flex justify-between items-center mb-2">
              <h3 className="text-md font-semibold text-gray-700">Debug Information</h3>
              <button 
                onClick={() => setShowDebug(!showDebug)}
                className="text-sm text-blue-600 hover:text-blue-800"
              >
                {showDebug ? 'Hide Details' : 'Show Details'}
              </button>
            </div>
            
            {showDebug && (
              <>
                {formatDebugUrl()}
                <div className="mt-4 p-3 bg-gray-100 border border-gray-200 rounded text-xs font-mono text-gray-600 overflow-x-auto">
                  <pre className="whitespace-pre-wrap">{debugInfo}</pre>
                </div>
              </>
            )}
          </div>
        </div>
      </div>
    </>
  );
}; 