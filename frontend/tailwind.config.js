// frontend/tailwind.config.js
const { fontFamily } = require('tailwindcss/defaultTheme');

/** @type {import('tailwindcss').Config} */
module.exports = {
    darkMode: ['class'],
    content: ['./src/pages/**/*.{js,ts,jsx,tsx}', './src/components/**/*.{js,ts,jsx,tsx}'],
    theme: {
        container: {
            center: true,
            padding: '2rem',
            screens: {
                '2xl': '1400px',
            },
        },
        extend: {
            fontSize: {
                'base': '1.0625rem',
                'lg': '1.125rem',
                'xl': '1.25rem',
                '2xl': '1.5rem',
                '3xl': '1.875rem',
                '4xl': '2.25rem',
                '5xl': '3rem',
            },
            colors: {
                border: 'hsl(var(--border))',
                input: 'hsl(var(--input))',
                ring: 'hsl(var(--ring))',
                background: 'hsl(var(--background))',
                foreground: 'hsl(var(--foreground))',
                primary: {
                    DEFAULT: '#173518', // Base dark green color
                    50: '#edf7ed',    // Lightest tint
                    100: '#d1ecd2',   // Very light tint
                    200: '#a7d8a8',   // Light tint
                    300: '#7fc280',   // Medium light tint
                    400: '#54ab56',   // Medium tint
                    500: '#3d883f',   // Medium dark tint
                    600: '#306c32',   // Dark tint
                    700: '#254a26',   // Darker tint
                    800: '#1d3b1e',   // Very dark tint 
                    900: '#173518',   // Original dark green
                    950: '#0b1b0c',   // Darkest shade
                },
                dive25: {
                    DEFAULT: '#173518', // Base dark green
                    50: '#edf7ed',
                    100: '#d1ecd2',
                    200: '#a7d8a8',
                    300: '#7fc280',
                    400: '#54ab56',
                    500: '#3d883f',
                    600: '#306c32',
                    700: '#254a26',
                    800: '#1d3b1e',
                    900: '#173518',
                    950: '#0b1b0c',
                },
                secondary: {
                    DEFAULT: 'hsl(var(--secondary))',
                    foreground: 'hsl(var(--secondary-foreground))',
                },
                destructive: {
                    DEFAULT: 'hsl(var(--destructive))',
                    foreground: 'hsl(var(--destructive-foreground))',
                },
                muted: {
                    DEFAULT: 'hsl(var(--muted))',
                    foreground: 'hsl(var(--muted-foreground))',
                },
                accent: {
                    DEFAULT: 'hsl(var(--accent))',
                    foreground: 'hsl(var(--accent-foreground))',
                },
                popover: {
                    DEFAULT: 'hsl(var(--popover))',
                    foreground: 'hsl(var(--popover-foreground))',
                },
                card: {
                    DEFAULT: 'hsl(var(--card))',
                    foreground: 'hsl(var(--card-foreground))',
                },
                'nato-blue': '#003d7a',
                'classification': {
                    'unclassified': '#28a745',
                    'restricted': '#ffc107',
                    'confidential': '#fd7e14',
                    'secret': '#dc3545',
                    'top-secret': '#6f42c1',
                },
            },
            fontFamily: {
                sans: [
                    'Inter var',
                    'system-ui',
                    '-apple-system',
                    'BlinkMacSystemFont',
                    'Segoe UI',
                    'Roboto',
                    'Helvetica Neue',
                    'Arial',
                    'sans-serif',
                    ...fontFamily.sans
                ],
                mono: ['JetBrains Mono', 'Roboto Mono', 'Menlo', 'Monaco', 'Consolas', 'monospace'],
            },
            height: {
                'screen-navbar': 'calc(100vh - 64px)',
                'screen-small': '100svh',
            },
        },
    },
    plugins: [],
};