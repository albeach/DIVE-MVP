import { useRouter } from 'next/router';
import { useEffect, useState } from 'react';
import { useAuth } from '@/context/auth-context';
import toast from 'react-hot-toast';
import { Spinner } from '@/components/ui/Spinner';
import Link from 'next/link';
import { Button } from '@/components/ui/Button';

// Callback page for handling authentication redirects
export default function AuthCallback() {
  const router = useRouter();
  const { keycloak, isAuthenticated } = useAuth();
  const [error, setError] = useState<string | null>(null);
  const [isProcessing, setIsProcessing] = useState(true);

  useEffect(() => {
    // Only process if we have authentication parameters in the URL
    if (router.isReady && router.query.code) {
      setIsProcessing(true);
      
      // We don't need to do additional processing since Keycloak integration 
      // is handled by the AuthContext automatically
      
      // After a short delay to allow authentication to complete, redirect to home
      const timer = setTimeout(() => {
        if (isAuthenticated) {
          // Get redirect path from session storage or default to documents
          const redirectPath = typeof window !== 'undefined' 
            ? sessionStorage.getItem('auth_redirect') || '/documents'
            : '/documents';
          
          // Clear redirect path
          sessionStorage.removeItem('auth_redirect');
          
          // Success message
          toast.success('Authentication successful!');
          
          // Redirect to the target page
          router.push(redirectPath);
        } else {
          // If not authenticated after delay, show error
          setError('Authentication failed. Please try again.');
          setIsProcessing(false);
        }
      }, 2000);
      
      return () => clearTimeout(timer);
    } else if (router.isReady) {
      // No authentication code in URL, redirect to login
      setError('No authentication code provided. Please try logging in again.');
      setIsProcessing(false);
    }
  }, [router, isAuthenticated]);

  // Show loading state while processing
  if (isProcessing) {
    return (
      <div className="min-h-screen flex flex-col items-center justify-center">
        <Spinner size="lg" />
        <p className="mt-4 text-lg text-gray-600">Completing authentication...</p>
      </div>
    );
  }

  // Show error state if authentication failed
  if (error) {
    return (
      <div className="min-h-screen flex flex-col items-center justify-center">
        <div className="bg-red-50 border-l-4 border-red-500 p-4 mb-6 max-w-lg">
          <div className="flex">
            <div className="flex-shrink-0">
              <svg className="h-5 w-5 text-red-500" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clipRule="evenodd" />
              </svg>
            </div>
            <div className="ml-3">
              <p className="text-sm text-red-700">
                {error}
              </p>
            </div>
          </div>
        </div>
        <Button variant="primary" onClick={() => router.push('/login')}>
          Try Again
        </Button>
        <Link href="/" className="mt-4 text-blue-600 hover:text-blue-800">
          Return to Home
        </Link>
      </div>
    );
  }

  return null;
}