// frontend/src/components/ui/Select.tsx
import React, { forwardRef, SelectHTMLAttributes } from 'react';
import { twMerge } from 'tailwind-merge';

interface SelectOption {
  value: string;
  label: string;
}

interface SelectProps extends Omit<SelectHTMLAttributes<HTMLSelectElement>, 'multiple'> {
  options: SelectOption[];
  error?: string;
  multiple?: boolean;
}

export const Select = forwardRef<HTMLSelectElement, SelectProps>(
  ({ options, error, multiple, className, ...props }, ref) => {
    return (
      <div>
        <select
          ref={ref}
          multiple={multiple}
          className={twMerge(
            'block w-full pl-3 pr-10 py-2 text-base border-gray-300 focus:outline-none focus:ring-dive25-500 focus:border-dive25-500 sm:text-sm rounded-md',
            error && 'border-red-300 text-red-900 placeholder-red-300 focus:ring-red-500 focus:border-red-500',
            multiple && 'h-32',
            className
          )}
          {...props}
        >
          {options.map((option) => (
            <option key={option.value} value={option.value}>
              {option.label}
            </option>
          ))}
        </select>
        {error && (
          <p className="mt-2 text-sm text-red-600">
            {error}
          </p>
        )}
      </div>
    );
  }
);

Select.displayName = 'Select';