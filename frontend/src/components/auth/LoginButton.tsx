import React, { useState } from 'react';
import { useAuth } from '@/context/auth-context';
import { User } from '@/types/user';
import toast from 'react-hot-toast';
import { createLogger } from '@/utils/logger';

// Create a logger for LoginButton
const logger = createLogger('LoginButton');

interface LoginButtonProps {
  className?: string;
  variant?: 'primary' | 'secondary' | 'outline';
  size?: 'sm' | 'md' | 'lg';
  label?: string;
}

const LoginButton: React.FC<LoginButtonProps> = ({
  className = '',
  variant = 'primary',
  size = 'md',
  label = 'Sign In'
}) => {
  const [isLoggingIn, setIsLoggingIn] = useState(false);
  
  // Safely try to get auth context
  let auth: any = {};
  let isAuthenticated = false;
  let user: User | null = null;
  
  try {
    auth = useAuth();
    isAuthenticated = auth?.isAuthenticated || false;
    user = auth.user;
  } catch (error) {
    logger.warn('Auth context not available in LoginButton');
  }
  
  // Safely access auth methods with fallbacks
  const login = auth?.login || (() => {});
  const logout = auth?.logout || (() => {});
  const initializeAuth = auth?.initializeAuth || (() => Promise.resolve(false));
  
  const handleLogin = async () => {
    try {
      setIsLoggingIn(true);
      
      // Display a loading toast
      toast.loading('Initializing login...', { id: 'login-process' });
      
      // Try to initialize auth first if it's available
      if (initializeAuth && !isAuthenticated) {
        logger.debug('Initializing auth before login');
        const initialized = await initializeAuth();
        if (!initialized) {
          logger.warn('Auth initialization failed, trying fallback');
          toast.dismiss('login-process');
          fallbackDirectLogin();
          return;
        }
      }
      
      // Try to login
      logger.debug('Calling login method');
      toast.dismiss('login-process');
      toast.loading('Redirecting to login...', { id: 'login-redirect' });
      
      await login();
      
      // If we get here without a redirect, try fallback
      setTimeout(() => {
        if (document.visibilityState !== 'hidden') {
          toast.dismiss('login-redirect');
          logger.warn('Login did not redirect, using fallback');
          fallbackDirectLogin();
        }
      }, 3000);
      
    } catch (error) {
      logger.error('Login error:', error);
      toast.dismiss('login-process');
      toast.dismiss('login-redirect');
      toast.error('Login failed. Trying direct method...');
      
      // Fallback to direct login if keycloak auth isn't initialized properly
      fallbackDirectLogin();
    } finally {
      // Don't set isLoggingIn to false until after a delay
      // to prevent multiple clicks during redirect
      setTimeout(() => {
        setIsLoggingIn(false);
      }, 5000);
    }
  };
  
  const handleLogout = () => {
    logout();
  };
  
  // Fallback login method that constructs auth URL
  const fallbackDirectLogin = () => {
    toast.loading('Attempting direct login...', { id: 'direct-login' });
    
    // Store current path for redirect after login
    const currentPath = window.location.pathname + window.location.search;
    if (currentPath !== '/' && !currentPath.includes('/login') && !currentPath.includes('/auth/')) {
      sessionStorage.setItem('auth_redirect', currentPath);
    }
    
    // Set redirect to documents for home page
    if (currentPath === '/' || currentPath === '/login') {
      sessionStorage.setItem('auth_redirect', '/documents');
    }
    
    // Construct auth URL directly with our callback page
    try {
      // CRITICAL: For direct login, always use the original Keycloak URL for the backend auth
      // but use the frontend URL for the UI parts like redirects
      const keycloakOriginalUrl = process.env.NEXT_PUBLIC_KEYCLOAK_URL;
      const frontendUrl = process.env.NEXT_PUBLIC_FRONTEND_URL || window.location.origin;
      const realm = process.env.NEXT_PUBLIC_KEYCLOAK_REALM;
      const clientId = process.env.NEXT_PUBLIC_KEYCLOAK_CLIENT_ID;
      
      if (!keycloakOriginalUrl || !realm || !clientId) {
        throw new Error('Missing Keycloak configuration');
      }
      
      logger.debug('Fallback login with configuration:', {
        keycloakOriginalUrl,
        frontendUrl,
        realm,
        clientId
      });
      
      // Use our dedicated callback page
      const redirectUri = encodeURIComponent(window.location.origin + '/auth/callback');
      
      // Generate a random state parameter for CSRF protection
      const state = crypto.randomUUID();
      
      // Generate a nonce for replay protection
      const nonce = crypto.randomUUID();
      
      // Generate code challenge for PKCE
      const codeVerifier = crypto.randomUUID() + crypto.randomUUID();
      sessionStorage.setItem('code_verifier', codeVerifier);
      
      // Hash the code verifier for the code challenge
      // For simplicity, we'll just use the first part of the verifier directly
      // In a production app, you would use a proper SHA-256 hash and base64url encoding
      const codeChallenge = codeVerifier.substring(0, 24);
      
      // For the auth backend operations, use the actual Keycloak URL directly
      // This avoids routing conflicts when the Kong routes are misconfigured
      const authUrl = `${keycloakOriginalUrl}/realms/${realm}/protocol/openid-connect/auth?` +
        `client_id=${clientId}` +
        `&redirect_uri=${redirectUri}` +
        `&state=${state}` +
        `&response_mode=query` +
        `&response_type=code` +
        `&scope=openid` +
        `&nonce=${nonce}` +
        `&prompt=login` +
        `&kc_theme=dive25` +
        `&ui_locales=en`;
      
      logger.debug('Redirecting to auth URL:', authUrl);
      
      // Add a small delay to ensure logs are visible before redirect
      setTimeout(() => {
        window.location.href = authUrl;
      }, 500);
    } catch (error) {
      logger.error('Fallback login failed:', error);
      toast.error('Login service unavailable. Please try again later.');
    }
  };
  
  // Button styling based on variant and size
  const variantClasses = {
    primary: 'bg-white/10 hover:bg-white/20 text-white border border-white/10 hover:border-white/20 backdrop-blur-sm shadow-sm',
    secondary: 'bg-white hover:bg-gray-50 text-primary-800 border border-primary-300 shadow-sm',
    outline: 'bg-transparent hover:bg-primary-50 text-primary-700 border border-primary-300',
  };
  
  const sizeClasses = {
    sm: 'text-sm px-3 py-1.5 rounded-md',
    md: 'text-base px-4 py-2 rounded-md',
    lg: 'text-base px-6 py-3 rounded-md font-medium',
  };
  
  const buttonText = isLoggingIn 
    ? 'Signing in...'
    : label || (isAuthenticated ? 'Sign out' : 'Sign in');
  
  return (
    <button
      className={`inline-flex items-center justify-center font-medium transition-all duration-300 focus:ring-2 focus:ring-offset-2 focus:ring-white/30 focus:outline-none disabled:opacity-50 ${variantClasses[variant]} ${sizeClasses[size]} ${className}`}
      onClick={isAuthenticated ? handleLogout : handleLogin}
      disabled={isLoggingIn}
    >
      {isLoggingIn && (
        <svg className="animate-spin -ml-1 mr-2 h-4 w-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
          <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
          <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
      )}
      {buttonText}
    </button>
  );
};

export default LoginButton; 