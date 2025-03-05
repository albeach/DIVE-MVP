// frontend/src/context/auth-context.tsx
import React, { createContext, useContext, useState, useEffect, ReactNode, useRef, useCallback } from 'react';
import { useRouter } from 'next/router';
import Keycloak from 'keycloak-js';
import { User } from '@/types/user';
import { Spinner } from '@/components/ui/Spinner';
import toast from 'react-hot-toast';
import { getKeycloak } from '@/lib/keycloak';
import { createLogger } from '@/utils/logger';

// Create a logger for auth context
const logger = createLogger('AuthContext');

// Token refresh buffer constants
const TOKEN_REFRESH_BUFFER = 120; // 2 minutes
const TOKEN_CHECK_INTERVAL = 10000; // 10 seconds
const SESSION_STORAGE_TOKEN_KEY = 'kc_token';
const SESSION_STORAGE_REFRESH_TOKEN_KEY = 'kc_refreshToken';

interface AuthContextProps {
  isAuthenticated: boolean;
  isLoading: boolean;
  user: User | null;
  keycloak: Keycloak | null;
  login: () => void;
  logout: () => void;
  refreshToken: () => Promise<boolean>;
  hasRole: (roles: string[]) => boolean;
  tokenExpiresIn: number | null;
  isTokenExpiring: boolean;
  initializeAuth: () => Promise<boolean>;
  getUserSecurityAttributes: () => UserSecurityAttributes;
  updateUserInformation: () => Promise<User | null>;
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
    __keycloak?: Keycloak;
  }
}

export function AuthProvider({ children, autoInitialize = false }: AuthProviderProps) {
  const [keycloak, setKeycloak] = useState<Keycloak | null>(null);
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [user, setUser] = useState<User | null>(null);
  const [initError, setInitError] = useState<string | null>(null);
  const [tokenExpiresIn, setTokenExpiresIn] = useState<number | null>(null);
  const [isTokenExpiring, setIsTokenExpiring] = useState<boolean>(false);
  const [initializationComplete, setInitializationComplete] = useState(false);
  const tokenCheckIntervalRef = useRef<NodeJS.Timeout | null>(null);
  const router = useRouter();

  // Calculate time until token expires and update state
  const updateTokenExpiry = useCallback((keycloakInstance: Keycloak) => {
    if (keycloakInstance && keycloakInstance.tokenParsed?.exp) {
      const currentTime = Math.floor(Date.now() / 1000);
      const expiryTime = keycloakInstance.tokenParsed.exp;
      const timeRemaining = expiryTime - currentTime;
      
      setTokenExpiresIn(timeRemaining);
      setIsTokenExpiring(timeRemaining < TOKEN_REFRESH_BUFFER);
      
      // Log expiry status (but not too frequently)
      if (timeRemaining < 300 || timeRemaining % 60 === 0) {
        logger.debug(`Token expires in ${timeRemaining} seconds`);
      }
      
      // Proactively refresh token if it's close to expiring
      if (timeRemaining < TOKEN_REFRESH_BUFFER && timeRemaining > 0) {
        logger.debug('Token nearing expiry, refreshing...');
        keycloakInstance.updateToken(TOKEN_REFRESH_BUFFER).catch((error) => {
          logger.warn('Failed to refresh token proactively', error);
        });
      }
    } else {
      setTokenExpiresIn(null);
      setIsTokenExpiring(false);
    }
  }, []);

  // Start periodic token check
  const startTokenExpiryCheck = useCallback((keycloakInstance: Keycloak) => {
    // Clear any existing interval
    if (tokenCheckIntervalRef.current) {
      clearInterval(tokenCheckIntervalRef.current);
      tokenCheckIntervalRef.current = null;
    }
    
    // Set initial expiry time
    updateTokenExpiry(keycloakInstance);
    
    // Start interval to check token expiry
    tokenCheckIntervalRef.current = setInterval(() => {
      if (keycloakInstance && keycloakInstance.authenticated) {
        updateTokenExpiry(keycloakInstance);
      } else if (keycloakInstance && !keycloakInstance.authenticated) {
        logger.warn('Token check interval found unauthenticated keycloak instance');
        clearInterval(tokenCheckIntervalRef.current!);
        tokenCheckIntervalRef.current = null;
      }
    }, TOKEN_CHECK_INTERVAL);

    return () => {
      if (tokenCheckIntervalRef.current) {
        clearInterval(tokenCheckIntervalRef.current);
        tokenCheckIntervalRef.current = null;
      }
    };
  }, [updateTokenExpiry]);

  // Listen for API token expiration headers
  useEffect(() => {
    if (!isAuthenticated || !keycloak) return;
    
    // Create a response interceptor for fetch
    const originalFetch = window.fetch;
    window.fetch = async function(input, init) {
      const response = await originalFetch(input, init);
      
      // Check for token expiration headers from our API
      if (response.headers.has('X-Token-Expiring')) {
        const expiresIn = response.headers.get('X-Token-Expires-In');
        logger.debug(`API reports token expiring in ${expiresIn} seconds`);
        
        // Refresh the token if needed
        if (keycloak && parseInt(expiresIn || '0', 10) < TOKEN_REFRESH_BUFFER) {
          try {
            await keycloak.updateToken(TOKEN_REFRESH_BUFFER);
            logger.debug('Token refreshed due to API expiry notification');
            
            // Update stored tokens
            if (keycloak.token) {
              sessionStorage.setItem(SESSION_STORAGE_TOKEN_KEY, keycloak.token);
            }
            if (keycloak.refreshToken) {
              sessionStorage.setItem(SESSION_STORAGE_REFRESH_TOKEN_KEY, keycloak.refreshToken);
            }
            
            // Update local expiry tracking
            updateTokenExpiry(keycloak);
          } catch (error) {
            logger.error('Token refresh failed after API notification:', error);
          }
        }
      }
      
      return response;
    };
    
    // Cleanup on unmount
    return () => {
      window.fetch = originalFetch;
    };
  }, [isAuthenticated, keycloak, updateTokenExpiry]);

  // Helper function to extract user from token
  const updateUserFromToken = useCallback((keycloakInstance: Keycloak) => {
    if (!keycloakInstance || !keycloakInstance.tokenParsed) return null;
    
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
    logger.debug('User profile updated from token', {
      username: userProfile.username,
      roles: userProfile.roles
    });
    
    return userProfile as User;
  }, []);

  // Initialize Keycloak
  const initKeycloak = async (): Promise<boolean> => {
    if (isLoading || initializationComplete) return isAuthenticated;
    
    setIsLoading(true);
    logger.debug('Initializing Keycloak...');
    
    try {
      logger.time('keycloak-init');
      
      // Use our configured Keycloak instance
      const keycloakInstance = getKeycloak();

      // First check if we already have an initialized instance
      if (window.__keycloak?.authenticated) {
        logger.debug('Using existing authenticated Keycloak instance');
        setKeycloak(window.__keycloak);
        setIsAuthenticated(true);
        updateUserFromToken(window.__keycloak);
        startTokenExpiryCheck(window.__keycloak);
        setInitializationComplete(true);
        setIsLoading(false);
        return true;
      }

      // Configure token refresh behavior
      keycloakInstance.onTokenExpired = () => {
        logger.debug('Token expired, attempting to refresh...');
        keycloakInstance.updateToken(30).catch((error) => {
          logger.warn('Token refresh failed after expiry', error);
          setIsAuthenticated(false);
        });
      };

      // Calculate the silent check URI with explicit protocol
      const origin = window.location.origin;
      const silentCheckUri = `${origin}/silent-check-sso.html`;
      
      logger.debug('Using silent check URI:', silentCheckUri);
      
      // Check if this is a protected route that requires stricter authentication
      const isProtectedRoute = window.location.pathname.startsWith('/auth') || 
                               window.location.pathname.startsWith('/api/auth') ||
                               window.location.pathname === '/profile';
      
      // Get stored tokens (if any)
      const storedToken = sessionStorage.getItem(SESSION_STORAGE_TOKEN_KEY);
      const storedRefreshToken = sessionStorage.getItem(SESSION_STORAGE_REFRESH_TOKEN_KEY);
      
      // Configure initialization options
      const initOptions = {
        onLoad: 'check-sso' as const,
        silentCheckSsoRedirectUri: silentCheckUri,
        pkceMethod: 'S256' as const,
        // Disable iframe checks completely on public routes to prevent CSP issues
        checkLoginIframe: isProtectedRoute, 
        enableLogging: true,
        flow: 'standard' as const,
        responseMode: 'fragment' as const,
        checkLoginIframeInterval: 5,
        promiseType: 'native' as const,
        token: storedToken || undefined,
        refreshToken: storedRefreshToken || undefined
      };
      
      // Initialize Keycloak
      const authenticated = await keycloakInstance.init(initOptions);
      logger.timeEnd('keycloak-init');
      logger.debug(`Keycloak initialized, authenticated: ${authenticated}`);

      // Store globally
      window.__keycloak = keycloakInstance;
      
      setKeycloak(keycloakInstance);
      setIsAuthenticated(authenticated);

      if (authenticated) {
        // Store tokens in sessionStorage for resilience against page refreshes
        sessionStorage.setItem(SESSION_STORAGE_TOKEN_KEY, keycloakInstance.token || '');
        sessionStorage.setItem(SESSION_STORAGE_REFRESH_TOKEN_KEY, keycloakInstance.refreshToken || '');
        
        // Start monitoring token expiry
        startTokenExpiryCheck(keycloakInstance);
        
        // Extract user information from token
        updateUserFromToken(keycloakInstance);
      }
      
      setInitializationComplete(true);
      return authenticated;
    } catch (error) {
      logger.error('Failed to initialize Keycloak', error);
      setInitError(error instanceof Error ? error.message : 'Unknown error');
      setIsAuthenticated(false);
      setInitializationComplete(true);
      return false;
    } finally {
      setIsLoading(false);
    }
  };

  // Check if current path should trigger authentication
  const shouldAuthenticate = useCallback((path: string): boolean => {
    return AUTH_PATHS.some(authPath => path.startsWith(authPath));
  }, []);

  // Auto-initialize if configured to do so
  useEffect(() => {
    // Skip initialization on the server
    if (typeof window === 'undefined') return;
    
    // Auto-initialize if explicitly requested OR the path requires auth
    if (autoInitialize || shouldAuthenticate(window.location.pathname)) {
      initKeycloak();
    }
  }, [autoInitialize, shouldAuthenticate]);

  // Login function - will initialize Keycloak if needed
  const login = async () => {
    try {
      // Make sure Keycloak is initialized first
      if (!initializationComplete) {
        await initKeycloak();
      }
      
      if (keycloak) {
        // Store the current path to redirect back after login
        const currentPath = window.location.pathname + window.location.search;
        if (currentPath !== '/' && !currentPath.includes('/login') && !currentPath.includes('/auth/') && !currentPath.includes('/callback')) {
          sessionStorage.setItem('auth_redirect', currentPath);
        }
        
        keycloak.login();
      } else {
        logger.error("Keycloak not initialized for login");
        throw new Error("Authentication service not available");
      }
    } catch (error) {
      logger.error('Login failed', error);
      toast.error('Login failed. Please try again.');
    }
  };

  // Logout function
  const logout = useCallback(() => {
    if (keycloak && keycloak.authenticated) {
      try {
        // Clear tokens from storage
        sessionStorage.removeItem(SESSION_STORAGE_TOKEN_KEY);
        sessionStorage.removeItem(SESSION_STORAGE_REFRESH_TOKEN_KEY);
        
        // Clear interval
        if (tokenCheckIntervalRef.current) {
          clearInterval(tokenCheckIntervalRef.current);
          tokenCheckIntervalRef.current = null;
        }
        
        // Clear state
        setUser(null);
        setIsAuthenticated(false);
        
        // Redirect to Keycloak logout
        keycloak.logout();
      } catch (error) {
        logger.error('Logout error', error);
        toast.error('Logout failed. Please try again.');
      }
    } else {
      // Not authenticated, just redirect to home
      router.push('/');
    }
  }, [keycloak, router]);
  
  // Refresh token function
  const refreshToken = async (): Promise<boolean> => {
    if (!keycloak) {
      logger.warn('Token refresh failed: Keycloak not initialized');
      return false;
    }
    
    try {
      const refreshed = await keycloak.updateToken(TOKEN_REFRESH_BUFFER);
      if (refreshed) {
        logger.debug('Token refreshed successfully');
        
        // Update stored tokens
        sessionStorage.setItem(SESSION_STORAGE_TOKEN_KEY, keycloak.token || '');
        sessionStorage.setItem(SESSION_STORAGE_REFRESH_TOKEN_KEY, keycloak.refreshToken || '');
        
        // Update expiry information
        updateTokenExpiry(keycloak);
      } else {
        logger.debug('Token still valid, not refreshed');
      }
      return true;
    } catch (error) {
      logger.error('Token refresh failed', error);
      setIsAuthenticated(false);
      return false;
    }
  };

  // Check if user has any of the specified roles
  const hasRole = useCallback((roles: string[]): boolean => {
    if (!keycloak || !roles.length) return false;
    
    return roles.some(role => keycloak.hasRealmRole(role));
  }, [keycloak]);
  
  // Get user security attributes
  const getUserSecurityAttributes = useCallback((): UserSecurityAttributes => {
    return {
      clearance: user?.clearance || '',
      caveats: user?.caveats || [],
      coi: user?.coi || [],
      countryOfAffiliation: user?.countryOfAffiliation || ''
    };
  }, [user]);
  
  // Update user information from Keycloak
  const updateUserInformation = async (): Promise<User | null> => {
    if (!keycloak || !keycloak.authenticated) {
      logger.warn('Cannot update user info: not authenticated');
      return null;
    }
    
    try {
      await keycloak.loadUserProfile();
      const updatedUser = updateUserFromToken(keycloak);
      return updatedUser;
    } catch (error) {
      logger.error('Failed to update user information', error);
      return null;
    }
  };

  // Provide auth context
  const authContextValue: AuthContextProps = {
    isAuthenticated,
    isLoading,
    user,
    keycloak,
    login,
    logout,
    refreshToken,
    hasRole,
    tokenExpiresIn,
    isTokenExpiring,
    initializeAuth: initKeycloak,
    getUserSecurityAttributes,
    updateUserInformation
  };

  if (isLoading) {
    return <div className="flex h-screen items-center justify-center"><Spinner size="lg" /></div>;
  }

  return (
    <AuthContext.Provider value={authContextValue}>
      {initError && <div className="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded fixed top-0 right-0 m-4 z-50">
        Authentication Error: {initError}
      </div>}
      {children}
    </AuthContext.Provider>
  );
}

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};