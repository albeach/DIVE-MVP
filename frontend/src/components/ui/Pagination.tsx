// frontend/src/components/ui/Pagination.tsx
import { ChevronLeftIcon, ChevronRightIcon } from '@heroicons/react/24/outline';
import { useTranslation } from 'next-i18next';

interface PaginationProps {
  currentPage: number;
  totalPages: number;
  onPageChange: (page: number) => void;
}

export function Pagination({ currentPage, totalPages, onPageChange }: PaginationProps) {
  const { t } = useTranslation(['common', 'translation']);
  
  // Generate page numbers to display
  const getPageNumbers = () => {
    const pageNumbers = [];
    
    // Always show first page
    pageNumbers.push(1);
    
    // Calculate range around current page
    let rangeStart = Math.max(2, currentPage - 1);
    let rangeEnd = Math.min(totalPages - 1, currentPage + 1);
    
    // Add ellipsis after page 1 if necessary
    if (rangeStart > 2) {
      pageNumbers.push('...');
    }
    
    // Add range of pages
    for (let i = rangeStart; i <= rangeEnd; i++) {
      pageNumbers.push(i);
    }
    
    // Add ellipsis before last page if necessary
    if (rangeEnd < totalPages - 1) {
      pageNumbers.push('...');
    }
    
    // Always show last page if there's more than one page
    if (totalPages > 1) {
      pageNumbers.push(totalPages);
    }
    
    return pageNumbers;
  };
  
  const pageNumbers = getPageNumbers();
  
  return (
    <nav className="flex items-center justify-between border-t border-gray-200 px-4 sm:px-0" aria-label="Pagination">
      <div className="-mt-px w-0 flex-1 flex">
        <button
          onClick={() => onPageChange(currentPage - 1)}
          disabled={currentPage === 1}
          className="border-t-2 border-transparent pt-4 pr-1 inline-flex items-center text-sm font-medium text-gray-500 hover:text-gray-700 hover:border-gray-300 disabled:opacity-50 disabled:cursor-not-allowed"
          aria-label={t('pagination.aria.previousPage')}
        >
          <ChevronLeftIcon className="mr-3 h-5 w-5" aria-hidden="true" />
          {t('pagination.previous')}
        </button>
      </div>
      <div className="hidden md:-mt-px md:flex">
        {pageNumbers.map((page, index) => (
          typeof page === 'number' ? (
            <button
              key={index}
              onClick={() => onPageChange(page)}
              className={`${
                page === currentPage
                  ? 'border-indigo-500 text-indigo-600'
                  : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
              } border-t-2 pt-4 px-4 inline-flex items-center text-sm font-medium`}
              aria-label={page === currentPage 
                ? t('pagination.aria.currentPage', { page }) 
                : t('pagination.aria.goToPage', { page })}
              aria-current={page === currentPage ? 'page' : undefined}
            >
              {page}
            </button>
          ) : (
            <span
              key={index}
              className="border-transparent text-gray-500 border-t-2 pt-4 px-4 inline-flex items-center text-sm font-medium"
              aria-hidden="true"
            >
              {page}
            </span>
          )
        ))}
      </div>
      <div className="-mt-px w-0 flex-1 flex justify-end">
        <button
          onClick={() => onPageChange(currentPage + 1)}
          disabled={currentPage === totalPages}
          className="border-t-2 border-transparent pt-4 pl-1 inline-flex items-center text-sm font-medium text-gray-500 hover:text-gray-700 hover:border-gray-300 disabled:opacity-50 disabled:cursor-not-allowed"
          aria-label={t('pagination.aria.nextPage')}
        >
          {t('pagination.next')}
          <ChevronRightIcon className="ml-3 h-5 w-5" aria-hidden="true" />
        </button>
      </div>
      <div className="md:hidden mt-2 flex justify-center items-center text-sm text-gray-500">
        <span>
          {t('pagination.page', { page: currentPage })} {t('pagination.of', { total: totalPages })}
        </span>
      </div>
    </nav>
  );
}