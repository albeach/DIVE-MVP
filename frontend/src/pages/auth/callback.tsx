import { useEffect, useState } from 'react';
import { useRouter } from 'next/router';
import { Spinner } from '@/components/ui/Spinner';
import { createLogger } from '@/utils/logger';
import { getKeycloak } from '@/lib/keycloak';
import Keycloak from 'keycloak-js';
import toast from 'react-hot-toast';

// Create a logger for the callback page
const logger = createLogger('AuthCallback');

// Session storage keys
const SESSION_STORAGE_TOKEN_KEY = 'kc_token';
const SESSION_STORAGE_REFRESH_TOKEN_KEY = 'kc_refreshToken';

export default function AuthCallback() {
  const router = useRouter();
  const [error, setError] = useState<string | null>(null);
  const [isProcessing, setIsProcessing] = useState(true);
  const [authenticated, setAuthenticated] = useState(false);

  useEffect(() => {
    if (typeof window === 'undefined') return;

    const processCallback = async () => {
      try {
        logger.debug('Processing authentication callback...');
        
        // Extract code from URL if present
        const urlParams = new URLSearchParams(window.location.search);
        const code = urlParams.get('code');
        const sessionState = urlParams.get('session_state');
        const error = urlParams.get('error');
        const errorDescription = urlParams.get('error_description');
        
        logger.debug('Auth params from URL:', { 
          code: !!code, 
          sessionState: !!sessionState,
          error: error,
          errorDescription: errorDescription
        });

        // If there's an explicit error in the URL, handle it
        if (error) {
          throw new Error(`Keycloak error: ${error} - ${errorDescription || 'No description'}`);
        }
        
        // Handle case where no code is present but we might already be authenticated
        if (!code) {
          logger.debug('No authentication code found in URL, checking if already authenticated');
          
          // Check if we have a token in session storage
          const existingToken = sessionStorage.getItem(SESSION_STORAGE_TOKEN_KEY);
          if (existingToken) {
            logger.debug('Token found in session storage, using existing authentication');
            setAuthenticated(true);
            
            // Get redirect path from session or default to documents
            const redirectPath = sessionStorage.getItem('auth_redirect') || '/documents';
            sessionStorage.removeItem('auth_redirect');
            
            logger.debug('Using existing authentication, redirecting to:', redirectPath);
            
            setTimeout(() => {
              router.push(redirectPath);
            }, 1000);
            return;
          }
        }
        
        logger.debug('Initializing Keycloak to handle authentication callback');
        
        // Get Keycloak instance
        const keycloakInstance = getKeycloak();
        
        // Set options for processing the callback - with proper types
        const options: Keycloak.KeycloakInitOptions = {
          enableLogging: true,
          pkceMethod: 'S256',
          onLoad: 'check-sso' as Keycloak.KeycloakOnLoad, // Changed from login-required to check-sso
          checkLoginIframe: false,
          flow: 'standard',
          responseMode: 'query'
        };
        
        // Initialize with login required to process the code
        logger.debug('Attempting Keycloak initialization with options', options);
        const success = await keycloakInstance.init(options);
        logger.debug('Keycloak initialization result:', success);
        
        if (success && keycloakInstance.authenticated) {
          logger.debug('Successfully authenticated!');
          setAuthenticated(true);
          
          // Store tokens in sessionStorage
          if (keycloakInstance.token) {
            sessionStorage.setItem(SESSION_STORAGE_TOKEN_KEY, keycloakInstance.token);
            logger.debug('Token stored in session storage');
          }
          
          if (keycloakInstance.refreshToken) {
            sessionStorage.setItem(SESSION_STORAGE_REFRESH_TOKEN_KEY, keycloakInstance.refreshToken);
            logger.debug('Refresh token stored in session storage');
          }
          
          // Store keycloak globally
          window.__keycloak = keycloakInstance;
          
          // Get redirect path from session or default to documents
          const redirectPath = sessionStorage.getItem('auth_redirect') || '/documents';
          sessionStorage.removeItem('auth_redirect');
          
          logger.debug('Authentication successful, redirecting to:', redirectPath);
          
          // Redirect to the intended page with a small delay
          setTimeout(() => {
            router.push(redirectPath);
          }, 1000);
        } else {
          // If we don't have a code and initialization was not successful, try direct login
          if (!code) {
            logger.debug('No code and not authenticated, initiating login');
            keycloakInstance.login({
              redirectUri: window.location.origin + '/auth/callback'
            });
            return;
          }
          
          logger.error('Authentication failed after initialization');
          setError('Failed to complete authentication. Please try again.');
          setIsProcessing(false);
          
          // Redirect to home after a delay
          setTimeout(() => {
            router.push('/');
          }, 3000);
        }
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : 'Unknown error';
        logger.error('Error processing callback:', errorMessage);
        setError(`Authentication error: ${errorMessage}`);
        setIsProcessing(false);
        
        toast.error('Authentication failed. Please try again later.');
        
        // Redirect to home after a delay
        setTimeout(() => {
          router.push('/');
        }, 3000);
      }
    };

    // Process the callback
    processCallback();
  }, [router]);

  return (
    <div className="flex flex-col items-center justify-center min-h-screen bg-gray-100">
      <div className="w-full max-w-md p-8 space-y-8 bg-white rounded-lg shadow-md">
        <div className="text-center">
          <h2 className="mt-6 text-3xl font-extrabold text-gray-900">
            {isProcessing ? 'Completing Login' : (authenticated ? 'Login Successful' : 'Login Failed')}
          </h2>
          
          {isProcessing && (
            <div className="mt-8 flex flex-col items-center justify-center">
              <Spinner size="lg" />
              <p className="mt-4 text-gray-600">
                Processing your authentication...
              </p>
            </div>
          )}
          
          {authenticated && (
            <div className="mt-4 p-3 bg-green-100 text-green-700 rounded-md">
              Successfully authenticated! Redirecting...
            </div>
          )}
          
          {error && (
            <div className="mt-4 p-3 bg-red-100 text-red-700 rounded-md">
              {error}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}