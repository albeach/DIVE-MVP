// frontend/next.config.js
/** @type {import('next').NextConfig} */
const { i18n } = require('./next-i18next.config');

const nextConfig = {
    reactStrictMode: true,
    i18n,
    output: 'standalone',
    images: {
        domains: ['localhost', 'dive25.local', 'dive25.com'],
    },
    async headers() {
        return [
            {
                source: '/(.*)',
                headers: [
                    {
                        key: 'Content-Security-Policy',
                        value: `
              default-src 'self';
              script-src 'self' 'unsafe-eval' 'unsafe-inline';
              style-src 'self' 'unsafe-inline' https://fonts.googleapis.com;
              img-src 'self' data: blob:;
              font-src 'self' https://fonts.gstatic.com;
              connect-src 'self' https://keycloak.dive25.local https://*.dive25.local http://localhost:8080 http://localhost:3001 http://localhost:3000;
              frame-src 'self' https://keycloak.dive25.local https://*.dive25.local http://localhost:8080 http://localhost:3001;
              object-src 'none';
              base-uri 'self';
              form-action 'self';
              frame-ancestors 'self' https://keycloak.dive25.local https://*.dive25.local http://localhost:8080 http://localhost:3001;
              block-all-mixed-content;
            `.replace(/\s{2,}/g, ' ').trim(),
                    },
                    {
                        key: 'X-Frame-Options',
                        value: 'SAMEORIGIN',
                    },
                    {
                        key: 'X-Content-Type-Options',
                        value: 'nosniff',
                    },
                    {
                        key: 'X-XSS-Protection',
                        value: '1; mode=block',
                    },
                    {
                        key: 'Referrer-Policy',
                        value: 'strict-origin-when-cross-origin',
                    },
                    {
                        key: 'Permissions-Policy',
                        value: 'camera=(), microphone=(), geolocation=()',
                    },
                ],
            },
        ];
    },
    // Handle environment-specific configuration
    publicRuntimeConfig: {
        apiUrl: process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3000/api/v1',
        keycloakUrl: process.env.NEXT_PUBLIC_KEYCLOAK_URL || 'http://localhost:8080',
        keycloakRealm: process.env.NEXT_PUBLIC_KEYCLOAK_REALM || 'dive25',
        keycloakClientId: process.env.NEXT_PUBLIC_KEYCLOAK_CLIENT_ID || 'dive25-frontend',
    },
};

module.exports = nextConfig;