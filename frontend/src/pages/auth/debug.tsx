import React, { useEffect, useState } from 'react';
import { useAuth } from '@/context/auth-context';
import { Spinner } from '@/components/ui/Spinner';
import Link from 'next/link';
import { Button } from '@/components/ui/Button';

interface TokenInfo {
  isValid: boolean;
  expiresAt: string | null;
  timeRemaining: string | null;
  tokenParsed: Record<string, any> | null;
}

interface DebugData {
  keycloakState: {
    authenticated: boolean;
    token: string | null;
    refreshToken: string | null;
  };
  tokenInfo: TokenInfo;
  environmentInfo: {
    nextPublicVars: Record<string, string>;
    serverTime: string;
  };
}

export default function AuthDebugPage() {
  const { isAuthenticated, isLoading, user, keycloak, login, refreshToken } = useAuth();
  const [debugData, setDebugData] = useState<DebugData | null>(null);
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [copySuccess, setCopySuccess] = useState('');

  // Collect debug information
  useEffect(() => {
    if (!isLoading) {
      collectDebugInfo();
    }
  }, [isLoading, isAuthenticated, keycloak]);

  const collectDebugInfo = () => {
    const initialTokenInfo: TokenInfo = {
      isValid: false,
      expiresAt: null,
      timeRemaining: null,
      tokenParsed: null
    };

    // Get token information if available
    let tokenInfo = { ...initialTokenInfo };
    if (keycloak && keycloak.tokenParsed) {
      const expiryTime = keycloak.tokenParsed.exp ? keycloak.tokenParsed.exp : 0;
      const currentTime = Math.floor(Date.now() / 1000);
      const timeRemaining = expiryTime - currentTime;
      
      tokenInfo = {
        isValid: keycloak.authenticated || false,
        expiresAt: expiryTime ? new Date(expiryTime * 1000).toLocaleString() : null,
        timeRemaining: timeRemaining ? `${Math.floor(timeRemaining / 60)}m ${timeRemaining % 60}s` : null,
        tokenParsed: keycloak.tokenParsed as Record<string, any>
      };
    }

    // Collect environment info
    const nextPublicVars: Record<string, string> = {};
    Object.keys(process.env).forEach(key => {
      if (key.startsWith('NEXT_PUBLIC_')) {
        nextPublicVars[key] = process.env[key] as string;
      }
    });

    // Set debug data
    setDebugData({
      keycloakState: {
        authenticated: keycloak?.authenticated || false,
        token: keycloak?.token ? `${keycloak.token.substring(0, 15)}...` : null,
        refreshToken: keycloak?.refreshToken ? `${keycloak.refreshToken.substring(0, 15)}...` : null,
      },
      tokenInfo,
      environmentInfo: {
        nextPublicVars,
        serverTime: new Date().toISOString(),
      }
    });
  };

  const handleRefreshToken = async () => {
    if (!keycloak) return;
    
    setIsRefreshing(true);
    try {
      const refreshed = await refreshToken();
      if (refreshed) {
        collectDebugInfo();
      }
    } catch (error) {
      console.error('Error refreshing token:', error);
    } finally {
      setIsRefreshing(false);
    }
  };

  const copyToClipboard = () => {
    const textToCopy = JSON.stringify(debugData, null, 2);
    navigator.clipboard.writeText(textToCopy).then(() => {
      setCopySuccess('Copied!');
      setTimeout(() => setCopySuccess(''), 2000);
    });
  };

  if (isLoading) {
    return (
      <div className="flex justify-center items-center min-h-screen">
        <Spinner size="lg" />
        <p className="ml-2">Loading authentication info...</p>
      </div>
    );
  }

  return (
    <div className="container mx-auto px-4 py-8">
      <h1 className="text-2xl font-bold mb-6">Authentication Debug Tool</h1>
      
      <div className="mb-6 flex gap-4">
        <Button variant="primary" onClick={collectDebugInfo}>
          Refresh Info
        </Button>
        
        {isAuthenticated ? (
          <Button 
            variant="secondary" 
            onClick={handleRefreshToken}
            disabled={isRefreshing}
          >
            {isRefreshing ? <><Spinner size="sm" /> Refreshing...</> : 'Refresh Token'}
          </Button>
        ) : (
          <Button variant="primary" onClick={() => login()}>
            Log In
          </Button>
        )}
        
        <Button variant="secondary" onClick={copyToClipboard}>
          {copySuccess || 'Copy Debug Data'}
        </Button>
      </div>
      
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div className="bg-white shadow-md rounded-lg p-6">
          <h2 className="text-xl font-semibold mb-4">Authentication Status</h2>
          <div className="space-y-2">
            <div className="flex justify-between">
              <span className="font-medium">Authenticated:</span>
              <span className={isAuthenticated ? 'text-green-600' : 'text-red-600'}>
                {isAuthenticated ? 'Yes' : 'No'}
              </span>
            </div>
            
            {user && (
              <>
                <div className="flex justify-between">
                  <span className="font-medium">Username:</span>
                  <span>{user.username}</span>
                </div>
                <div className="flex justify-between">
                  <span className="font-medium">Name:</span>
                  <span>{user.givenName} {user.surname}</span>
                </div>
                <div className="flex justify-between">
                  <span className="font-medium">Roles:</span>
                  <span>{user.roles?.join(', ') || 'None'}</span>
                </div>
              </>
            )}
            
            {debugData?.tokenInfo && (
              <>
                <div className="flex justify-between">
                  <span className="font-medium">Token Expires:</span>
                  <span>{debugData.tokenInfo.expiresAt || 'N/A'}</span>
                </div>
                <div className="flex justify-between">
                  <span className="font-medium">Time Remaining:</span>
                  <span className={
                    debugData.tokenInfo.timeRemaining && 
                    parseInt(debugData.tokenInfo.timeRemaining.split('m')[0]) < 5 
                      ? 'text-red-600' 
                      : 'text-green-600'
                  }>
                    {debugData.tokenInfo.timeRemaining || 'N/A'}
                  </span>
                </div>
              </>
            )}
          </div>
        </div>
        
        <div className="bg-white shadow-md rounded-lg p-6">
          <h2 className="text-xl font-semibold mb-4">Environment Information</h2>
          <div className="space-y-2">
            {debugData?.environmentInfo.nextPublicVars && 
              Object.entries(debugData.environmentInfo.nextPublicVars).map(([key, value]) => (
                <div key={key} className="flex justify-between overflow-hidden">
                  <span className="font-medium truncate mr-2">{key}:</span>
                  <span className="truncate">{value}</span>
                </div>
              ))
            }
            
            <div className="flex justify-between">
              <span className="font-medium">Server Time:</span>
              <span>{debugData?.environmentInfo.serverTime}</span>
            </div>
          </div>
        </div>
      </div>
      
      {debugData?.tokenInfo.tokenParsed && (
        <div className="mt-6 bg-white shadow-md rounded-lg p-6">
          <h2 className="text-xl font-semibold mb-4">Token Claims</h2>
          <pre className="bg-gray-100 p-4 rounded overflow-auto max-h-96 text-sm">
            {JSON.stringify(debugData.tokenInfo.tokenParsed, null, 2)}
          </pre>
        </div>
      )}
      
      <div className="mt-8 text-center">
        <Link href="/" className="text-blue-600 hover:text-blue-800">
          Back to Home
        </Link>
      </div>
    </div>
  );
} 