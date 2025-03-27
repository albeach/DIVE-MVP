// This file is intentionally left minimal to avoid conflicts with next-i18next
// The actual i18n configuration is in next-i18next.config.js

// Import this file in _app.tsx to provide type definitions, but the actual
// initialization is handled by next-i18next's appWithTranslation HOC

import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';
import Backend from 'i18next-http-backend';
import LanguageDetector from 'i18next-browser-languagedetector';
import config from '../../next-i18next.config.js';

i18n
    .use(Backend)
    .use(LanguageDetector)
    .use(initReactI18next)
    .init({
        fallbackLng: 'en',
        debug: process.env.NODE_ENV === 'development',
        ns: config.ns,
        defaultNS: config.defaultNS,

        // Handle language variants like en-US -> map to en
        load: 'languageOnly',

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