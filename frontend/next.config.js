// frontend/next.config.js
/** @type {import('next').NextConfig} */
const { i18n } = require('./next-i18next.config');

const nextConfig = {
    reactStrictMode: true,
    swcMinify: true,
    i18n,
    output: 'standalone',
    images: {
        domains: ['localhost', 'dive25.local', 'dive25.com'],
    },
    env: {
        baseUrl: process.env.NEXT_PUBLIC_BASE_URL || 'https://dive25.local:8443',
        apiUrl: process.env.NEXT_PUBLIC_API_URL || 'https://api.dive25.local:8443',
        keycloakUrl: process.env.NEXT_PUBLIC_KEYCLOAK_URL || 'https://keycloak.dive25.local:8443',
        keycloakRealm: process.env.NEXT_PUBLIC_KEYCLOAK_REALM || 'dive25',
        keycloakClientId: process.env.NEXT_PUBLIC_KEYCLOAK_CLIENT_ID || 'dive25-frontend',
        kongUrl: process.env.NEXT_PUBLIC_KONG_URL || 'https://dive25.local:8443',
        apiPath: '/api/v1',
    },
    async headers() {
        return [
            {
                source: '/:path*',
                headers: [
                    {
                        key: 'X-DNS-Prefetch-Control',
                        value: 'on'
                    },
                    {
                        key: 'Strict-Transport-Security',
                        value: 'max-age=63072000; includeSubDomains; preload'
                    },
                    {
                        key: 'X-XSS-Protection',
                        value: '1; mode=block'
                    },
                    {
                        key: 'X-Frame-Options',
                        value: 'SAMEORIGIN'
                    },
                    {
                        key: 'X-Content-Type-Options',
                        value: 'nosniff'
                    },
                    {
                        key: 'Referrer-Policy',
                        value: 'origin-when-cross-origin'
                    }
                ]
            },
            {
                source: '/country-select',
                headers: [
                    {
                        key: 'Content-Security-Policy',
                        value: "frame-ancestors 'self'; default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self' https://*.dive25.local:*; font-src 'self'; object-src 'none';"
                    }
                ]
            }
        ];
    },
    async redirects() {
        return [
            {
                source: '/login',
                destination: '/country-select',
                permanent: true,
            },
        ];
    },
};

module.exports = nextConfig;