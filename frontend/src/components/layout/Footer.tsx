// frontend/src/components/layout/Footer.tsx
import { useTranslation } from 'next-i18next';
import Link from 'next/link';

export function Footer() {
  const { t } = useTranslation('common');
  const currentYear = new Date().getFullYear();

  return (
    <footer className="bg-white border-t border-gray-200 py-6">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="md:flex md:items-center md:justify-between">
          <div className="flex justify-center space-x-6 md:order-2">
            <Link 
              href="/privacy" 
              className="text-gray-500 hover:text-dive25-600 text-sm"
            >
              {t('footer.privacyPolicy')}
            </Link>
            <Link 
              href="/terms" 
              className="text-gray-500 hover:text-dive25-600 text-sm"
            >
              {t('footer.termsOfService')}
            </Link>
            <a 
              href="https://dive25.com/contact" 
              target="_blank" 
              rel="noopener noreferrer" 
              className="text-gray-500 hover:text-dive25-600 text-sm"
            >
              {t('footer.contact')}
            </a>
          </div>
          
          <div className="mt-4 md:mt-0 md:order-1">
            <p className="text-center text-sm text-gray-500">
              &copy; {currentYear} {t('appName')}. {t('footer.allRightsReserved')}
            </p>
          </div>
        </div>

        <div className="mt-4 text-center text-xs text-gray-500">
          {t('footer.securityNotice')}
        </div>
      </div>
    </footer>
  );
}