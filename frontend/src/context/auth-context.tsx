// frontend/src/context/auth-context.tsx
import React, { createContext, useContext, useState, useEffect, ReactNode, useCallback } from 'react';
import { useRouter } from 'next/router';
import Keycloak, { KeycloakLoginOptions } from 'keycloak-js';
import { User } from '@/types/user';
import { Spinner } from '@/components/ui/Spinner';
import toast from 'react-hot-toast';
import { createLogger } from '@/utils/logger';
import { createIdpRedirectUrl } from '@/lib/keycloak';

// Create a logger for auth context
const logger = createLogger('AuthContext');

// Token refresh buffer constants
const TOKEN_REFRESH_BUFFER = 60; // Refresh token 60 seconds before expiry

// Define the country IdP interface
export interface CountryIdP {
  id: string;
  name: string;
  flag: string;
}

// List of supported country IdPs
export const COUNTRY_IDPS: CountryIdP[] = [
  { id: 'usa-oidc', name: 'United States', flag: '🇺🇸' },
  { id: 'uk-oidc', name: 'United Kingdom', flag: '🇬🇧' },
  { id: 'canada-oidc', name: 'Canada', flag: '🇨🇦' },
  { id: 'australia-oidc', name: 'Australia', flag: '🇦🇺' },
  { id: 'newzealand-oidc', name: 'New Zealand', flag: '🇳🇿' }
];

interface AuthContextProps {
  isAuthenticated: boolean;
  isLoading: boolean;
  user: User | null;
  keycloak: Keycloak | null;
  login: (countryIdP?: string) => void;
  logout: () => void;
  refreshToken: () => Promise<boolean>;
  hasRole: (roles: string[]) => boolean;
  error: string | null;
  tokenExpiresIn: number | null; // Time in seconds until token expires
  isTokenExpiring: boolean; // Flag indicating if token is expiring soon
  getAuthHeaders: () => Record<string, string>; // Method to get auth headers for API requests
  countryIdPs: CountryIdP[]; // List of supported country IdPs
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

// List of paths that should never trigger authentication
const NON_AUTH_PATHS = ['/', '/country-select', '/login'];

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
  const [tokenExpiresIn, setTokenExpiresIn] = useState<number | null>(null);
  const [isTokenExpiring, setIsTokenExpiring] = useState(false);
  const router = useRouter();
  
  // Function to update token expiration time
  const updateTokenExpiration = useCallback(() => {
    if (!keycloak || !keycloak.tokenParsed || !keycloak.tokenParsed.exp) {
      setTokenExpiresIn(null);
      setIsTokenExpiring(false);
      return;
    }
    
    const expiryTime = keycloak.tokenParsed.exp;
    const currentTime = Math.floor(Date.now() / 1000);
    const timeUntilExpiry = expiryTime - currentTime;
    
    setTokenExpiresIn(timeUntilExpiry > 0 ? timeUntilExpiry : 0);
    setIsTokenExpiring(timeUntilExpiry < TOKEN_REFRESH_BUFFER * 2);
    
    logger.debug(`Token expires in ${timeUntilExpiry} seconds, isExpiring: ${timeUntilExpiry < TOKEN_REFRESH_BUFFER * 2}`);
  }, [keycloak]);
  
  // Set up periodic token expiration check
  useEffect(() => {
    if (!keycloak || !keycloak.authenticated) return;
    
    // Update immediately
    updateTokenExpiration();
    
    // Then set up interval to check regularly
    const interval = setInterval(updateTokenExpiration, 1000);
    
    return () => clearInterval(interval);
  }, [keycloak, updateTokenExpiration]);
  
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
        updateTokenExpiration(); // Update token expiration after refresh
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
  }, [keycloak, updateTokenExpiration]);
  
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
  
  // Function to get auth headers for API requests
  const getAuthHeaders = useCallback((): Record<string, string> => {
    if (!keycloak || !keycloak.token) {
      logger.warn('Cannot get auth headers - no token available');
      return {};
    }
    
    return {
      'Authorization': `Bearer ${keycloak.token}`
    };
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
      
      if (!keycloakConfig.url || !keycloakConfig.realm || !keycloakConfig.clientId) {
        const errorMessage = `Missing Keycloak configuration: url=${keycloakConfig.url}, realm=${keycloakConfig.realm}, clientId=${keycloakConfig.clientId}`;
        logger.error(errorMessage);
        setError(errorMessage);
        setIsLoading(false);
        return false;
      }
      
      try {
        const keycloakInstance = new Keycloak(keycloakConfig);
        
        // Set up event listeners
        keycloakInstance.onTokenExpired = () => {
          logger.debug('Token expired event triggered');
          refreshToken();
        };
        
        // Initialize Keycloak - For country selection flow, we don't check SSO right away
        // We just initialize the instance without authentication since users will first
        // choose a country IdP
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
            
            // Parse caveats and coi to ensure they're arrays
            let caveatsArray = tokenParsed.caveats || [];
            let coiArray = tokenParsed.coi || [];
            
            // Handle case where caveats is a string (parse JSON or split)
            if (typeof tokenParsed.caveats === 'string') {
              try {
                // Try to parse as JSON
                caveatsArray = JSON.parse(tokenParsed.caveats);
              } catch (e) {
                // If parsing fails, split by comma
                caveatsArray = tokenParsed.caveats.split(',').map(item => item.trim()).filter(Boolean);
              }
            }
            
            // Handle case where coi is a string (parse JSON or split)
            if (typeof tokenParsed.coi === 'string') {
              try {
                // Try to parse as JSON
                coiArray = JSON.parse(tokenParsed.coi);
              } catch (e) {
                // If parsing fails, split by comma
                coiArray = tokenParsed.coi.split(',').map(item => item.trim()).filter(Boolean);
              }
            }
            
            const userProfile: User = {
              uniqueId: tokenParsed.sub || '',
              username: tokenParsed.preferred_username || '',
              email: tokenParsed.email || '',
              givenName: tokenParsed.given_name || '',
              surname: tokenParsed.family_name || '',
              organization: tokenParsed.organization || '',
              countryOfAffiliation: tokenParsed.countryOfAffiliation || '',
              clearance: tokenParsed.clearance || '',
              caveats: caveatsArray,
              coi: coiArray,
              roles: realmAccess.roles || [],
              lastLogin: tokenParsed.lastLogin || null,
            };
            
            logger.debug('User profile set:', userProfile);
            logger.debug('Token parsed:', tokenParsed);
            
            setUser(userProfile);
            
            // Set up token refresh before expiration
            if (tokenParsed.exp) {
              const expiryTime = tokenParsed.exp;
              const currentTime = Math.floor(Date.now() / 1000);
              const timeUntilExpiry = expiryTime - currentTime;
              
              logger.debug(`Token expires in ${timeUntilExpiry} seconds`);
              
              // Update token expiration time
              setTokenExpiresIn(timeUntilExpiry > 0 ? timeUntilExpiry : 0);
              setIsTokenExpiring(timeUntilExpiry < TOKEN_REFRESH_BUFFER * 2);
              
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
        
        // Even if not authenticated, initialization is considered successful
        // This allows the country selection flow to work
        setIsLoading(false);
        return true;
        
      } catch (initError) {
        const errorMessage = `Error initializing Keycloak: ${initError instanceof Error ? initError.message : String(initError)}`;
        logger.error(errorMessage);
        logger.error('Full error:', initError);
        setError(errorMessage);
        setIsLoading(false);
        return false;
      }
    } catch (outerError) {
      const errorMessage = `Unexpected error initializing auth: ${outerError instanceof Error ? outerError.message : String(outerError)}`;
      logger.error(errorMessage);
      setError(errorMessage);
      setIsLoading(false);
      return false;
    }
  }, [refreshToken, router.pathname]);
  
  // Check if authentication should be initialized based on current route
  useEffect(() => {
    // Skip auth initialization for:
    // 1. Explicitly excluded paths (NON_AUTH_PATHS)
    // 2. Keycloak broker URLs (containing '/broker/')
    // 3. Any Keycloak realm URLs (containing '/realms/')
    const isKeycloakUrl = router.pathname.includes('/broker/') || 
                         router.pathname.includes('/realms/');
    
    const shouldInitialize = autoInitialize && 
      !NON_AUTH_PATHS.some(path => router.pathname === path) &&
      !isKeycloakUrl;
    
    if (shouldInitialize && !keycloak) {
      logger.debug(`Initializing auth due to route: ${router.pathname}`);
      initializeAuth();
    } else {
      logger.debug(`Skipping auth initialization for path: ${router.pathname}`);
    }
  }, [router.pathname, autoInitialize, initializeAuth, keycloak]);
  
  // Login function - enhanced to support country IdP selection
  const login = useCallback((countryIdP?: string) => {
    if (!keycloak) {
      logger.error('Cannot login - no Keycloak instance');
      return;
    }
    
    try {
      // Store current location for redirect after login if not already in sessionStorage
      if (!sessionStorage.getItem('auth_redirect') && window.location.pathname !== '/country-select') {
        sessionStorage.setItem('auth_redirect', window.location.pathname);
      }
      
      logger.debug('Initiating login process');
      
      // If a specific country IdP is selected, redirect to that IdP
      if (countryIdP) {
        logger.info(`Logging in with country IdP: ${countryIdP}`);
        
        // Use the utility function to get a consistent URL for the IdP redirect
        const idpRedirectUrl = createIdpRedirectUrl(countryIdP);
        
        logger.debug(`Redirecting to IdP: ${idpRedirectUrl}`);
        window.location.href = idpRedirectUrl;
        return;
      }
      
      // If no country selected, redirect to country selection page
      logger.debug('No country IdP selected, redirecting to country selection');
      router.push('/country-select');
    } catch (error) {
      logger.error('Error during login:', error);
      setError('Login failed. Please try again.');
    }
  }, [keycloak, router]);
  
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
    <AuthContext.Provider
      value={{
        isAuthenticated,
        isLoading,
        user,
        keycloak,
        login,
        logout,
        refreshToken,
        hasRole,
        error,
        tokenExpiresIn,
        isTokenExpiring,
        getAuthHeaders,
        countryIdPs: COUNTRY_IDPS
      }}
    >
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