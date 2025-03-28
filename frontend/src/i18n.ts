import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';
import Backend from 'i18next-http-backend';
import LanguageDetector from 'i18next-browser-languagedetector';

i18n
    .use(Backend)
    .use(LanguageDetector)
    .use(initReactI18next)
    .init({
        fallbackLng: 'en',
        supportedLngs: ['en', 'fr'],
        debug: process.env.NODE_ENV === 'development',

        // Handle language variants like en-US -> map to en
        load: 'languageOnly',

        ns: ['common', 'profile', 'documents'],
        defaultNS: 'common',

        interpolation: {
            escapeValue: false,
        },

        backend: {
            loadPath: '/locales/{{lng}}/{{ns}}.json',
        },

        react: {
            useSuspense: false,
        },
    });

export default i18n; 