import React from 'react';
import { useAuth } from '@/context/auth-context';

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
  const { isAuthenticated, login, logout, user } = useAuth();

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
  `;

  // Handle auth action
  const handleClick = () => {
    if (isAuthenticated) {
      logout();
    } else {
      login();
    }
  };

  return (
    <button 
      onClick={handleClick} 
      className={buttonClasses}
      aria-label={isAuthenticated ? 'Sign Out' : 'Sign In'}
    >
      {isAuthenticated ? `Sign Out ${user?.givenName ? `(${user.givenName})` : ''}` : label}
    </button>
  );
};

export default LoginButton; 