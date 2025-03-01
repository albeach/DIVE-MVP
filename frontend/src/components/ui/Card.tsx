// frontend/src/components/ui/Card.tsx
import { twMerge } from 'tailwind-merge';

interface CardProps {
  children: React.ReactNode;
  className?: string;
}

export function Card({ children, className }: CardProps) {
  return (
    <div className={twMerge('bg-white shadow rounded-lg overflow-hidden', className)}>
      {children}
    </div>
  );
}