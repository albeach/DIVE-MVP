// frontend/src/context/auth-context.tsx
import React, { createContext, useContext, useState, useEffect, ReactNode } from 'react';
import { useRouter } from 'next/router';
import Keycloak from 'keycloak-js';
import { User } from '@/types/user';
import { Spinner } from '@/components/ui/Spinner';

interface AuthContextProps {
  isAuthenticated: boolean;
  isLoading: boolean;
  user: User | null;
  keycloak: Keycloak | null;
  login: () => void;
  logout: () => void;
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

        const authenticated = await keycloakInstance.init({
          onLoad: 'check-sso',
          silentCheckSsoRedirectUri: window.location.origin + '/silent-check-sso.html',
          pkceMethod: 'S256',
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

          // Set up token refresh
          keycloakInstance.onTokenExpired = () => {
            keycloakInstance.updateToken(30).catch(() => {
              console.error('Failed to refresh token');
            });
          };
        }

        setIsLoading(false);
      } catch (error) {
        console.error('Keycloak initialization failed:', error);
        setIsLoading(false);
      }
    };

    initKeycloak();
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

  const value = {
    isAuthenticated,
    isLoading,
    user,
    keycloak,
    login,
    logout
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