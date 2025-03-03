import { useEffect } from 'react';
import { useRouter } from 'next/router';
import { useAuth } from '@/context/auth-context';
import Image from 'next/image';
import Head from 'next/head';

export default function LoginPage() {
  const { login, isAuthenticated, isLoading } = useAuth();
  const router = useRouter();
  
  // Redirect if already authenticated
  useEffect(() => {
    if (isAuthenticated && !isLoading) {
      router.push('/');
    }
  }, [isAuthenticated, isLoading, router]);
  
  // Initiate login
  const handleLogin = () => {
    login();
  };
  
  if (isLoading || isAuthenticated) {
    return <div className="flex items-center justify-center min-h-screen">
      <div className="animate-spin rounded-full h-12 w-12 border-t-2 border-b-2 border-dive25-primary"></div>
    </div>;
  }
  
  return (
    <>
      <Head>
        <title>Login - DIVE25 Secure Document System</title>
      </Head>
      
      <div className="flex items-center justify-center min-h-screen bg-gray-100">
        <div className="auth-container max-w-md w-full">
          <div className="auth-logo">
            <Image 
              src="/assets/dive25-logo.svg" 
              alt="DIVE25 Logo"
              width={150}
              height={60}
              priority
            />
          </div>
          
          <h1 className="auth-title">
            DIVE25 Secure Document System
          </h1>
          
          <p className="text-center text-gray-600 mb-6">
            Sign in to access the secure document repository
          </p>
          
          <div className="flex flex-col items-center">
            <button 
              onClick={handleLogin}
              className="auth-button w-full flex justify-center"
            >
              Sign in with Keycloak
            </button>
            
            <div className="mt-4 text-sm text-gray-500">
              This will redirect you to our secure authentication service
            </div>
          </div>
        </div>
      </div>
    </>
  );
} 