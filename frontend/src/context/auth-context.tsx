// frontend/src/context/auth-context.tsx
import React, { createContext, useContext, useState, useEffect, ReactNode, useCallback } from 'react';
import { useRouter } from 'next/router';
import Keycloak, { KeycloakLoginOptions } from 'keycloak-js';
import { User } from '@/types/user';
import { Spinner } from '@/components/ui/Spinner';
import toast from 'react-hot-toast';
import { createLogger } from '@/utils/logger';

// Create a logger for auth context
const logger = createLogger('AuthContext');

// Token refresh buffer constants
const TOKEN_REFRESH_BUFFER = 60; // Refresh token 60 seconds before expiry

interface AuthContextProps {
  isAuthenticated: boolean;
  isLoading: boolean;
  user: User | null;
  keycloak: Keycloak | null;
  login: () => void;
  logout: () => void;
  refreshToken: () => Promise<boolean>;
  hasRole: (roles: string[]) => boolean;
  error: string | null;
}

export interface UserSecurityAttributes {
  clearance: string;
  caveats: string[];
  coi: string[];
  countryOfAffiliation: string;
}

const AuthContext = createContext<AuthContextProps | undefined>(undefined);

interface AuthProviderProps {
  children: ReactNode;
  autoInitialize?: boolean;
}

// List of paths that should trigger authentication
const AUTH_PATHS = ['/auth', '/api/auth', '/callback', '/logout', '/profile', '/documents', '/admin'];

// Move and update the global window interface declaration at the top of the file
declare global {
  interface Window {
    __keycloak?: any;
  }
}

export function AuthProvider({ children, autoInitialize = false }: AuthProviderProps) {
  const [keycloak, setKeycloak] = useState<Keycloak | null>(null);
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [user, setUser] = useState<User | null>(null);
  const [error, setError] = useState<string | null>(null);
  const router = useRouter();
  
  // Define refreshToken function
  const refreshToken = useCallback(async (): Promise<boolean> => {
    if (!keycloak) {
      logger.error('Cannot refresh token - no Keycloak instance');
      return false;
    }
    
    if (!keycloak.authenticated) {
      logger.error('Cannot refresh token - not authenticated');
      return false;
    }
    
    try {
      logger.debug('Attempting to refresh token');
      const refreshed = await keycloak.updateToken(TOKEN_REFRESH_BUFFER);
      
      if (refreshed) {
        logger.info('Token refreshed successfully');
        return true;
      } else {
        logger.debug('Token is still valid, no refresh needed');
        return true;
      }
    } catch (error) {
      logger.error('Failed to refresh token:', error);
      
      // If refresh failed but we're still authenticated, try to login again
      if (keycloak.authenticated) {
        toast.error('Your session has expired. Redirecting to login...');
        
        // Store current location for redirect after login
        sessionStorage.setItem('auth_redirect', window.location.pathname);
        
        // Attempt to login again
        setTimeout(() => {
          keycloak.login();
        }, 1000);
      }
      
      return false;
    }
  }, [keycloak]);
  
  // Define logout function
  const logout = useCallback(() => {
    // Set state to unauthenticated
    setIsAuthenticated(false);
    setUser(null);
    
    // Redirect to home after logout if keycloak instance exists
    if (keycloak) {
      try {
        // Get the hostname for redirection
        const origin = window.location.origin;
        keycloak.logout({ redirectUri: origin });
      } catch (error) {
        logger.error('Error during logout:', error);
        // Fallback: redirect to home page
        window.location.href = '/';
      }
    } else {
      // If no keycloak instance, just redirect to home
      window.location.href = '/';
    }
  }, [keycloak]);
  
  // Function to check if user has any of the specified roles
  const hasRole = useCallback((roles: string[]): boolean => {
    if (!user || !user.roles || user.roles.length === 0) {
      return false;
    }
    
    return roles.some(role => user.roles?.includes(role));
  }, [user]);
  
  // Initialize Keycloak
  const initializeAuth = useCallback(async (): Promise<boolean> => {
    try {
      setIsLoading(true);
      setError(null);
      
      // Only run on client side
      if (typeof window === 'undefined') {
        setIsLoading(false);
        return false;
      }
      
      logger.debug('Initializing Keycloak...');
      
      // Create a new Keycloak instance
      const keycloakConfig = {
        url: process.env.NEXT_PUBLIC_KEYCLOAK_URL,
        realm: process.env.NEXT_PUBLIC_KEYCLOAK_REALM || 'dive25',
        clientId: process.env.NEXT_PUBLIC_KEYCLOAK_CLIENT_ID || 'dive25-frontend'
      };
      
      logger.debug('Keycloak config:', keycloakConfig);
      
      const keycloakInstance = new Keycloak(keycloakConfig);
      
      // Set up event listeners
      keycloakInstance.onTokenExpired = () => {
        logger.debug('Token expired event triggered');
        refreshToken();
      };
      
      // Initialize Keycloak
      const authenticated = await keycloakInstance.init({
        onLoad: 'check-sso',
        silentCheckSsoRedirectUri: window.location.origin + '/silent-check-sso.html',
        pkceMethod: 'S256',
        checkLoginIframe: false, // Disable iframe checks to prevent issues
        enableLogging: true
      });
      
      logger.info(`Keycloak initialized, authenticated: ${authenticated}`);
      
      // Store instance
      window.__keycloak = keycloakInstance;
      setKeycloak(keycloakInstance);
      setIsAuthenticated(authenticated);
      
      if (authenticated) {
        try {
          // Extract user info from token
          const tokenParsed = keycloakInstance.tokenParsed || {};
          const realmAccess = tokenParsed.realm_access || { roles: [] };
          
          const userProfile: User = {
            uniqueId: tokenParsed.sub || '',
            username: tokenParsed.preferred_username || '',
            email: tokenParsed.email || '',
            givenName: tokenParsed.given_name || '',
            surname: tokenParsed.family_name || '',
            organization: tokenParsed.organization || '',
            countryOfAffiliation: tokenParsed.countryOfAffiliation || '',
            clearance: tokenParsed.clearance || '',
            roles: realmAccess.roles || [],
          };
          
          setUser(userProfile);
          logger.debug('User profile set:', userProfile);
          
          // Set up token refresh before expiration
          if (tokenParsed.exp) {
            const expiryTime = tokenParsed.exp;
            const currentTime = Math.floor(Date.now() / 1000);
            const timeUntilExpiry = expiryTime - currentTime;
            
            logger.debug(`Token expires in ${timeUntilExpiry} seconds`);
            
            // If token is about to expire, refresh it immediately
            if (timeUntilExpiry < TOKEN_REFRESH_BUFFER) {
              logger.debug('Token near expiry, refreshing immediately');
              refreshToken();
            }
          }
        } catch (error) {
          logger.error('Error processing authenticated user:', error);
          toast.error('Error processing user information');
        }
      }
      
      return authenticated;
    } catch (err) {
      logger.error('Failed to initialize Keycloak:', err);
      setError('Failed to initialize authentication service');
      toast.error('Authentication initialization failed');
      return false;
    } finally {
      setIsLoading(false);
    }
  }, [refreshToken]);
  
  // Check if authentication should be initialized based on current route
  useEffect(() => {
    const shouldInitialize = autoInitialize || 
      AUTH_PATHS.some(path => router.pathname.startsWith(path));
    
    if (shouldInitialize && !keycloak) {
      logger.debug(`Initializing auth due to route: ${router.pathname}`);
      initializeAuth();
    }
  }, [router.pathname, autoInitialize, initializeAuth, keycloak]);
  
  // Login function
  const login = useCallback(() => {
    // Store current path for redirect after login
    if (typeof window !== 'undefined') {
      const redirectPath = router.asPath !== '/login' ? router.asPath : '/';
      sessionStorage.setItem('auth_redirect', redirectPath);
    }
    
    const performLogin = (kc: Keycloak) => {
      try {
        const loginOptions: KeycloakLoginOptions = {
          redirectUri: window.location.origin + '/auth/callback',
          prompt: 'login'
        };
        
        logger.debug('Initiating login with options:', loginOptions);
        kc.login(loginOptions);
      } catch (error) {
        logger.error('Error during login:', error);
        toast.error('Failed to initialize login');
      }
    };
    
    if (keycloak) {
      performLogin(keycloak);
    } else {
      // Initialize Keycloak if it isn't initialized yet
      logger.debug('Keycloak not initialized, initializing before login');
      initializeAuth().then(success => {
        if (success && window.__keycloak) {
          performLogin(window.__keycloak);
        } else {
          toast.error('Could not initialize authentication service');
        }
      });
    }
  }, [keycloak, router.asPath, initializeAuth]);
  
  // Provide loading UI if initializing
  if (isLoading) {
    return (
      <div className="flex justify-center items-center min-h-screen">
        <Spinner size="lg" />
        <p className="ml-2 text-gray-600">Initializing authentication...</p>
      </div>
    );
  }
  
  return (
    <AuthContext.Provider value={{
      isAuthenticated,
      isLoading,
      user,
      keycloak,
      login,
      logout,
      refreshToken,
      hasRole,
      error
    }}>
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