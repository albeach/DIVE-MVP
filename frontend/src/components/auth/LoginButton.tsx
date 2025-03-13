import React, { useState } from 'react';
import { useAuth } from '@/context/auth-context';
import { User } from '@/types/user';
import toast from 'react-hot-toast';

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
    console.warn('Auth context not available in LoginButton');
  }
  
  // Safely access auth methods with fallbacks
  const login = auth?.login || (() => {});
  const logout = auth?.logout || (() => {});
  
  const handleLogin = async () => {
    try {
      setIsLoggingIn(true);
      await login();
    } catch (error) {
      console.error('Login error:', error);
      // Fallback to direct login if keycloak auth isn't initialized properly
      fallbackDirectLogin();
    } finally {
      setIsLoggingIn(false);
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
    
    // Construct auth URL directly with our callback page - FIXED URL CONSTRUCTION
    try {
      const keycloakBaseUrl = process.env.NEXT_PUBLIC_KEYCLOAK_URL;
      const realm = process.env.NEXT_PUBLIC_KEYCLOAK_REALM;
      const clientId = process.env.NEXT_PUBLIC_KEYCLOAK_CLIENT_ID;
      
      // Add debug logging
      console.log('DIVE25-DEBUG: Raw Keycloak URL from env:', keycloakBaseUrl);
      console.log('DIVE25-DEBUG: Realm:', realm);
      console.log('DIVE25-DEBUG: Client ID:', clientId);
      console.log('DIVE25-DEBUG: Window origin:', window.location.origin);
      
      if (!keycloakBaseUrl || !realm || !clientId) {
        throw new Error('Missing Keycloak configuration');
      }
      
      // Use our dedicated callback page
      const redirectUri = encodeURIComponent(window.location.origin);
      
      console.log('DIVE25-DEBUG: Redirect URI:', redirectUri);
      
      // Construct the URL correctly without adding /auth
      // The NEXT_PUBLIC_KEYCLOAK_URL should already have the correct base path
      const authUrl = `${keycloakBaseUrl}/realms/${realm}/protocol/openid-connect/auth?client_id=${clientId}&redirect_uri=${redirectUri}&response_type=code&scope=openid`;
      
      console.log('DIVE25-DEBUG: Final auth URL:', authUrl);
      
      // Add a small delay to ensure logs are visible before redirect
      setTimeout(() => {
        console.log('DIVE25-DEBUG: Redirecting to Keycloak now...');
        window.location.href = authUrl;
      }, 500);
    } catch (error) {
      console.error('DIVE25-DEBUG: Fallback login failed:', error);
      toast.error('Login service unavailable. Please try again later.');
    }
  };
  
  // Button styling based on variant and size
  const variantClasses = {
    primary: 'bg-primary-600 hover:bg-primary-700 text-white shadow-sm',
    secondary: 'bg-white hover:bg-gray-50 text-primary-800 border border-primary-300 shadow-sm',
    outline: 'bg-transparent hover:bg-primary-50 text-primary-700 border border-primary-300',
  };
  
  const sizeClasses = {
    sm: 'text-sm px-3 py-1.5 rounded',
    md: 'text-base px-4 py-2 rounded-md',
    lg: 'text-base px-6 py-3 rounded-md font-medium',
  };
  
  const buttonText = isLoggingIn 
    ? 'Signing in...'
    : label || (isAuthenticated ? 'Sign out' : 'Sign in');
  
  return (
    <button
      className={`inline-flex items-center justify-center font-medium transition-all duration-200 focus:ring-2 focus:ring-offset-2 focus:ring-primary-500 focus:outline-none disabled:opacity-50 ${variantClasses[variant]} ${sizeClasses[size]} ${className}`}
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