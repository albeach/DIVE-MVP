// frontend/src/components/hoc/withAuth.tsx
import { useRouter } from 'next/router';
import { useEffect } from 'react';
import { useAuth } from '@/context/auth-context';
import { Spinner } from '@/components/ui/Spinner';

export function withAuth<T>(Component: React.ComponentType<T>) {
  return function WithAuth(props: T) {
    const { isAuthenticated, isLoading, login } = useAuth();
    const router = useRouter();

    useEffect(() => {
      if (!isLoading && !isAuthenticated) {
        // Redirect to login if not authenticated
        login();
      }
    }, [isLoading, isAuthenticated, login]);

    if (isLoading) {
      return (
        <div className="flex items-center justify-center min-h-screen">
          <Spinner size="lg" />
        </div>
      );
    }

    if (!isAuthenticated) {
      return null;
    }

    return <Component {...props} />;
  };
}