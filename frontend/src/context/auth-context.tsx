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
  const router = useRouter();

  // Initialize Keycloak
  useEffect(() => {
    const initKeycloak = async () => {
      try {
        const keycloakInstance = new Keycloak({
          url: process.env.NEXT_PUBLIC_KEYCLOAK_URL || 'http://localhost:8080',
          realm: process.env.NEXT_PUBLIC_KEYCLOAK_REALM || 'dive25',
          clientId: process.env.NEXT_PUBLIC_KEYCLOAK_CLIENT_ID || 'dive25-frontend'
        });

        keycloakInstance.onTokenExpired = () => {
          console.log('Token expired, attempting to refresh...');
          keycloakInstance.updateToken(30).catch(() => {
            toast.error('Your session has expired. Please log in again.');
            keycloakInstance.login();
          });
        };

        const authenticated = await keycloakInstance.init({
          onLoad: 'check-sso',
          silentCheckSsoRedirectUri: window.location.origin + '/silent-check-sso.html',
          pkceMethod: 'S256',
          checkLoginIframe: false
        });

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
        }

        setIsLoading(false);
      } catch (error) {
        console.error('Keycloak initialization failed:', error);
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
      keycloak.login({
        redirectUri: window.location.origin + router.pathname
      });
    }
  };

  // Logout function
  const logout = () => {
    if (keycloak) {
      keycloak.logout({
        redirectUri: window.location.origin
      });
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
    return roles.some(role => user.roles.includes(role));
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