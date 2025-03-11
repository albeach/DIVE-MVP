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

app.prepare().then(() => {
    let server;

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

                server = https.createServer(httpsOptions, (req, res) => {
                    const parsedUrl = parse(req.url, true);
                    handle(req, res, parsedUrl);
                });
            } else {
                console.warn(`SSL certificates not found at: ${sslCertPath} or ${sslKeyPath}`);
                console.warn('Falling back to HTTP server');
                server = http.createServer((req, res) => {
                    const parsedUrl = parse(req.url, true);
                    handle(req, res, parsedUrl);
                });
            }
        } catch (error) {
            console.error('Error setting up HTTPS server:', error);
            console.warn('Falling back to HTTP server');
            server = http.createServer((req, res) => {
                const parsedUrl = parse(req.url, true);
                handle(req, res, parsedUrl);
            });
        }
    } else {
        console.log('Starting server with HTTP (HTTPS not enabled)');
        server = http.createServer((req, res) => {
            const parsedUrl = parse(req.url, true);
            handle(req, res, parsedUrl);
        });
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