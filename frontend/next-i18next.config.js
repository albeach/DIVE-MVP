// frontend/next-i18next.config.js
module.exports = {
    i18n: {
        defaultLocale: 'en',
        locales: ['en', 'fr'],
        localeDetection: false,
    },
    ns: ['common', 'profile', 'documents'],
    defaultNS: 'common',
    localePath: './public/locales'
};