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
        console.time('keycloak-total-init');
        // Log the environment configuration for debugging
        console.log('Environment configuration:', {
          keycloakUrl: process.env.NEXT_PUBLIC_KEYCLOAK_URL || 'http://localhost:8080',
          realm: process.env.NEXT_PUBLIC_KEYCLOAK_REALM || 'dive25',
          clientId: process.env.NEXT_PUBLIC_KEYCLOAK_CLIENT_ID || 'dive25-frontend'
        });

        // Create keycloak instance with full URL
        const keycloakInstance = new Keycloak({
          url: (process.env.NEXT_PUBLIC_KEYCLOAK_URL || 'http://localhost:8080') + '/auth',
          realm: process.env.NEXT_PUBLIC_KEYCLOAK_REALM || 'dive25',
          clientId: process.env.NEXT_PUBLIC_KEYCLOAK_CLIENT_ID || 'dive25-frontend'
        });

        console.log('Initializing Keycloak instance...');

        // Add a global error handler
        const originalOnError = window.onerror;
        window.onerror = function(message, source, lineno, colno, error) {
          console.log('Global error caught:', { message, source, lineno, colno });
          
          // Handle Keycloak-specific errors
          if (message && typeof message === 'string' && 
              (message.includes('Timeout when waiting for 3rd party check iframe message') || 
               message.includes('Blocked a frame with origin') ||
               message.includes('Failed to initialize') ||
               message.includes('Keycloak'))) {
            console.warn('Intercepted Keycloak error:', message);
            // Don't prevent other handlers from running, but log it
            return false;
          }
          
          // Call the original handler if it exists
          return originalOnError ? originalOnError(message, source, lineno, colno, error) : false;
        };

        // Simplified cookie check - we'll just rely on the actual auth flow
        // to determine if cookies are working, rather than a separate check
        /* 
        // This check was slowing down initialization
        const checkThirdPartyCookies = () => {
          try {
            // Try to create a test iframe to detect third-party cookie blocking
            const iframe = document.createElement('iframe');
            iframe.style.display = 'none';
            iframe.src = `${process.env.NEXT_PUBLIC_KEYCLOAK_URL || 'http://localhost:8080'}/auth/realms/${process.env.NEXT_PUBLIC_KEYCLOAK_REALM || 'dive25'}/protocol/openid-connect/login-status-iframe.html`;
            
            iframe.onload = () => {
              try {
                // Try to access the iframe's content
                const iframeContent = iframe.contentWindow || iframe.contentDocument;
                if (!iframeContent) {
                  console.warn('Cannot access iframe content - possible third-party cookie blocking');
                }
              } catch (e) {
                console.warn('Third-party cookies appear to be blocked by browser', e);
              } finally {
                // Clean up
                document.body.removeChild(iframe);
              }
            };
            
            document.body.appendChild(iframe);
          } catch (e) {
            console.warn('Error checking for third-party cookies:', e);
          }
        };
        
        // Run the check
        checkThirdPartyCookies();
        */

        // Configure token refresh behavior
        keycloakInstance.onTokenExpired = () => {
          console.log('Token expired, attempting to refresh...');
          keycloakInstance.updateToken(30).catch(() => {
            console.warn('Token refresh failed');
            // Don't auto-redirect to login on silent token refresh failure
            setIsAuthenticated(false);
          });
        };

        // Use direct access grants for simplicity if standard flow fails
        try {
          console.log('Attempting Keycloak initialization...');
          // Calculate the silent check URI with explicit protocol
          const protocol = window.location.protocol;
          const host = window.location.host;
          const silentCheckUri = `${protocol}//${host}/silent-check-sso.html`;
          console.log('Using silent check URI:', silentCheckUri);
          
          const initOptions = {
            onLoad: 'login-required' as const,
            silentCheckSsoRedirectUri: silentCheckUri,
            pkceMethod: 'S256' as const,
            checkLoginIframe: false,
            enableLogging: true,
            flow: 'standard' as const,
            responseMode: 'fragment' as const,
            checkLoginIframeInterval: 0,
            silentCheckSsoFallback: false,
            messageReceiveTimeout: 3000 // Reduced to 3 seconds for faster initialization
          };
          
          console.log('Keycloak init options:', initOptions);
          console.time('keycloak-init-call');
          const authenticated = await keycloakInstance.init(initOptions);
          console.timeEnd('keycloak-init-call');
          console.log('Keycloak initialized with auth status:', authenticated);

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
              caveats: keycloakInstance.tokenParsed?.caveats || [],
              coi: keycloakInstance.tokenParsed?.coi || [],
              roles: keycloakInstance.tokenParsed?.realm_access?.roles || [],
              lastLogin: new Date().toISOString(),
            };
            
            setUser(userProfile as User);
            
            // Expose keycloak instance for API client
            window.__keycloak = keycloakInstance;
            
            console.log('User authenticated successfully:', userProfile.username);
          } else {
            console.log('User not authenticated');
          }

        } catch (initError) {
          console.error('Standard flow initialization failed:', initError);
          setInitError('Keycloak initialization failed. Please try again or contact support.');
          // Continue without authentication
        }

        setIsLoading(false);
      } catch (error) {
        console.error('Keycloak initialization failed:', error);
        setInitError('Authentication service initialization failed');
        toast.error('Authentication service initialization failed');
        setIsLoading(false);
      }
    };

    initKeycloak();

    // Cleanup function
    return () => {
      // Clear the global keycloak instance
      if (window.__keycloak) {
        window.__keycloak = undefined;
      }
    };
  }, []);

  // Login function
  const login = () => {
    if (keycloak) {
      try {
        // Ensure we're using the same protocol for redirects
        const redirectUrl = window.location.origin + router.pathname;
        console.log('Login redirect URL:', redirectUrl);
        
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
        // Force reload as a fallback
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
    if (!user || !user.roles || user.roles.length === 0) {
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