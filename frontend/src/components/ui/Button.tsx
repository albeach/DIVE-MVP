// frontend/src/components/ui/Button.tsx
import React, { ButtonHTMLAttributes, forwardRef } from 'react';
import { twMerge } from 'tailwind-merge';

export type ButtonVariant = 'primary' | 'secondary' | 'tertiary' | 'ghost' | 'danger';
export type ButtonSize = 'sm' | 'md' | 'lg';

export interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  children: React.ReactNode;
  variant?: ButtonVariant;
  size?: ButtonSize;
  isLoading?: boolean;
  isFullWidth?: boolean;
  as?: React.ElementType;
  href?: string;
}

export const Button = forwardRef<HTMLButtonElement, ButtonProps>(
  (
    {
      children,
      variant = 'primary',
      size = 'md',
      isLoading = false,
      isFullWidth = false,
      className,
      disabled,
      as: Component = 'button',
      ...props
    },
    ref
  ) => {
    const variantStyles = {
      primary: 'bg-dive25-600 text-white hover:bg-dive25-700 focus:ring-dive25-500',
secondary: 'bg-white text-gray-700 border border-gray-300 hover:bg-gray-50 focus:ring-dive25-500',
tertiary: 'bg-dive25-100 text-dive25-800 hover:bg-dive25-200 focus:ring-dive25-500',
ghost: 'bg-transparent text-gray-700 hover:bg-gray-100 focus:ring-gray-500',
danger: 'bg-red-600 text-white hover:bg-red-700 focus:ring-red-500',
};

const sizeStyles = {
sm: 'text-xs px-2.5 py-1.5 rounded',
md: 'text-sm px-4 py-2 rounded-md',
lg: 'text-base px-6 py-3 rounded-md',
};

const baseStyles = 'inline-flex justify-center items-center font-medium focus:outline-none focus:ring-2 focus:ring-offset-2 transition-colors disabled:opacity-50 disabled:cursor-not-allowed';

const combinedClassName = twMerge(
baseStyles,
variantStyles[variant],
sizeStyles[size],
isFullWidth ? 'w-full' : '',
className
);

return (
<Component
  ref={ref}
  className={combinedClassName}
  disabled={disabled || isLoading}
  {...props}
>
  {isLoading ? (
    <>
      <svg
        className="animate-spin -ml-1 mr-2 h-4 w-4"
        xmlns="http://www.w3.org/2000/svg"
        fill="none"
        viewBox="0 0 24 24"
      >
        <circle
          className="opacity-25"
          cx="12"
          cy="12"
          r="10"
          stroke="currentColor"
          strokeWidth="4"
        ></circle>
        <path
          className="opacity-75"
          fill="currentColor"
          d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
        ></path>
      </svg>
      Loading...
    </>
  ) : (
    children
  )}
</Component>
);
}
);

Button.displayName = 'Button';