/**
 * i18nHelper.ts
 * 
 * Central configuration for i18n to ensure consistency throughout the application.
 * Import this file instead of directly setting up namespaces in components.
 */

// All supported namespaces in the application
export const appNamespaces = ['common', 'translation', 'profile', 'documents'] as const;

// Default namespaces to use in most components
export const defaultNamespaces = ['common', 'translation'] as const;

// For use in getStaticProps/getServerSideProps
export const getAllNamespaces = () => [...appNamespaces];

// Helper to get translation keys that might be in either namespace
export const getTranslationFallbacks = {
    // App name can be in either common or translation namespace
    appName: ['common:appName', 'translation:app.name'],
    appDescription: ['common:app.description', 'translation:app.description'],

    // Common keys that might exist in either namespace
    navigation: {
        home: ['common:nav.home', 'translation:navigation.home'],
        documents: ['common:nav.documents', 'translation:navigation.documents'],
        dashboard: ['common:nav.dashboard', 'translation:navigation.dashboard'],
        profile: ['common:nav.profile', 'translation:navigation.profile'],
    },

    auth: {
        signIn: ['common:login.signIn', 'translation:auth.sign_in'],
        signOut: ['common:nav.signOut', 'translation:auth.sign_out'],
        getStarted: ['common:auth.get_started', 'translation:auth.get_started'],
    },

    session: {
        expiresIn: ['common:session.expires_in', 'translation:session.expires_in'],
        refresh: ['common:session.refresh', 'translation:session.refresh'],
        expired: ['common:session.expired', 'translation:session.expired'],
        aboutToExpire: ['common:session.about_to_expire', 'translation:session.about_to_expire'],
    },

    footer: {
        allRightsReserved: ['common:footer.allRightsReserved', 'translation:footer.allRightsReserved'],
        privacyPolicy: ['common:footer.privacyPolicy', 'translation:footer.privacyPolicy'],
        termsOfService: ['common:footer.termsOfService', 'translation:footer.termsOfService'],
        contact: ['common:footer.contact', 'translation:footer.contact'],
        rights: ['common:footer.allRightsReserved', 'translation:footer.allRightsReserved'],
        privacy: ['common:footer.privacyPolicy', 'translation:footer.privacyPolicy'],
        terms: ['common:footer.termsOfService', 'translation:footer.termsOfService'],
        securityNotice: ['common:footer.securityNotice', 'translation:footer.securityNotice'],
        aboutUs: ['common:footer.aboutUs', 'translation:footer.aboutUs'],
        help: ['common:footer.help', 'translation:footer.help'],
        feedbackLink: ['common:footer.feedbackLink', 'translation:footer.feedbackLink'],
        version: ['common:footer.version', 'translation:footer.version'],
        poweredBy: ['common:footer.poweredBy', 'translation:footer.poweredBy'],
    },

    // Home page specific keys
    pages: {
        home: {
            subtitle: ['common:home.subtitle', 'translation:pages.home.hero.subtitle'],
            viewDocuments: ['common:home.viewDocuments', 'translation:pages.home.hero.document_cta'],
            learnMore: ['common:home.learnMore', 'translation:pages.home.hero.learn_more'],
            features: {
                title: ['common:home.features.title', 'translation:pages.home.features.title'],
                feature1: {
                    title: ['common:home.features.feature1.title', 'translation:pages.home.features.feature1.title'],
                    description: ['common:home.features.feature1.description', 'translation:pages.home.features.feature1.description'],
                },
                feature2: {
                    title: ['common:home.features.feature2.title', 'translation:pages.home.features.feature2.title'],
                    description: ['common:home.features.feature2.description', 'translation:pages.home.features.feature2.description'],
                },
                feature3: {
                    title: ['common:home.features.feature3.title', 'translation:pages.home.features.feature3.title'],
                    description: ['common:home.features.feature3.description', 'translation:pages.home.features.feature3.description'],
                },
            },
            cta: {
                title: ['common:home.cta.title', 'translation:pages.home.cta.title'],
                description: ['common:home.cta.description', 'translation:pages.home.cta.description'],
                securityNote: ['common:home.cta.security_note', 'translation:pages.home.cta.security_note'],
                needHelp: ['common:home.cta.need_help', 'translation:pages.home.cta.need_help'],
            }
        }
    }
}; 