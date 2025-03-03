// frontend/src/components/layout/Navbar.tsx
import React from 'react';
import Link from 'next/link';
import { useRouter } from 'next/router';
import { useAuth } from '@/context/auth-context';
import LoginButton from '@/components/auth/LoginButton';

const Navbar: React.FC = () => {
  const { isAuthenticated, user } = useAuth();
  const router = useRouter();

  // Navigation items - adjust based on auth status
  const navItems = [
    { label: 'Home', href: '/' },
    { label: 'Documents', href: '/documents' },
    ...(isAuthenticated ? [
      { label: 'Dashboard', href: '/dashboard' },
      { label: 'Profile', href: '/profile' }
    ] : [])
  ];

  return (
    <nav className="bg-white shadow-md">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex justify-between h-16">
          <div className="flex items-center">
            <Link href="/">
              <span className="flex-shrink-0 flex items-center">
                <img 
                  className="h-8 w-auto"
                  src="/assets/dive25-logo.svg"
                  alt="DIVE25 Logo"
                />
                <span className="ml-2 text-xl font-bold text-blue-800">DIVE25</span>
              </span>
            </Link>
            
            <div className="hidden md:ml-8 md:flex md:space-x-8">
              {navItems.map((item) => (
                <Link 
                  key={item.href}
                  href={item.href}
                  className={`inline-flex items-center px-1 pt-1 border-b-2 text-sm font-medium ${
                    router.pathname === item.href
                      ? 'border-blue-500 text-gray-900'
                      : 'border-transparent text-gray-500 hover:border-gray-300 hover:text-gray-700'
                  }`}
                >
                  {item.label}
                </Link>
              ))}
            </div>
          </div>
          
          <div className="flex items-center">
            {isAuthenticated && (
              <div className="hidden md:flex items-center mr-4">
                <span className="text-sm text-gray-600 mr-2">
                  Welcome, {user?.givenName || user?.username || 'User'}
                </span>
              </div>
            )}
            <LoginButton 
              variant="primary"
              size="md"
              className="ml-2"
            />
          </div>
        </div>
      </div>
    </nav>
  );
};

export default Navbar;