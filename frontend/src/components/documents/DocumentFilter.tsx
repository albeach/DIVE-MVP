// frontend/src/components/documents/DocumentFilter.tsx
import { useState } from 'react';
import { useTranslation } from 'next-i18next';
import { DocumentFilterParams } from '@/types/document';
import { Button } from '@/components/ui/Button';
import { Select } from '@/components/ui/Select';
import { Input } from '@/components/ui/Input';
import { MagnifyingGlassIcon, FunnelIcon, XMarkIcon } from '@heroicons/react/24/outline';

interface DocumentFilterProps {
  filters: DocumentFilterParams;
  onFilterChange: (filters: Partial<DocumentFilterParams>) => void;
}

export function DocumentFilter({ filters, onFilterChange }: DocumentFilterProps) {
  const { t } = useTranslation(['common', 'documents']);
  const [showFilters, setShowFilters] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');

  const clearFilters = () => {
    onFilterChange({
      classification: undefined,
      country: undefined,
      fromDate: undefined,
      toDate: undefined,
      search: undefined,
      page: 1
    });
    setSearchQuery('');
  };

  const handleSearch = (e: React.FormEvent) => {
    e.preventDefault();
    onFilterChange({ search: searchQuery });
  };

  // Classifications for the dropdown
  const classifications = [
    { value: '', label: t('documents:filters.allClassifications') },
    { value: 'UNCLASSIFIED', label: 'UNCLASSIFIED' },
    { value: 'RESTRICTED', label: 'RESTRICTED' },
    { value: 'CONFIDENTIAL', label: 'CONFIDENTIAL' },
    { value: 'NATO CONFIDENTIAL', label: 'NATO CONFIDENTIAL' },
    { value: 'SECRET', label: 'SECRET' },
    { value: 'NATO SECRET', label: 'NATO SECRET' },
    { value: 'TOP SECRET', label: 'TOP SECRET' },
    { value: 'COSMIC TOP SECRET', label: 'COSMIC TOP SECRET' },
  ];

  // Countries for the dropdown (simplified list)
  const countries = [
    { value: '', label: t('documents:filters.allCountries') },
    { value: 'USA', label: 'USA' },
    { value: 'GBR', label: 'United Kingdom' },
    { value: 'CAN', label: 'Canada' },
    { value: 'AUS', label: 'Australia' },
    { value: 'NZL', label: 'New Zealand' },
    { value: 'FRA', label: 'France' },
    { value: 'DEU', label: 'Germany' },
  ];

  return (
    <div className="bg-white shadow rounded-md p-4 mt-6">
      <div className="flex flex-col sm:flex-row justify-between sm:items-center">
        <form onSubmit={handleSearch} className="flex w-full sm:w-96">
          <Input
            type="text"
            placeholder={t('documents:filters.searchPlaceholder')}
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="flex-grow"
          />
          <Button type="submit" variant="primary" className="ml-2">
            <MagnifyingGlassIcon className="h-5 w-5" />
          </Button>
        </form>

        <div className="flex mt-3 sm:mt-0">
          <Button
            type="button"
            variant="secondary"
            className="flex items-center"
            onClick={() => setShowFilters(!showFilters)}
          >
            <FunnelIcon className="h-5 w-5 mr-1" />
            {t('documents:filters.advancedFilters')}
          </Button>
          
          {(filters.classification || filters.country || filters.fromDate || filters.toDate) && (
            <Button
              type="button"
              variant="ghost"
              className="ml-2 flex items-center text-gray-500"
              onClick={clearFilters}
            >
              <XMarkIcon className="h-5 w-5 mr-1" />
              {t('documents:filters.clearFilters')}
            </Button>
          )}
        </div>
      </div>

      {showFilters && (
        <div className="mt-4 grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
          <div>
            <label htmlFor="classification" className="block text-sm font-medium text-gray-700 mb-1">
              {t('documents:filters.classification')}
            </label>
            <Select
              id="classification"
              value={filters.classification || ''}
              onChange={(e) => onFilterChange({ classification: e.target.value || undefined })}
              options={classifications}
            />
          </div>
          
          <div>
            <label htmlFor="country" className="block text-sm font-medium text-gray-700 mb-1">
              {t('documents:filters.country')}
            </label>
            <Select
              id="country"
              value={filters.country || ''}
              onChange={(e) => onFilterChange({ country: e.target.value || undefined })}
              options={countries}
            />
          </div>
          
          <div>
            <label htmlFor="fromDate" className="block text-sm font-medium text-gray-700 mb-1">
              {t('documents:filters.fromDate')}
            </label>
            <Input
              type="date"
              id="fromDate"
              value={filters.fromDate || ''}
              onChange={(e) => onFilterChange({ fromDate: e.target.value || undefined })}
            />
          </div>
          
          <div>
            <label htmlFor="toDate" className="block text-sm font-medium text-gray-700 mb-1">
              {t('documents:filters.toDate')}
            </label>
            <Input
              type="date"
              id="toDate"
              value={filters.toDate || ''}
              onChange={(e) => onFilterChange({ toDate: e.target.value || undefined })}
            />
          </div>
        </div>
      )}
    </div>
  );
}