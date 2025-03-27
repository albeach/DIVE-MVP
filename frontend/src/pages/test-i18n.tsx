import { GetStaticProps } from 'next';
import { useTranslation } from 'next-i18next';
import { serverSideTranslations } from 'next-i18next/serverSideTranslations';

export default function TestI18n() {
  const { t } = useTranslation(['common', 'translation']);
  
  // Create a table of translation keys and their values for debugging
  const translationKeys = [
    'app.name',
    'navigation.home',
    'auth.sign_in',
    'app.description',
    'common:app.name',
    'translation:app.name',
    'common:navigation.home',
    'translation:navigation.home',
  ];
  
  return (
    <div className="container mx-auto p-4">
      <h1 className="text-2xl font-bold mb-4">Translation Test Page</h1>
      
      <div className="mb-6">
        <h2 className="text-xl font-semibold mb-2">Common translations:</h2>
        <p><strong>App name:</strong> {t('app.name')}</p>
        <p><strong>Navigation home:</strong> {t('navigation.home')}</p>
        <p><strong>Sign in:</strong> {t('auth.sign_in')}</p>
      </div>
      
      <div className="mt-6">
        <h2 className="text-xl font-semibold mb-2">Debug Translation Table:</h2>
        <table className="min-w-full bg-white border border-gray-200">
          <thead>
            <tr>
              <th className="border border-gray-200 px-4 py-2">Key</th>
              <th className="border border-gray-200 px-4 py-2">Translated Value</th>
            </tr>
          </thead>
          <tbody>
            {translationKeys.map((key) => (
              <tr key={key}>
                <td className="border border-gray-200 px-4 py-2">{key}</td>
                <td className="border border-gray-200 px-4 py-2">{t(key)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      
      <div className="mt-6">
        <h2 className="text-xl font-semibold mb-2">Namespaced Translation Access:</h2>
        <p><strong>Explicit common namespace:</strong> {t('app.name', { ns: 'common' })}</p>
        <p><strong>Explicit translation namespace:</strong> {t('app.name', { ns: 'translation' })}</p>
      </div>
    </div>
  );
}

export const getStaticProps: GetStaticProps = async ({ locale }) => {
  return {
    props: {
      ...(await serverSideTranslations(locale || 'en', ['common', 'translation'])),
    },
  };
}; 