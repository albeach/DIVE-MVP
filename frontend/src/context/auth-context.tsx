// frontend/src/context/auth-context.tsx
import React, { createContext, useContext, useState, useEffect, ReactNode } from 'react';
import { useRouter } from 'next/router';
import Keycloak from 'keycloak-js';
import { User } from '@/types/user';
import { Spinner } from '@/components/ui/Spinner';
import toast from 'react-hot-toast';

interface AuthContextProps {
  isAuthenticated: boolean;
  isLoading: boolean;
  user: User | null;
  keycloak: Keycloak | null;
  login: () => void;
  logout: () => void;
  refreshToken: () => Promise<boolean>;
  hasRole: (roles: string[]) => boolean;
}

const AuthContext = createContext<AuthContextProps | undefined>(undefined);

interface AuthProviderProps {
  children: ReactNode;
}

export function AuthProvider({ children }: AuthProviderProps) {
  const [keycloak, setKeycloak] = useState<Keycloak | null>(null);
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [isLoading, setIsLoading] = useState(true);
  const [user, setUser] = useState<User | null>(null);
  const [initError, setInitError] = useState<string | null>(null);
  const router = useRouter();

  // Initialize Keycloak
  useEffect(() => {
    const initKeycloak = async () => {
      try {
        console.time('keycloak-init');
        
        // Create keycloak instance with full URL
        const keycloakInstance = new Keycloak({
          url: (process.env.NEXT_PUBLIC_KEYCLOAK_URL || 'http://localhost:8080') + '/auth',
          realm: process.env.NEXT_PUBLIC_KEYCLOAK_REALM || 'dive25',
          clientId: process.env.NEXT_PUBLIC_KEYCLOAK_CLIENT_ID || 'dive25-frontend'
        });

        // Configure token refresh behavior
        keycloakInstance.onTokenExpired = () => {
          console.log('Token expired, attempting to refresh...');
          keycloakInstance.updateToken(30).catch(() => {
            console.warn('Token refresh failed');
            setIsAuthenticated(false);
          });
        };

        try {
          // Calculate the silent check URI with explicit protocol
          const protocol = window.location.protocol;
          const host = window.location.host;
          const silentCheckUri = `${protocol}//${host}/silent-check-sso.html`;
          
          const initOptions = {
            onLoad: 'check-sso' as const,
            silentCheckSsoRedirectUri: silentCheckUri,
            pkceMethod: 'S256' as const,
            checkLoginIframe: false,
            enableLogging: true,
            flow: 'standard' as const,
            responseMode: 'fragment' as const,
            checkLoginIframeInterval: 0
          };
          
          const authenticated = await keycloakInstance.init(initOptions);
          console.timeEnd('keycloak-init');

          setKeycloak(keycloakInstance);
          setIsAuthenticated(authenticated);

          if (authenticated) {
            // Extract user information from token
            const userProfile = {
              uniqueId: keycloakInstance.tokenParsed?.sub,
              username: keycloakInstance.tokenParsed?.preferred_username,
              email: keycloakInstance.tokenParsed?.email,
              givenName: keycloakInstance.tokenParsed?.given_name,
              surname: keycloakInstance.tokenParsed?.family_name,
              organization: keycloakInstance.tokenParsed?.organization,
              countryOfAffiliation: keycloakInstance.tokenParsed?.countryOfAffiliation,
              clearance: keycloakInstance.tokenParsed?.clearance,
              caveats: Array.isArray(keycloakInstance.tokenParsed?.caveats) 
                ? keycloakInstance.tokenParsed?.caveats 
                : keycloakInstance.tokenParsed?.caveats ? [keycloakInstance.tokenParsed?.caveats] : [],
              coi: Array.isArray(keycloakInstance.tokenParsed?.coi) 
                ? keycloakInstance.tokenParsed?.coi 
                : keycloakInstance.tokenParsed?.coi ? [keycloakInstance.tokenParsed?.coi] : [],
              roles: keycloakInstance.tokenParsed?.realm_access?.roles || [],
              lastLogin: new Date().toISOString(),
            };
            
            setUser(userProfile as User);
            
            // Expose keycloak instance for API client
            window.__keycloak = keycloakInstance;
          }
        } catch (error) {
          console.error('Keycloak initialization failed:', error);
          setInitError('Authentication service initialization failed');
          
          // Try direct login if silent check fails
          if (router.pathname !== '/' && router.pathname !== '/login') {
            login();
          }
        }

        setIsLoading(false);
      } catch (error) {
        console.error('Keycloak setup failed:', error);
        setInitError('Authentication service initialization failed');
        toast.error('Authentication service initialization failed');
        setIsLoading(false);
      }
    };

    initKeycloak();

    // Cleanup function
    return () => {
      if (window.__keycloak) {
        window.__keycloak = undefined;
      }
    };
  }, []);

  // Login function
  const login = () => {
    if (keycloak) {
      try {
        const redirectUrl = window.location.origin + (router.pathname !== '/login' ? router.pathname : '/');
        
        keycloak.login({
          redirectUri: redirectUrl
        });
      } catch (error) {
        console.error('Login error:', error);
        toast.error('Login failed. Please try again.');
      }
    } else {
      console.error('Cannot login: Keycloak not initialized');
      toast.error('Authentication service not available');
      
      // Create a new keycloak instance and try login
      const keycloakInstance = new Keycloak({
        url: (process.env.NEXT_PUBLIC_KEYCLOAK_URL || 'http://localhost:8080') + '/auth',
        realm: process.env.NEXT_PUBLIC_KEYCLOAK_REALM || 'dive25',
        clientId: process.env.NEXT_PUBLIC_KEYCLOAK_CLIENT_ID || 'dive25-frontend'
      });
      
      keycloakInstance.init({
        onLoad: 'login-required',
        redirectUri: window.location.origin + (router.pathname !== '/login' ? router.pathname : '/')
      });
    }
  };

  // Logout function
  const logout = () => {
    if (keycloak) {
      try {
        keycloak.logout({
          redirectUri: window.location.origin
        });
      } catch (error) {
        console.error('Logout error:', error);
        toast.error('Logout failed. Please try again.');
        window.location.href = window.location.origin;
      }
    }
  };

  // Token refresh function
  const refreshToken = async (): Promise<boolean> => {
    if (keycloak) {
      try {
        const refreshed = await keycloak.updateToken(30);
        return refreshed;
      } catch (error) {
        console.error('Failed to refresh token:', error);
        toast.error('Your session has expired. Please log in again.');
        login();
        return false;
      }
    }
    return false;
  };

  // Check if user has any of the specified roles
  const hasRole = (roles: string[]): boolean => {
    if (!user?.roles || user.roles.length === 0) {
      return false;
    }
    return roles.some(role => user.roles?.includes(role) || false);
  };

  const value = {
    isAuthenticated,
    isLoading,
    user,
    keycloak,
    login,
    logout,
    refreshToken,
    hasRole
  };

  if (isLoading) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <Spinner size="lg" />
      </div>
    );
  }

  if (initError) {
    // Show an error message but still render the app in unauthenticated mode
    return (
      <AuthContext.Provider value={value}>
        {children}
      </AuthContext.Provider>
    );
  }

  return (
    <AuthContext.Provider value={value}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
}

// Type definition for the global window object
declare global {
  interface Window {
    __keycloak?: Keycloak;
  }
}