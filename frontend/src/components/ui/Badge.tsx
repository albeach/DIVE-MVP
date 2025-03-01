// frontend/src/components/ui/Badge.tsx
import { twMerge } from 'tailwind-merge';

export type BadgeVariant = 'primary' | 'secondary' | 'tertiary' | 'info' | 'success' | 'warning' | 'danger' | 'clearance';

interface BadgeProps {
  children: React.ReactNode;
  variant?: BadgeVariant;
  level?: string;
  className?: string;
}

export function Badge({ children, variant = 'primary', level, className }: BadgeProps) {
  const variantStyles = {
    primary: 'bg-dive25-100 text-dive25-800',
    secondary: 'bg-gray-100 text-gray-800',
    tertiary: 'bg-indigo-100 text-indigo-800',
    info: 'bg-blue-100 text-blue-800',
    success: 'bg-green-100 text-green-800',
    warning: 'bg-yellow-100 text-yellow-800',
    danger: 'bg-red-100 text-red-800',
    clearance: ''
  };

  // For clearance variant, style based on classification level
  let clearanceStyle = '';
  if (variant === 'clearance' && level) {
    const normalizedLevel = level.toUpperCase();
    if (normalizedLevel.includes('TOP SECRET') || normalizedLevel.includes('COSMIC')) {
      clearanceStyle = 'bg-purple-100 text-purple-800';
    } else if (normalizedLevel.includes('SECRET')) {
      clearanceStyle = 'bg-red-100 text-red-800';
    } else if (normalizedLevel.includes('CONFIDENTIAL')) {
      clearanceStyle = 'bg-orange-100 text-orange-800';
    } else if (normalizedLevel.includes('RESTRICTED')) {
      clearanceStyle = 'bg-yellow-100 text-yellow-800';
    } else if (normalizedLevel.includes('UNCLASSIFIED')) {
      clearanceStyle = 'bg-green-100 text-green-800';
    } else {
      clearanceStyle = 'bg-gray-100 text-gray-800';
    }
  }

  const baseStyles = 'inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium';
  
  const styleToUse = variant === 'clearance' ? clearanceStyle : variantStyles[variant];
  
  return (
    <span className={twMerge(baseStyles, styleToUse, className)}>
      {children}
    </span>
  );
}