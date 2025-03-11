import { useEffect, useState } from 'react';
import { getKeycloak } from '@/lib/keycloak';
import { getAuthServerUrl } from '@/lib/url';

export default function AuthDebug() {
  const [debugInfo, setDebugInfo] = useState<any>({
    loading: true,
    error: null,
    info: {}
  });

  useEffect(() => {
    async function gatherDebugInfo() {
      try {
        const keycloakInstance = getKeycloak();
        const authServerUrl = getAuthServerUrl();
        const currentUrl = window.location.href;
        const urlParams = new URLSearchParams(window.location.search);
        const hashParams = window.location.hash 
          ? new URLSearchParams(window.location.hash.substring(1)) 
          : new URLSearchParams();
        
        // Check session storage
        const storedToken = sessionStorage.getItem('kc_token');
        const storedRefreshToken = sessionStorage.getItem('kc_refreshToken');
        const redirectPath = sessionStorage.getItem('auth_redirect');
        
        // Try to get configuration from environment
        const envConfig = {
          NEXT_PUBLIC_KEYCLOAK_URL: process.env.NEXT_PUBLIC_KEYCLOAK_URL,
          NEXT_PUBLIC_KEYCLOAK_REALM: process.env.NEXT_PUBLIC_KEYCLOAK_REALM,
          NEXT_PUBLIC_KEYCLOAK_CLIENT_ID: process.env.NEXT_PUBLIC_KEYCLOAK_CLIENT_ID
        };
        
        // Test URL generation
        const testLoginUrl = `${authServerUrl}/realms/${process.env.NEXT_PUBLIC_KEYCLOAK_REALM}/protocol/openid-connect/auth?client_id=${process.env.NEXT_PUBLIC_KEYCLOAK_CLIENT_ID}&redirect_uri=${encodeURIComponent(window.location.origin + '/auth/callback')}&response_type=code&scope=openid`;
        
        // Try to initialize Keycloak and get status
        let keycloakStatus = { initialized: false, authenticated: false };
        try {
          const initialized = await keycloakInstance.init({
            onLoad: 'check-sso',
            silentCheckSsoRedirectUri: undefined,
            checkLoginIframe: false
          });
          keycloakStatus = {
            initialized: true,
            authenticated: keycloakInstance.authenticated || false
          };
        } catch (error) {
          keycloakStatus.initialized = false;
        }
        
        setDebugInfo({
          loading: false,
          error: null,
          info: {
            keycloakConfig: {
              url: keycloakInstance.authServerUrl,
              realm: keycloakInstance.realm,
              clientId: keycloakInstance.clientId
            },
            authServerUrl,
            currentUrl,
            urlParams: Object.fromEntries(urlParams.entries()),
            hashParams: Object.fromEntries(hashParams.entries()),
            sessionStorage: {
              hasToken: !!storedToken,
              hasRefreshToken: !!storedRefreshToken,
              redirectPath
            },
            environment: envConfig,
            testLoginUrl,
            keycloakStatus
          }
        });
      } catch (err) {
        setDebugInfo({
          loading: false,
          error: err instanceof Error ? err.message : String(err),
          info: {}
        });
      }
    }
    
    gatherDebugInfo();
  }, []);

  // Function to directly test login
  const testDirectLogin = () => {
    const authServerUrl = getAuthServerUrl();
    const callbackUrl = `${window.location.origin}/auth/callback`;
    const redirectUri = encodeURIComponent(callbackUrl);
    const loginUrl = `${authServerUrl}/realms/${process.env.NEXT_PUBLIC_KEYCLOAK_REALM}/protocol/openid-connect/auth?client_id=${process.env.NEXT_PUBLIC_KEYCLOAK_CLIENT_ID}&redirect_uri=${redirectUri}&response_type=code&scope=openid`;
    
    console.log('Redirecting to:', loginUrl);
    window.location.href = loginUrl;
  };

  // Function to test an alternative login URL
  const testAlternativeLogin = () => {
    // Construct a login URL without using the utilities, directly with env vars
    const keycloakUrl = process.env.NEXT_PUBLIC_KEYCLOAK_URL;
    const realm = process.env.NEXT_PUBLIC_KEYCLOAK_REALM;
    const clientId = process.env.NEXT_PUBLIC_KEYCLOAK_CLIENT_ID;
    
    // Ensure we don't add /auth
    const baseUrl = keycloakUrl?.endsWith('/auth') 
      ? keycloakUrl.slice(0, -5) 
      : keycloakUrl;
    
    const callbackUrl = `${window.location.origin}/auth/callback`;
    const redirectUri = encodeURIComponent(callbackUrl);
    
    const loginUrl = `${baseUrl}/realms/${realm}/protocol/openid-connect/auth?client_id=${clientId}&redirect_uri=${redirectUri}&response_type=code&scope=openid`;
    
    console.log('Redirecting to alternative URL:', loginUrl);
    window.location.href = loginUrl;
  };

  return (
    <div className="container mx-auto px-4 py-8">
      <h1 className="text-3xl font-bold mb-8">Authentication Debug</h1>
      
      {debugInfo.loading ? (
        <div className="p-4 bg-blue-100 text-blue-700 rounded">Loading debug information...</div>
      ) : debugInfo.error ? (
        <div className="p-4 bg-red-100 text-red-700 rounded">Error: {debugInfo.error}</div>
      ) : (
        <div className="space-y-6">
          <div className="p-4 bg-gray-100 rounded">
            <h2 className="text-xl font-semibold mb-2">Environment Configuration</h2>
            <pre className="whitespace-pre-wrap bg-white p-3 rounded border">
              {JSON.stringify(debugInfo.info.environment, null, 2)}
            </pre>
          </div>
          
          <div className="p-4 bg-gray-100 rounded">
            <h2 className="text-xl font-semibold mb-2">Keycloak Configuration</h2>
            <pre className="whitespace-pre-wrap bg-white p-3 rounded border">
              {JSON.stringify(debugInfo.info.keycloakConfig, null, 2)}
            </pre>
          </div>
          
          <div className="p-4 bg-gray-100 rounded">
            <h2 className="text-xl font-semibold mb-2">Auth Server URL</h2>
            <pre className="whitespace-pre-wrap bg-white p-3 rounded border">
              {debugInfo.info.authServerUrl}
            </pre>
          </div>
          
          <div className="p-4 bg-gray-100 rounded">
            <h2 className="text-xl font-semibold mb-2">Session Storage</h2>
            <pre className="whitespace-pre-wrap bg-white p-3 rounded border">
              {JSON.stringify(debugInfo.info.sessionStorage, null, 2)}
            </pre>
          </div>
          
          <div className="p-4 bg-gray-100 rounded">
            <h2 className="text-xl font-semibold mb-2">Current URL and Parameters</h2>
            <p className="mb-2"><strong>URL:</strong> {debugInfo.info.currentUrl}</p>
            <p className="mb-2"><strong>URL Parameters:</strong></p>
            <pre className="whitespace-pre-wrap bg-white p-3 rounded border">
              {JSON.stringify(debugInfo.info.urlParams, null, 2)}
            </pre>
            <p className="mb-2 mt-4"><strong>Hash Parameters:</strong></p>
            <pre className="whitespace-pre-wrap bg-white p-3 rounded border">
              {JSON.stringify(debugInfo.info.hashParams, null, 2)}
            </pre>
          </div>
          
          <div className="p-4 bg-gray-100 rounded">
            <h2 className="text-xl font-semibold mb-2">Keycloak Status</h2>
            <pre className="whitespace-pre-wrap bg-white p-3 rounded border">
              {JSON.stringify(debugInfo.info.keycloakStatus, null, 2)}
            </pre>
          </div>
          
          <div className="p-4 bg-gray-100 rounded">
            <h2 className="text-xl font-semibold mb-2">Test Login URLs</h2>
            <div className="mb-6">
              <h3 className="text-lg font-medium mb-2">Standard Login URL:</h3>
              <pre className="whitespace-pre-wrap bg-white p-3 rounded border mb-4">
                {debugInfo.info.testLoginUrl}
              </pre>
              <button
                onClick={testDirectLogin}
                className="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700 transition-colors"
              >
                Test Standard Login
              </button>
            </div>
            
            <div>
              <h3 className="text-lg font-medium mb-2">Alternative Login URL (Direct):</h3>
              <button
                onClick={testAlternativeLogin}
                className="px-4 py-2 bg-green-600 text-white rounded hover:bg-green-700 transition-colors"
              >
                Test Alternative Login
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
} 