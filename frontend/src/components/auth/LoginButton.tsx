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
  const [isLoading, setIsLoading] = useState(false);
  
  // Default to unauthenticated state
  let isAuthenticated = false;
  let user: User | null = null;
  let login = () => console.warn('Auth context not available, login function not accessible');
  let logout = () => console.warn('Auth context not available, logout function not accessible');
  
  // Try to use auth context, but fall back to unauthenticated state if not available
  try {
    const auth = useAuth();
    isAuthenticated = auth.isAuthenticated;
    user = auth.user;
    login = auth.login;
    logout = auth.logout;
  } catch (error) {
    console.warn('Auth context not available in LoginButton, using fallback state');
  }

  // Button styling classes based on variant and size
  const variantClasses = {
    primary: 'bg-blue-600 hover:bg-blue-700 text-white',
    secondary: 'bg-gray-600 hover:bg-gray-700 text-white',
    outline: 'bg-transparent border border-blue-600 text-blue-600 hover:bg-blue-50'
  };

  const sizeClasses = {
    sm: 'py-1 px-3 text-sm',
    md: 'py-2 px-4 text-base',
    lg: 'py-3 px-6 text-lg'
  };

  const buttonClasses = `
    rounded font-medium transition-colors duration-200 
    focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-opacity-50
    ${variantClasses[variant]} 
    ${sizeClasses[size]} 
    ${className}
    ${isLoading ? 'opacity-75 cursor-not-allowed' : ''}
  `;

  // Fallback direct login if normal login fails
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
      const keycloakUrl = process.env.NEXT_PUBLIC_KEYCLOAK_URL;
      const realm = process.env.NEXT_PUBLIC_KEYCLOAK_REALM;
      const clientId = process.env.NEXT_PUBLIC_KEYCLOAK_CLIENT_ID;
      
      if (!keycloakUrl || !realm || !clientId) {
        throw new Error('Missing Keycloak configuration');
      }
      
      // Use our dedicated callback page
      const callbackUrl = `${window.location.origin}/auth/callback`;
      const redirectUri = encodeURIComponent(callbackUrl);
      
      // Construct the URL correctly without adding /auth
      // The NEXT_PUBLIC_KEYCLOAK_URL should already have the correct base path
      const authUrl = `${keycloakUrl}/realms/${realm}/protocol/openid-connect/auth?client_id=${clientId}&redirect_uri=${redirectUri}&response_type=code&scope=openid`;
      
      console.log('Redirecting to auth URL with callback:', authUrl);
      window.location.href = authUrl;
    } catch (error) {
      console.error('Fallback login failed:', error);
      toast.error('Login service unavailable. Please try again later.');
    }
  };

  // Handle auth action
  const handleClick = async () => {
    if (isLoading) return;
    
    setIsLoading(true);
    try {
      if (isAuthenticated) {
        await logout();
      } else {
        // Store current path for redirect after login
        const currentPath = window.location.pathname + window.location.search;
        if (currentPath !== '/' && !currentPath.includes('/login') && !currentPath.includes('/auth/')) {
          sessionStorage.setItem('auth_redirect', currentPath);
        }
        
        // Set redirect to documents for home page
        if (currentPath === '/' || currentPath === '/login') {
          sessionStorage.setItem('auth_redirect', '/documents');
        }
        
        // Skip normal login and go directly to fallback for better reliability
        fallbackDirectLogin();
      }
    } catch (error) {
      console.error('Authentication action failed:', error);
      
      if (!isAuthenticated) {
        fallbackDirectLogin();
      }
    } finally {
      // In case the promises resolve before redirect
      setTimeout(() => {
        setIsLoading(false);
      }, 2000);
    }
  };

  // Get display text
  const getButtonText = () => {
    if (isLoading) {
      return isAuthenticated ? 'Signing Out...' : 'Signing In...';
    }
    
    if (isAuthenticated && user) {
      return user.givenName ? `Sign Out` : 'Sign Out';
    }
    
    return label;
  };

  return (
    <button 
      onClick={handleClick} 
      className={buttonClasses}
      aria-label={isAuthenticated ? 'Sign Out' : 'Sign In'}
      disabled={isLoading}
    >
      {isLoading && (
        <span className="inline-block mr-2">
          <svg className="animate-spin -ml-1 mr-2 h-4 w-4 text-white inline-block" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
            <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
            <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
          </svg>
        </span>
      )}
      {getButtonText()}
    </button>
  );
};

export default LoginButton; 