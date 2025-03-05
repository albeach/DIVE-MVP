// frontend/src/components/layout/Layout.tsx
import React, { ReactNode } from 'react';
import Navbar from './Navbar';
import { Footer } from './Footer';
import { useAuth } from '@/context/auth-context';

interface LayoutProps {
  children: ReactNode;
  isPublicRoute?: boolean;
}

export function Layout({ children, isPublicRoute = false }: LayoutProps) {
  // Default to unauthenticated state
  let isAuthenticated = false;
  let isLoading = false;
  
  // Only use auth context if not a public route
  try {
    if (!isPublicRoute) {
      const auth = useAuth();
      isAuthenticated = auth.isAuthenticated;
      isLoading = auth.isLoading;
    }
  } catch (error) {
    // If auth context is not available, treat as public route
    console.warn('Auth context not available, treating as public route');
  }
  
  // If the route requires authentication and user isn't authenticated
  if (!isPublicRoute && !isLoading && !isAuthenticated) {
    // In a real app, we would redirect to login page here
    // but that's handled by our withAuth HOC
    return null;
  }

  return (
    <div className="min-h-screen flex flex-col">
      <Navbar />
      <main className="flex-grow">
        {children}
      </main>
      <Footer />
    </div>
  );
}