// frontend/src/components/layout/Navbar.tsx
import React, { useState, useEffect } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/router';
import { useAuth } from '@/context/auth-context';
import LoginButton from '@/components/auth/LoginButton';

const Navbar: React.FC = () => {
  const router = useRouter();
  const [isDropdownOpen, setIsDropdownOpen] = useState(false);
  const [sessionTimeRemaining, setSessionTimeRemaining] = useState<number | null>(null);
  const [mounted, setMounted] = useState(false);

  // Get auth information
  const auth = useAuth();
  const { 
    isAuthenticated = false, 
    user = null, 
    tokenExpiresIn = null, 
    isTokenExpiring = false,
    refreshToken = () => Promise.resolve(false),
    logout = () => {}
  } = auth;

  // Handle component mounting
  useEffect(() => {
    setMounted(true);
    return () => setMounted(false);
  }, []);

  // Force refresh on auth state change
  useEffect(() => {
    if (mounted) {
      console.log('Auth state changed in Navbar:', { isAuthenticated, user });
    }
  }, [isAuthenticated, user, mounted]);

  const toggleDropdown = () => {
    setIsDropdownOpen(!isDropdownOpen);
  };

  const handleLogout = () => {
    setIsDropdownOpen(false);
    logout();
  };

  const handleRefreshSession = async () => {
    try {
      await refreshToken();
    } catch (error) {
      console.error('Error refreshing token:', error);
    }
  };

  // Format session time remaining for display
  useEffect(() => {
    if (tokenExpiresIn !== null) {
      setSessionTimeRemaining(tokenExpiresIn);
      
      const interval = setInterval(() => {
        setSessionTimeRemaining(prev => prev !== null ? prev - 1 : null);
      }, 1000);
      
      return () => clearInterval(interval);
    } else {
      setSessionTimeRemaining(null);
    }
  }, [tokenExpiresIn]);

  const formatTimeRemaining = (seconds: number | null): string => {
    if (seconds === null) return 'Unknown';
    if (seconds <= 0) return 'Expired';
    
    const minutes = Math.floor(seconds / 60);
    const remainingSeconds = seconds % 60;
    
    if (minutes > 0) {
      return `${minutes}m ${remainingSeconds}s`;
    }
    return `${remainingSeconds}s`;
  };

  // Function to render security clearance with appropriate styling
  const renderClearanceBadge = (clearance: string) => {
    if (!clearance) return null;
    
    let badgeClass = '';
    
    // Style based on clearance level
    switch (clearance.toUpperCase()) {
      case 'TOP SECRET':
      case 'TS':
        badgeClass = 'bg-red-600 text-white';
        break;
      case 'SECRET':
      case 'S':
        badgeClass = 'bg-amber-500 text-white';
        break;
      case 'CONFIDENTIAL':
      case 'C':
        badgeClass = 'bg-blue-600 text-white';
        break;
      case 'UNCLASSIFIED':
      case 'U':
        badgeClass = 'bg-green-600 text-white';
        break;
      default:
        badgeClass = 'bg-gray-600 text-white';
    }
    
    return (
      <span className={`text-xs font-bold px-2 py-1 rounded ${badgeClass}`}>
        {clearance.toUpperCase()}
      </span>
    );
  };

  // If not mounted yet, render a placeholder to avoid hydration issues
  if (!mounted) return <div className="h-16 bg-gray-800"></div>;

  return (
    <header className="bg-gray-800 text-white shadow-md z-50">
      <div className="container mx-auto px-4 py-3">
        <div className="flex items-center justify-between">
          {/* Logo and site name */}
          <div className="flex items-center space-x-4">
            <Link href="/" className="text-xl font-bold text-white hover:text-blue-300 transition-colors">
              DIVE
            </Link>
            
            {/* Navigation links */}
            <nav className="hidden md:flex space-x-6">
              <Link href="/" className={`hover:text-blue-300 transition-colors ${router.pathname === '/' ? 'text-blue-300' : ''}`}>
                Home
              </Link>
              
              {isAuthenticated && (
                <>
                  <Link href="/documents" className={`hover:text-blue-300 transition-colors ${router.pathname === '/documents' ? 'text-blue-300' : ''}`}>
                    Documents
                  </Link>
                  <Link href="/dashboard" className={`hover:text-blue-300 transition-colors ${router.pathname === '/dashboard' ? 'text-blue-300' : ''}`}>
                    Dashboard
                  </Link>
                </>
              )}
            </nav>
          </div>

          {/* User section */}
          <div className="flex items-center space-x-4">
            {isAuthenticated && user ? (
              <div className="relative">
                {/* User info button */}
                <button 
                  onClick={toggleDropdown}
                  className="flex items-center space-x-2 bg-gray-700 hover:bg-gray-600 px-3 py-2 rounded-md transition-colors"
                  aria-expanded={isDropdownOpen}
                  aria-haspopup="true"
                >
                  <span className="font-medium">{user.givenName || user.username}</span>
                  {user.clearance && (
                    <span className="ml-2">{renderClearanceBadge(user.clearance)}</span>
                  )}
                  <svg 
                    xmlns="http://www.w3.org/2000/svg" 
                    className={`h-5 w-5 transition-transform ${isDropdownOpen ? 'rotate-180' : ''}`} 
                    fill="none" 
                    viewBox="0 0 24 24" 
                    stroke="currentColor"
                  >
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                  </svg>
                </button>
                
                {/* Dropdown menu */}
                {isDropdownOpen && (
                  <div 
                    className="absolute right-0 mt-2 w-64 bg-white rounded-md shadow-lg z-50 overflow-hidden"
                    role="menu"
                    aria-orientation="vertical"
                    aria-labelledby="user-menu"
                  >
                    <div className="px-4 py-3 border-b border-gray-200">
                      <p className="text-sm font-medium text-gray-900">{user.givenName} {user.surname}</p>
                      <p className="text-sm text-gray-600 truncate">{user.email}</p>
                      {user.organization && (
                        <p className="text-xs text-gray-500 mt-1">{user.organization}</p>
                      )}
                    </div>
                    
                    {/* Session information */}
                    <div className="px-4 py-2 bg-gray-50 border-b border-gray-200">
                      <div className="flex justify-between items-center">
                        <p className="text-xs text-gray-500">Session expires in:</p>
                        <div className="flex items-center">
                          <span className={`text-xs font-medium ${isTokenExpiring ? 'text-red-600' : 'text-green-600'}`}>
                            {formatTimeRemaining(sessionTimeRemaining)}
                          </span>
                          <button 
                            onClick={handleRefreshSession}
                            className="ml-2 text-blue-600 hover:text-blue-800"
                            title="Refresh session"
                          >
                            <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
                            </svg>
                          </button>
                        </div>
                      </div>
                    </div>
                    
                    <div className="py-1">
                      <Link href="/profile" className="block px-4 py-2 text-sm text-gray-700 hover:bg-gray-100" role="menuitem" onClick={() => setIsDropdownOpen(false)}>
                        Your Profile
                      </Link>
                      <Link href="/dashboard" className="block px-4 py-2 text-sm text-gray-700 hover:bg-gray-100" role="menuitem" onClick={() => setIsDropdownOpen(false)}>
                        Dashboard
                      </Link>
                      <button 
                        onClick={handleLogout}
                        className="block w-full text-left px-4 py-2 text-sm text-red-600 hover:bg-red-50" 
                        role="menuitem"
                      >
                        Sign out
                      </button>
                    </div>
                  </div>
                )}
              </div>
            ) : (
              <div className="flex items-center">
                <LoginButton variant="primary" size="sm" />
              </div>
            )}
          </div>
        </div>
      </div>
    </header>
  );
};

export default Navbar;