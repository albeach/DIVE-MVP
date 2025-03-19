// frontend/src/components/layout/Navbar.tsx
import React, { useState, useEffect, useRef } from 'react';
import Link from 'next/link';
import Image from 'next/image';
import { useRouter } from 'next/router';
import { useAuth } from '@/context/auth-context';
import LoginButton from '@/components/auth/LoginButton';
import { useTranslation } from 'next-i18next';

const Navbar: React.FC = () => {
  const router = useRouter();
  const { t } = useTranslation('common');
  const [isDropdownOpen, setIsDropdownOpen] = useState(false);
  const [isMobileMenuOpen, setIsMobileMenuOpen] = useState(false);
  const [sessionTimeRemaining, setSessionTimeRemaining] = useState<number | null>(null);
  const [mounted, setMounted] = useState(false);
  const [authLoaded, setAuthLoaded] = useState(false);
  const dropdownRef = useRef<HTMLDivElement>(null);

  // For the landing page, we may not have auth initialized
  // Check if we're on the landing page
  const isLandingPage = router.pathname === '/';
  
  // Safely access auth information
  let auth: any = {};
  let isAuthenticated = false;
  let user = null;
  let tokenExpiresIn = null;
  let isTokenExpiring = false;
  
  // Try to get auth context - this won't throw if we wrap it properly
  try {
    // Only try to use auth if not on landing page or if already loaded
    // This avoids forcing auth initialization on landing page
    if (!isLandingPage || authLoaded) {
      auth = useAuth() || {};
      isAuthenticated = auth.isAuthenticated || false;
      user = auth.user || null;
      tokenExpiresIn = auth.tokenExpiresIn || null;
      isTokenExpiring = auth.isTokenExpiring || false;
      
      // Mark auth as loaded if we successfully got it
      if (!authLoaded) setAuthLoaded(true);
    }
  } catch (error) {
    console.warn('Auth context not available in Navbar, using default values');
  }
  
  // Safely access auth methods with fallbacks
  const refreshToken = auth.refreshToken || (() => Promise.resolve(false));
  const logout = auth.logout || (() => {});

  // Handle component mounting
  useEffect(() => {
    setMounted(true);
    return () => setMounted(false);
  }, []);

  // Handle click outside to close dropdown
  useEffect(() => {
    function handleClickOutside(event: MouseEvent) {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target as Node)) {
        setIsDropdownOpen(false);
      }
    }

    document.addEventListener('mousedown', handleClickOutside);
    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
    };
  }, []);

  // Close mobile menu on route change
  useEffect(() => {
    setIsMobileMenuOpen(false);
  }, [router.pathname]);

  // Force refresh on auth state change
  useEffect(() => {
    if (mounted) {
      console.log('Auth state changed in Navbar:', { isAuthenticated, user });
    }
  }, [isAuthenticated, user, mounted]);

  const toggleDropdown = () => {
    setIsDropdownOpen(!isDropdownOpen);
  };

  const toggleMobileMenu = () => {
    setIsMobileMenuOpen(!isMobileMenuOpen);
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
      <span className={`text-xs font-bold px-2 py-1 rounded-full ${badgeClass}`}>
        {clearance.toUpperCase()}
      </span>
    );
  };

  // If not mounted yet, render a placeholder to avoid hydration issues
  if (!mounted) return <div className="h-16 bg-gradient-to-r from-primary-900 to-primary-800"></div>;

  return (
    <header className="sticky top-0 z-50 bg-gradient-to-r from-primary-900 to-primary-800 text-white backdrop-blur-sm backdrop-saturate-150">
      <div className="container mx-auto px-4">
        <div className="flex items-center justify-between h-16">
          {/* Logo only */}
          <div className="flex items-center">
            <Link href="/" className="flex items-center group relative">
              <div className="w-12 h-12 relative overflow-hidden rounded-md bg-white/5 p-1.5 backdrop-blur-sm border border-white/10 shadow-md">
                <Image 
                  src="/assets/dive25-logo.svg" 
                  alt={t('app.name')} 
                  width={40} 
                  height={40}
                  className="transition-all duration-300 group-hover:scale-105"
                />
              </div>
            </Link>
          </div>
          
          {/* Desktop Navigation */}
          <nav className="hidden md:flex items-center space-x-3">
            <NavLink href="/" active={router.pathname === '/'} label={t('navigation.home')} />
            
            {isAuthenticated && (
              <>
                <NavLink href="/documents" active={router.pathname.startsWith('/documents')} label={t('navigation.documents')} />
                <NavLink href="/dashboard" active={router.pathname === '/dashboard'} label={t('navigation.dashboard')} />
              </>
            )}
          </nav>

          {/* Right side items */}
          <div className="flex items-center">
            {/* User section - Desktop */}
            {isAuthenticated && user ? (
              <div className="hidden md:block relative" ref={dropdownRef}>
                {/* User info button */}
                <button 
                  onClick={toggleDropdown}
                  className="flex items-center space-x-2 px-4 py-2 rounded-md transition-all duration-300 bg-white/10 hover:bg-white/20 focus:outline-none focus:ring-2 focus:ring-white/30 focus:ring-offset-1 focus:ring-offset-primary-800 backdrop-blur-sm border border-white/10"
                  aria-expanded={isDropdownOpen}
                  aria-haspopup="true"
                >
                  <div className="flex items-center">
                    <div className="h-8 w-8 rounded-md bg-primary-700 flex items-center justify-center text-white font-medium mr-2 shadow-inner border border-primary-600">
                      {user.givenName ? user.givenName.charAt(0) : (user.username ? user.username.charAt(0).toUpperCase() : 'U')}
                    </div>
                    <span className="font-medium">{user.givenName || user.username}</span>
                    {user.clearance && (
                      <span className="ml-2">{renderClearanceBadge(user.clearance)}</span>
                    )}
                  </div>
                  <svg 
                    xmlns="http://www.w3.org/2000/svg" 
                    className={`h-4 w-4 transition-transform duration-300 ml-1 ${isDropdownOpen ? 'rotate-180' : ''}`} 
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
                    className="absolute right-0 mt-2 w-72 bg-white rounded-lg shadow-xl z-50 overflow-hidden transform origin-top-right transition-all duration-200 ease-out border border-gray-100"
                    role="menu"
                    aria-orientation="vertical"
                    aria-labelledby="user-menu"
                  >
                    <div className="p-4 border-b border-gray-100 bg-gradient-to-br from-green-50 to-white">
                      <p className="text-base font-medium text-gray-900">{user.givenName} {user.surname}</p>
                      <p className="text-sm text-gray-600 truncate mt-0.5">{user.email}</p>
                      {user.organization && (
                        <p className="text-xs text-gray-500 mt-1 flex items-center">
                          <svg xmlns="http://www.w3.org/2000/svg" className="h-3.5 w-3.5 mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" />
                          </svg>
                          {user.organization}
                        </p>
                      )}
                    </div>
                    
                    {/* Session information */}
                    <div className="px-4 py-3 bg-gray-50 border-b border-gray-100">
                      <div className="flex justify-between items-center">
                        <p className="text-sm text-gray-500 flex items-center">
                          <svg xmlns="http://www.w3.org/2000/svg" className="h-3.5 w-3.5 mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                          </svg>
                          {t('session.expires_in')}:
                        </p>
                        <div className="flex items-center">
                          <span className={`text-sm font-medium ${isTokenExpiring ? 'text-red-600' : 'text-green-600'}`}>
                            {formatTimeRemaining(sessionTimeRemaining)}
                          </span>
                          <button 
                            onClick={handleRefreshSession}
                            className="ml-2 text-primary-600 hover:text-primary-800 transition-colors p-1 rounded-full hover:bg-green-50"
                            title={t('session.refresh')}
                          >
                            <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
                            </svg>
                          </button>
                        </div>
                      </div>
                    </div>
                    
                    <div className="py-1">
                      <DropdownLink 
                        href="/profile" 
                        onClick={() => setIsDropdownOpen(false)}
                        icon={
                          <svg className="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"></path>
                          </svg>
                        }
                      >
                        {t('navigation.profile')}
                      </DropdownLink>
                      
                      <DropdownLink 
                        href="/dashboard" 
                        onClick={() => setIsDropdownOpen(false)}
                        icon={
                          <svg className="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M4 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2V6zM14 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2V6zM4 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2v-2zM14 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2v-2z"></path>
                          </svg>
                        }
                      >
                        {t('navigation.dashboard')}
                      </DropdownLink>
                      
                      <DropdownLink 
                        href="/documents" 
                        onClick={() => setIsDropdownOpen(false)}
                        icon={
                          <svg className="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"></path>
                          </svg>
                        }
                      >
                        {t('navigation.documents')}
                      </DropdownLink>
                      
                      <div className="border-t border-gray-100 my-1"></div>
                      
                      <button 
                        onClick={handleLogout}
                        className="group flex w-full items-center px-4 py-2.5 text-sm text-red-600 hover:bg-red-50 transition-colors duration-150" 
                        role="menuitem"
                      >
                        <svg className="h-4 w-4 mr-3 text-red-500 group-hover:text-red-600" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1"></path>
                        </svg>
                        {t('auth.sign_out')}
                      </button>
                    </div>
                  </div>
                )}
              </div>
            ) : (
              <div className="hidden md:block">
                <LoginButton 
                  variant="primary" 
                  size="md" 
                  className="bg-white/10 hover:bg-white/20 text-white py-2 px-4 rounded-md shadow-sm backdrop-blur-sm border border-white/10 hover:border-white/20 transition-all duration-300"
                  label={t('auth.sign_in')}
                />
              </div>
            )}
            
            {/* Mobile menu button */}
            <div className="md:hidden">
              <button 
                onClick={toggleMobileMenu}
                className="p-2 rounded-md hover:bg-white/10 focus:outline-none focus:ring-2 focus:ring-white/30 transition-colors duration-200"
                aria-expanded={isMobileMenuOpen}
              >
                <span className="sr-only">Open main menu</span>
                {isMobileMenuOpen ? (
                  <svg xmlns="http://www.w3.org/2000/svg" className="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                  </svg>
                ) : (
                  <svg xmlns="http://www.w3.org/2000/svg" className="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6h16M4 12h16M4 18h16" />
                  </svg>
                )}
              </button>
            </div>
          </div>
        </div>
      </div>

      {/* Mobile menu, show/hide based on menu state */}
      {isMobileMenuOpen && (
        <div className="md:hidden bg-gradient-to-b from-primary-800 to-primary-900 border-t border-white/10 shadow-lg animate-fadeIn">
          <div className="px-3 pt-3 pb-4 space-y-1.5">
            <MobileNavLink href="/" active={router.pathname === '/'}>
              <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5 mr-3 opacity-80" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6" />
              </svg>
              <span>{t('navigation.home')}</span>
            </MobileNavLink>
            
            {isAuthenticated ? (
              <>
                <MobileNavLink href="/documents" active={router.pathname.startsWith('/documents')}>
                  <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5 mr-3 opacity-80" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                  </svg>
                  <span>{t('navigation.documents')}</span>
                </MobileNavLink>
                
                <MobileNavLink href="/dashboard" active={router.pathname === '/dashboard'}>
                  <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5 mr-3 opacity-80" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 5a1 1 0 011-1h14a1 1 0 011 1v2a1 1 0 01-1 1H5a1 1 0 01-1-1V5zM4 13a1 1 0 011-1h6a1 1 0 011 1v6a1 1 0 01-1 1H5a1 1 0 01-1-1v-6zM16 13a1 1 0 011-1h2a1 1 0 011 1v6a1 1 0 01-1 1h-2a1 1 0 01-1-1v-6z" />
                  </svg>
                  <span>{t('navigation.dashboard')}</span>
                </MobileNavLink>
                
                <MobileNavLink href="/profile" active={router.pathname === '/profile'}>
                  <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5 mr-3 opacity-80" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
                  </svg>
                  <span>{t('navigation.profile')}</span>
                </MobileNavLink>
                
                <div className="pt-2 pb-1">
                  <button
                    onClick={handleLogout}
                    className="flex w-full items-center px-3 py-2.5 text-base font-medium rounded-lg text-red-100 bg-red-900/40 hover:bg-red-900/60 transition-colors duration-200 border border-red-800/50"
                  >
                    <svg className="h-5 w-5 mr-3 opacity-90" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1"></path>
                    </svg>
                    {t('auth.sign_out')}
                  </button>
                </div>
              </>
            ) : (
              <div className="pt-2 pb-1">
                <LoginButton 
                  variant="primary" 
                  size="md" 
                  className="w-full bg-white/10 hover:bg-white/20 text-white py-2.5 px-4 rounded-lg shadow-sm backdrop-blur-sm border border-white/10 hover:border-white/20 transition-all duration-300"
                  label={t('auth.sign_in')}
                />
              </div>
            )}
          </div>
        </div>
      )}
    </header>
  );
};

// Helper component for desktop nav links
const NavLink: React.FC<{ href: string; active: boolean; label: string }> = ({ href, active, label }) => {
  return (
    <Link 
      href={href} 
      className={`px-4 py-2 rounded-md text-base font-medium transition-all duration-300 relative ${
        active 
          ? 'bg-white/20 text-white' 
          : 'text-white hover:text-white hover:bg-white/10'
      }`}
    >
      {label}
      {active && <span className="absolute bottom-0 left-1/2 transform -translate-x-1/2 w-8 h-0.5 bg-primary-400 rounded-sm"></span>}
    </Link>
  );
};

// Helper component for mobile nav links
const MobileNavLink: React.FC<{ href: string; active: boolean; children: React.ReactNode }> = ({ 
  href, 
  active, 
  children 
}) => {
  return (
    <Link
      href={href}
      className={`flex items-center px-3 py-2.5 rounded-lg text-base font-medium transition-all duration-300 ${
        active 
          ? 'bg-white/15 text-white shadow-inner border border-white/10' 
          : 'text-white/80 hover:bg-white/10 hover:text-white'
      }`}
    >
      {children}
    </Link>
  );
};

// Helper component for dropdown links
const DropdownLink: React.FC<{ 
  href: string; 
  onClick: () => void; 
  children: React.ReactNode;
  icon?: React.ReactNode;
}> = ({ href, onClick, children, icon }) => {
  return (
    <Link 
      href={href} 
      className="group flex items-center px-4 py-2.5 text-sm text-gray-700 hover:bg-green-50 transition-colors duration-200" 
      role="menuitem" 
      onClick={onClick}
    >
      {icon && <span className="mr-3 text-gray-500 group-hover:text-primary-600 transition-colors duration-200">{icon}</span>}
      {children}
    </Link>
  );
};

export default Navbar;