import React, { useState } from 'react';
import { useAuth } from '@/context/auth-context';
import { User } from '@/types/user';
import toast from 'react-hot-toast';
import { createLogger } from '@/utils/logger';
import { useRouter } from 'next/router';

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
  const router = useRouter();
  
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
  const login = auth?.login;
  const logout = auth?.logout || (() => window.location.href = '/');
  
  // Handle click to navigate to country selection
  const handleLogin = () => {
    try {
      setIsLoggingIn(true);
      
      // Store current path for post-login redirect
      if (typeof window !== 'undefined') {
        const currentPath = window.location.pathname;
        sessionStorage.setItem('auth_redirect', currentPath === '/' ? '/dashboard' : currentPath);
        
        // Navigate directly to country-select page
        logger.info('Navigating to country selection page');
        const baseUrl = window.location.origin;
        window.location.href = `${baseUrl}/country-select`;
      }
    } catch (error) {
      logger.error('Login redirect error:', error);
      toast.error('Failed to navigate to country selection. Please try again.');
      setIsLoggingIn(false);
    }
  };
  
  // Handle logout
  const handleLogout = () => {
    logout();
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
  
  // Determine button text based on authentication state
  const buttonText = isLoggingIn 
    ? 'Signing in...' 
    : label || (isAuthenticated ? 'Sign out' : 'Sign in');
  
  return (
    <button
      className={`inline-flex items-center justify-center font-medium transition-all duration-300 focus:ring-2 focus:ring-offset-2 focus:ring-white/30 focus:outline-none disabled:opacity-50 ${variantClasses[variant]} ${sizeClasses[size]} ${className}`}
      onClick={isAuthenticated ? handleLogout : handleLogin}
      disabled={isLoggingIn}
      data-testid="login-button"
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