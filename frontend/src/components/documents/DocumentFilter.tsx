// frontend/src/components/documents/DocumentFilter.tsx
import { useState, useEffect } from 'react';
import { useTranslation } from 'next-i18next';
import { DocumentFilterParams } from '@/types/document';
import { Button } from '@/components/ui/Button';
import { Select } from '@/components/ui/Select';
import { Input } from '@/components/ui/Input';
import { 
  MagnifyingGlassIcon, 
  FunnelIcon, 
  XMarkIcon, 
  AdjustmentsHorizontalIcon,
  TagIcon,
  GlobeAltIcon,
  CalendarIcon,
  FlagIcon
} from '@heroicons/react/24/outline';
import { Badge } from '@/components/ui/Badge';

interface DocumentFilterProps {
  filters: DocumentFilterParams;
  onFilterChange: (filters: Partial<DocumentFilterParams>) => void;
}

export function DocumentFilter({ filters, onFilterChange }: DocumentFilterProps) {
  const { t } = useTranslation(['common', 'documents']);
  const [showFilters, setShowFilters] = useState(false);
  const [searchQuery, setSearchQuery] = useState(filters.search || '');
  const [activeFiltersCount, setActiveFiltersCount] = useState(0);

  // Count active filters
  useEffect(() => {
    let count = 0;
    if (filters.classification) count++;
    if (filters.country) count++;
    if (filters.fromDate) count++;
    if (filters.toDate) count++;
    if (filters.search) count++;
    setActiveFiltersCount(count);
  }, [filters]);

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
    onFilterChange({ search: searchQuery || undefined });
  };

  const handleSearchChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setSearchQuery(e.target.value);
    if (e.target.value === '') {
      onFilterChange({ search: undefined });
    }
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
    <div className="bg-white rounded-lg shadow">
      {/* Search and filter toggle */}
      <div className="p-4 border-b border-gray-200">
        <div className="flex flex-col sm:flex-row justify-between sm:items-center">
          <form onSubmit={handleSearch} className="relative flex w-full sm:w-96">
            <div className="relative flex-grow">
              <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                <MagnifyingGlassIcon className="h-5 w-5 text-gray-400" aria-hidden="true" />
              </div>
              <Input
                type="text"
                placeholder={t('documents:filters.searchPlaceholder')}
                value={searchQuery}
                onChange={handleSearchChange}
                className="pl-10 pr-10 py-2 rounded-md focus:ring-indigo-500 focus:border-indigo-500 block w-full sm:text-sm border-gray-300"
              />
              {searchQuery && (
                <div className="absolute inset-y-0 right-0 pr-3 flex items-center">
                  <button 
                    type="button" 
                    onClick={() => {
                      setSearchQuery('');
                      onFilterChange({ search: undefined });
                    }}
                    className="text-gray-400 hover:text-gray-500 focus:outline-none"
                  >
                    <XMarkIcon className="h-5 w-5" aria-hidden="true" />
                  </button>
                </div>
              )}
            </div>
            <Button type="submit" variant="primary" className="ml-2 rounded-md">
              {t('common:actions.search')}
            </Button>
          </form>

          <div className="flex mt-3 sm:mt-0">
            <Button
              type="button"
              variant={showFilters ? "primary" : "secondary"}
              className="flex items-center rounded-md"
              onClick={() => setShowFilters(!showFilters)}
            >
              {showFilters ? (
                <XMarkIcon className="h-5 w-5 mr-1" />
              ) : (
                <AdjustmentsHorizontalIcon className="h-5 w-5 mr-1" />
              )}
              {t('documents:filters.advancedFilters')}
              {activeFiltersCount > 0 && (
                <span className="ml-2 inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-indigo-100 text-indigo-800">
                  {activeFiltersCount}
                </span>
              )}
            </Button>
            
            {activeFiltersCount > 0 && (
              <Button
                type="button"
                variant="ghost"
                className="ml-2 flex items-center text-gray-500 rounded-md"
                onClick={clearFilters}
              >
                <XMarkIcon className="h-5 w-5 mr-1" />
                {t('documents:filters.clearFilters')}
              </Button>
            )}
          </div>
        </div>

        {/* Active filters */}
        {activeFiltersCount > 0 && (
          <div className="mt-3 flex flex-wrap gap-2">
            {filters.classification && (
              <Badge variant="primary" className="flex items-center gap-1 py-1 pl-2 pr-1">
                <TagIcon className="h-3 w-3" />
                <span>{filters.classification}</span>
                <button
                  type="button"
                  onClick={() => onFilterChange({ classification: undefined })}
                  className="ml-1 inline-flex rounded-full p-0.5 text-dive25-800 hover:bg-dive25-200"
                >
                  <XMarkIcon className="h-3 w-3" />
                </button>
              </Badge>
            )}
            {filters.country && (
              <Badge variant="info" className="flex items-center gap-1 py-1 pl-2 pr-1">
                <FlagIcon className="h-3 w-3" />
                <span>{countries.find(c => c.value === filters.country)?.label || filters.country}</span>
                <button
                  type="button"
                  onClick={() => onFilterChange({ country: undefined })}
                  className="ml-1 inline-flex rounded-full p-0.5 text-blue-800 hover:bg-blue-200"
                >
                  <XMarkIcon className="h-3 w-3" />
                </button>
              </Badge>
            )}
            {filters.fromDate && (
              <Badge variant="success" className="flex items-center gap-1 py-1 pl-2 pr-1">
                <CalendarIcon className="h-3 w-3" />
                <span>From: {filters.fromDate}</span>
                <button
                  type="button"
                  onClick={() => onFilterChange({ fromDate: undefined })}
                  className="ml-1 inline-flex rounded-full p-0.5 text-green-800 hover:bg-green-200"
                >
                  <XMarkIcon className="h-3 w-3" />
                </button>
              </Badge>
            )}
            {filters.toDate && (
              <Badge variant="success" className="flex items-center gap-1 py-1 pl-2 pr-1">
                <CalendarIcon className="h-3 w-3" />
                <span>To: {filters.toDate}</span>
                <button
                  type="button"
                  onClick={() => onFilterChange({ toDate: undefined })}
                  className="ml-1 inline-flex rounded-full p-0.5 text-green-800 hover:bg-green-200"
                >
                  <XMarkIcon className="h-3 w-3" />
                </button>
              </Badge>
            )}
            {filters.search && (
              <Badge variant="warning" className="flex items-center gap-1 py-1 pl-2 pr-1">
                <MagnifyingGlassIcon className="h-3 w-3" />
                <span>"{filters.search}"</span>
                <button
                  type="button"
                  onClick={() => {
                    setSearchQuery('');
                    onFilterChange({ search: undefined });
                  }}
                  className="ml-1 inline-flex rounded-full p-0.5 text-yellow-800 hover:bg-yellow-200"
                >
                  <XMarkIcon className="h-3 w-3" />
                </button>
              </Badge>
            )}
          </div>
        )}
      </div>

      {/* Advanced filters */}
      {showFilters && (
        <div className="p-4 bg-gray-50 rounded-b-lg border-t border-gray-200 animate-fadeIn">
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
            <div className="space-y-1">
              <label htmlFor="classification" className="block text-sm font-medium text-gray-700 flex items-center">
                <TagIcon className="h-4 w-4 mr-1 text-gray-500" />
                {t('documents:filters.classification')}
              </label>
              <Select
                id="classification"
                value={filters.classification || ''}
                onChange={(e) => onFilterChange({ classification: e.target.value || undefined })}
                options={classifications}
                className="block w-full rounded-md shadow-sm focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm border-gray-300"
              />
            </div>
            
            <div className="space-y-1">
              <label htmlFor="country" className="block text-sm font-medium text-gray-700 flex items-center">
                <GlobeAltIcon className="h-4 w-4 mr-1 text-gray-500" />
                {t('documents:filters.country')}
              </label>
              <Select
                id="country"
                value={filters.country || ''}
                onChange={(e) => onFilterChange({ country: e.target.value || undefined })}
                options={countries}
                className="block w-full rounded-md shadow-sm focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm border-gray-300"
              />
            </div>
            
            <div className="space-y-1">
              <label htmlFor="fromDate" className="block text-sm font-medium text-gray-700 flex items-center">
                <CalendarIcon className="h-4 w-4 mr-1 text-gray-500" />
                {t('documents:filters.fromDate')}
              </label>
              <Input
                type="date"
                id="fromDate"
                value={filters.fromDate || ''}
                onChange={(e) => onFilterChange({ fromDate: e.target.value || undefined })}
                className="block w-full rounded-md shadow-sm focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm border-gray-300"
              />
            </div>
            
            <div className="space-y-1">
              <label htmlFor="toDate" className="block text-sm font-medium text-gray-700 flex items-center">
                <CalendarIcon className="h-4 w-4 mr-1 text-gray-500" />
                {t('documents:filters.toDate')}
              </label>
              <Input
                type="date"
                id="toDate"
                value={filters.toDate || ''}
                onChange={(e) => onFilterChange({ toDate: e.target.value || undefined })}
                className="block w-full rounded-md shadow-sm focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm border-gray-300"
                min={filters.fromDate || ''}
              />
            </div>
          </div>
          
          <div className="mt-4 flex justify-end">
            <Button
              type="button"
              variant="ghost"
              className="mr-3"
              onClick={clearFilters}
            >
              {t('documents:filters.clearFilters')}
            </Button>
            <Button
              type="button"
              variant="primary"
              onClick={() => setShowFilters(false)}
            >
              {t('documents:filters.applyFilters', 'Apply Filters')}
            </Button>
          </div>
        </div>
      )}
    </div>
  );
}