import React, { useEffect, useState } from 'react';
import { useRouter } from 'next/router';
import Head from 'next/head';
import { Spinner } from '@/components/ui/Spinner';
import { createLogger } from '@/utils/logger';

// Create a logger for debugging
const logger = createLogger('AuthCallback');

export default function AuthCallbackPage() {
  const router = useRouter();
  const [error, setError] = useState<string | null>(null);
  const [debug, setDebug] = useState<string>('Initializing callback');
  const [showDebug, setShowDebug] = useState(true);
  const [savedData, setSavedData] = useState<any>({});
  
  useEffect(() => {
    // Simple function to process the callback and redirect
    const processCallback = () => {
      try {
        const timestamp = new Date().toISOString();
        logger.info('Processing authentication callback');
        console.log(`===DIVE25 DEBUG: Auth Callback Processing (${timestamp})===`);
        
        // Get current URL for debugging
        const currentUrl = typeof window !== 'undefined' ? window.location.href : 'unknown';
        setDebug(prev => `${prev}\n${timestamp}: Processing URL: ${currentUrl}`);
        console.log(`DIVE25 DEBUG: Processing URL: ${currentUrl}`);
        
        // Check for authorization code in URL (OAuth code flow)
        const params = new URLSearchParams(window.location.search);
        const code = params.get('code');
        const state = params.get('state');
        const error = params.get('error');
        const error_description = params.get('error_description');
        
        // Log all query parameters for debugging
        const allParams: Record<string, string> = {};
        params.forEach((value, key) => {
          allParams[key] = value;
        });
        
        // Log the saved state from sessionStorage if available
        const savedSession: Record<string, any> = {};
        
        // Try to get all relevant session storage items
        if (typeof window !== 'undefined') {
          const keys = [
            'idp_state', 
            'idp_session_state', 
            'idp_redirect_time', 
            'selected_country',
            'auth_redirect',
            'redirecting_to_idp',
            'redirect_debug_info'
          ];
          
          keys.forEach(key => {
            try {
              const value = sessionStorage.getItem(key);
              savedSession[key] = value;
              if (key === 'redirect_debug_info' && value) {
                try {
                  savedSession[`${key}_parsed`] = JSON.parse(value);
                } catch (e) {
                  savedSession[`${key}_parse_error`] = String(e);
                }
              }
            } catch (e) {
              savedSession[`${key}_error`] = String(e);
            }
          });
        }
        
        setSavedData({
          urlParams: allParams,
          sessionData: savedSession,
          timestamp
        });
        
        console.log('DIVE25 DEBUG: URL parameters:', {
          allParams,
          code: !!code,
          state,
          error,
          error_description
        });
        
        console.log('DIVE25 DEBUG: Session storage:', savedSession);
        
        setDebug(prev => 
          `${prev}\n${timestamp}: URL Parameters: ${JSON.stringify(allParams, null, 2)}` +
          `\n\n${timestamp}: Session Storage: ${JSON.stringify(savedSession, null, 2)}`
        );
        
        // Handle any errors from the IdP
        if (error) {
          const errorMsg = error_description || error;
          logger.error('Authentication error:', errorMsg);
          console.error(`DIVE25 DEBUG: Authentication error: ${errorMsg}`);
          setError(`Authentication failed: ${errorMsg}`);
          setDebug(prev => `${prev}\n\n${timestamp}: ERROR: ${errorMsg}`);
          return;
        }
        
        // Also check if there's a state mismatch
        const savedState = typeof window !== 'undefined' ? sessionStorage.getItem('idp_state') : null;
        if (state && savedState && state !== savedState) {
          const errorMsg = `State mismatch - expected: ${savedState}, got: ${state}`;
          logger.error(errorMsg);
          console.error(`DIVE25 DEBUG: ${errorMsg}`);
          setError(`Authentication error: Invalid state parameter`);
          setDebug(prev => `${prev}\n\n${timestamp}: ERROR: ${errorMsg}`);
          return;
        }
        
        // Get redirect path from session storage or default to dashboard
        const redirectPath = sessionStorage.getItem('auth_redirect') || '/dashboard';
        logger.info(`Redirecting to: ${redirectPath}`);
        console.log(`DIVE25 DEBUG: Redirecting to: ${redirectPath}`);
        setDebug(prev => `${prev}\n\n${timestamp}: Redirecting to: ${redirectPath}`);
        
        // Cleanup session storage
        try {
          sessionStorage.removeItem('auth_redirect');
          sessionStorage.removeItem('idp_state');
          sessionStorage.removeItem('idp_session_state');
          sessionStorage.removeItem('idp_redirect_time');
          sessionStorage.removeItem('selected_country');
          sessionStorage.removeItem('redirecting_to_idp');
          sessionStorage.removeItem('redirect_debug_info');
          console.log('DIVE25 DEBUG: Session storage cleaned up');
        } catch (cleanupError) {
          console.error(`DIVE25 DEBUG: Error cleaning up session storage: ${cleanupError}`);
        }
        
        // Use direct navigation for most reliable redirect
        // Add a delay to make sure the debug info is visible
        setTimeout(() => {
          try {
            window.location.href = redirectPath;
          } catch (redirectError) {
            const errMsg = `Error redirecting: ${redirectError instanceof Error ? redirectError.message : String(redirectError)}`;
            console.error(`DIVE25 DEBUG: ${errMsg}`);
            setDebug(prev => `${prev}\n\n${new Date().toISOString()}: ERROR: ${errMsg}`);
            setError(errMsg);
          }
        }, 2000);
      } catch (err) {
        const errorMsg = `Error processing callback: ${err instanceof Error ? err.message : String(err)}`;
        logger.error(errorMsg);
        console.error(`DIVE25 DEBUG: ${errorMsg}`);
        setError('Authentication failed. Please try again.');
        setDebug(prev => `${prev}\n\n${new Date().toISOString()}: ERROR: ${errorMsg}`);
      }
    };
    
    // Only run on client side
    if (typeof window !== 'undefined') {
      // If we got here, assume auth was successful and redirect
      // Short timeout to let any potential session cookies be set
      setTimeout(processCallback, 1000);
    }
  }, [router]);
  
  // Format the saved data for better debugging
  const formatDebugData = () => {
    if (!savedData.timestamp) return null;
    
    return (
      <div className="debug-data">
        <div className="mt-6 p-4 bg-gray-800 text-white rounded-md overflow-x-auto">
          <h3 className="text-lg font-semibold mb-2">Callback Data</h3>
          <p className="mb-1"><strong>Time:</strong> {savedData.timestamp}</p>
          
          <div className="mb-4">
            <h4 className="text-md font-semibold mb-1">URL Parameters:</h4>
            {Object.keys(savedData.urlParams || {}).length > 0 ? (
              <ul className="list-disc pl-6">
                {Object.entries(savedData.urlParams || {}).map(([key, value]) => (
                  <li key={key}><strong>{key}:</strong> {String(value)}</li>
                ))}
              </ul>
            ) : (
              <p className="text-yellow-300">No URL parameters found</p>
            )}
          </div>
          
          <div>
            <h4 className="text-md font-semibold mb-1">Session Storage:</h4>
            {Object.keys(savedData.sessionData || {}).length > 0 ? (
              <ul className="list-disc pl-6">
                {Object.entries(savedData.sessionData || {}).map(([key, value]) => (
                  <li key={key}>
                    <strong>{key}:</strong> 
                    {typeof value === 'object' ? (
                      <pre className="pl-4 mt-1 text-xs whitespace-pre-wrap">{JSON.stringify(value, null, 2)}</pre>
                    ) : (
                      <span className="break-all"> {String(value)}</span>
                    )}
                  </li>
                ))}
              </ul>
            ) : (
              <p className="text-yellow-300">No session storage data found</p>
            )}
          </div>
        </div>
      </div>
    );
  };
  
  return (
    <>
      <Head>
        <title>Authentication Callback</title>
        <style>{`
          .debug-section {
            margin-top: 2rem;
            border-top: 1px solid #e2e8f0;
            padding-top: 1rem;
          }
          pre {
            white-space: pre-wrap;
          }
        `}</style>
      </Head>
      <div className="flex flex-col items-center justify-center min-h-screen bg-gray-100 p-4">
        <div className="bg-white p-8 rounded-lg shadow-md max-w-2xl w-full text-center">
          {!error ? (
            <>
              <h1 className="text-2xl font-bold mb-6">Authentication In Progress</h1>
              <div className="flex justify-center mb-4">
                <Spinner size="lg" />
              </div>
              <p className="text-gray-600 mb-2">
                Authentication callback is being processed...
              </p>
              <p className="text-gray-500 text-sm">
                You will be redirected automatically when complete.
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
          
          {/* Debug information toggle */}
          <div className="debug-section">
            <div className="flex justify-between items-center">
              <h3 className="text-md font-semibold text-gray-700">Debug Information</h3>
              <button 
                onClick={() => setShowDebug(!showDebug)}
                className="text-sm text-blue-600 hover:text-blue-800"
              >
                {showDebug ? 'Hide Details' : 'Show Details'}
              </button>
            </div>
            
            {showDebug && (
              <div className="mt-4">
                {formatDebugData()}
                <div className="mt-4 p-3 bg-gray-100 border border-gray-200 rounded text-xs font-mono text-gray-600 overflow-x-auto">
                  <pre>{debug}</pre>
                </div>
              </div>
            )}
          </div>
        </div>
      </div>
    </>
  );
}