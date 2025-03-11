// frontend/src/components/layout/Footer.tsx
import { useTranslation } from 'next-i18next';
import Link from 'next/link';
import { useState, useEffect } from 'react';
import {
  ChatBubbleLeftRightIcon,
  QuestionMarkCircleIcon,
  ShieldCheckIcon,
  DocumentTextIcon,
  InformationCircleIcon
} from '@heroicons/react/24/outline';

interface AppVersion {
  version: string;
  buildDate?: string;
}

export function Footer() {
  const { t } = useTranslation('common');
  const currentYear = new Date().getFullYear();
  const [appVersion, setAppVersion] = useState<AppVersion | null>(null);

  useEffect(() => {
    // You could fetch the actual version from an API endpoint
    // This is a placeholder implementation
    const mockVersion = { version: '1.0.4' };
    setAppVersion(mockVersion);
  }, []);

  return (
    <footer className="bg-gray-50 border-t border-gray-200">
      {/* Main footer content */}
      <div className="max-w-7xl mx-auto py-6 px-4 sm:px-6 lg:px-8">
        <div className="grid grid-cols-1 md:grid-cols-4 gap-8">
          {/* App info */}
          <div className="col-span-1">
            <h3 className="text-sm font-semibold text-gray-900 tracking-wider uppercase">
              {t('app.name')}
            </h3>
            <p className="mt-2 text-sm text-gray-600">
              {t('app.description')}
            </p>
            {appVersion && (
              <p className="mt-4 text-xs text-gray-500">
                {t('footer.version')}: {appVersion.version}
              </p>
            )}
          </div>

          {/* Resources */}
          <div className="col-span-1">
            <h3 className="text-sm font-semibold text-gray-900 tracking-wider uppercase">
              Resources
            </h3>
            <ul className="mt-2 space-y-2">
              <li>
                <Link href="/documents" className="text-sm text-gray-600 hover:text-indigo-600 flex items-center">
                  <DocumentTextIcon className="h-4 w-4 mr-2" />
                  {t('navigation.documents')}
                </Link>
              </li>
              <li>
                <Link href="/dashboard" className="text-sm text-gray-600 hover:text-indigo-600 flex items-center">
                  <InformationCircleIcon className="h-4 w-4 mr-2" />
                  {t('navigation.dashboard')}
                </Link>
              </li>
            </ul>
          </div>

          {/* Support */}
          <div className="col-span-1">
            <h3 className="text-sm font-semibold text-gray-900 tracking-wider uppercase">
              Support
            </h3>
            <ul className="mt-2 space-y-2">
              <li>
                <a 
                  href="#" 
                  className="text-sm text-gray-600 hover:text-indigo-600 flex items-center"
                  onClick={(e) => {
                    e.preventDefault();
                    // You could open a feedback form modal here
                    alert('Feedback form would open here');
                  }}
                >
                  <ChatBubbleLeftRightIcon className="h-4 w-4 mr-2" />
                  {t('footer.feedbackLink')}
                </a>
              </li>
              <li>
                <Link href="/help" className="text-sm text-gray-600 hover:text-indigo-600 flex items-center">
                  <QuestionMarkCircleIcon className="h-4 w-4 mr-2" />
                  {t('footer.help')}
                </Link>
              </li>
              <li>
                <a 
                  href="https://dive25.com/contact" 
                  target="_blank" 
                  rel="noopener noreferrer" 
                  className="text-sm text-gray-600 hover:text-indigo-600 flex items-center"
                >
                  <ChatBubbleLeftRightIcon className="h-4 w-4 mr-2" />
                  {t('footer.contact')}
                </a>
              </li>
            </ul>
          </div>

          {/* Legal */}
          <div className="col-span-1">
            <h3 className="text-sm font-semibold text-gray-900 tracking-wider uppercase">
              Legal
            </h3>
            <ul className="mt-2 space-y-2">
              <li>
                <Link href="/privacy" className="text-sm text-gray-600 hover:text-indigo-600 flex items-center">
                  <ShieldCheckIcon className="h-4 w-4 mr-2" />
                  {t('footer.privacyPolicy')}
                </Link>
              </li>
              <li>
                <Link href="/terms" className="text-sm text-gray-600 hover:text-indigo-600 flex items-center">
                  <DocumentTextIcon className="h-4 w-4 mr-2" />
                  {t('footer.termsOfService')}
                </Link>
              </li>
              <li>
                <Link href="/about" className="text-sm text-gray-600 hover:text-indigo-600 flex items-center">
                  <InformationCircleIcon className="h-4 w-4 mr-2" />
                  {t('footer.aboutUs')}
                </Link>
              </li>
            </ul>
          </div>
        </div>
      </div>

      {/* Secondary footer with copyright and security notice */}
      <div className="border-t border-gray-200 py-4 bg-gray-100">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="md:flex md:items-center md:justify-between text-center md:text-left">
            <p className="text-sm text-gray-600">
              &copy; {currentYear} {t('app.name')}. {t('footer.allRightsReserved')}
            </p>
            <p className="mt-2 md:mt-0 text-xs text-gray-500 flex items-center justify-center md:justify-start">
              <ShieldCheckIcon className="h-4 w-4 mr-1 inline" />
              {t('footer.securityNotice')}
            </p>
          </div>
        </div>
      </div>
    </footer>
  );
}