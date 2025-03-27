// Custom Next.js server with HTTPS support
const http = require('http');
const https = require('https');
const { parse } = require('url');
const next = require('next');
const fs = require('fs');
const path = require('path');

const dev = process.env.NODE_ENV !== 'production';
const app = next({ dev });
const handle = app.getRequestHandler();

const port = process.env.PORT || 3000;
const useHttps = process.env.USE_HTTPS === 'true';
const hostname = process.env.HOSTNAME || '0.0.0.0';

// Default certificate paths - adjust as needed
const sslCertPath = process.env.SSL_CERT_PATH || '/app/certs/tls.crt';
const sslKeyPath = process.env.SSL_KEY_PATH || '/app/certs/tls.key';

// Define the API proxy path based on environment variables
const apiUrl = process.env.NEXT_PUBLIC_API_URL || 'https://api.dive25.local:8443/api/v1';
console.log(`Frontend API proxy set to: ${apiUrl}`);

// Print debug info about the current environment
console.log('Environment variables:');
console.log(`NODE_ENV: ${process.env.NODE_ENV}`);
console.log(`NEXT_PUBLIC_KEYCLOAK_URL: ${process.env.NEXT_PUBLIC_KEYCLOAK_URL}`);
console.log(`NEXT_PUBLIC_API_URL: ${apiUrl}`);

// CSS file that's causing CORS issues
const TARGET_CSS = 'cf2f07e87a7c6988.css';

app.prepare().then(() => {
    let server;

    // Function to handle requests
    const requestHandler = (req, res) => {
        // Parse URL
        const parsedUrl = parse(req.url, true);

        // Add cache busting headers to all responses
        res.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate, proxy-revalidate');
        res.setHeader('Pragma', 'no-cache');
        res.setHeader('Expires', '0');
        res.setHeader('Surrogate-Control', 'no-store');

        // Special handling for the problematic CSS file
        if (req.url.includes('/_next/static/css') && req.url.includes(TARGET_CSS)) {
            console.log(`Applying CORS headers to CSS file: ${req.url}`);

            // Add CORS headers
            res.setHeader('Access-Control-Allow-Origin', '*');
            res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
            res.setHeader('Access-Control-Allow-Headers', '*');
            res.setHeader('Cache-Control', 'public, max-age=31536000, immutable');

            // If it's an OPTIONS request, handle it immediately
            if (req.method === 'OPTIONS') {
                res.writeHead(204);
                res.end();
                return;
            }
        }

        // Handle CORS preflight requests for any other path
        if (req.method === 'OPTIONS') {
            res.setHeader('Access-Control-Allow-Origin', '*');
            res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS, PUT, PATCH, DELETE');
            res.setHeader('Access-Control-Allow-Headers', '*');
            res.writeHead(204);
            res.end();
            return;
        }

        // Let Next.js handle the request
        handle(req, res, parsedUrl);
    };

    if (useHttps) {
        console.log('Attempting to start server with HTTPS...');
        try {
            if (fs.existsSync(sslCertPath) && fs.existsSync(sslKeyPath)) {
                const httpsOptions = {
                    key: fs.readFileSync(sslKeyPath),
                    cert: fs.readFileSync(sslCertPath),
                    // Added to handle common SSL issues
                    rejectUnauthorized: false,
                    // Support older TLS versions
                    minVersion: 'TLSv1',
                    // Add more options if needed for troubleshooting
                    secureOptions: require('constants').SSL_OP_NO_SSLv3
                };

                console.log(`HTTPS configuration loaded with certificates from ${sslCertPath} and ${sslKeyPath}`);

                server = https.createServer(httpsOptions, requestHandler);
            } else {
                console.warn(`SSL certificates not found at: ${sslCertPath} or ${sslKeyPath}`);
                console.warn('Falling back to HTTP server');
                server = http.createServer(requestHandler);
            }
        } catch (error) {
            console.error('Error setting up HTTPS server:', error);
            console.warn('Falling back to HTTP server');
            server = http.createServer(requestHandler);
        }
    } else {
        console.log('Starting server with HTTP (HTTPS not enabled)');
        server = http.createServer(requestHandler);
    }

    server.listen(port, hostname, (err) => {
        if (err) throw err;
        console.log(`> Ready on ${useHttps ? 'https' : 'http'}://${hostname}:${port}`);

        // Log additional information about the environment
        console.log(`> Environment: ${process.env.NODE_ENV}`);
        console.log(`> HTTPS enabled: ${useHttps}`);
        if (useHttps) {
            console.log(`> Using SSL cert: ${sslCertPath}`);
            console.log(`> Using SSL key: ${sslKeyPath}`);
        }
    });
}); 