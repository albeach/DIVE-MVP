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

console.log('Starting custom server with the following settings:');
console.log('- NODE_ENV:', process.env.NODE_ENV);
console.log('- USE_HTTPS:', process.env.USE_HTTPS);
console.log('- SSL_CERT_PATH:', sslCertPath);
console.log('- SSL_KEY_PATH:', sslKeyPath);

app.prepare().then(() => {
    let server;

    if (useHttps) {
        console.log('Attempting to start server with HTTPS...');
        try {
            // Check if certificate files exist and can be accessed
            console.log('Checking certificate files:');
            console.log('- Certificate exists:', fs.existsSync(sslCertPath));
            console.log('- Key exists:', fs.existsSync(sslKeyPath));

            if (fs.existsSync(sslCertPath) && fs.existsSync(sslKeyPath)) {
                // Try to read certificate files
                let certContent, keyContent;
                try {
                    certContent = fs.readFileSync(sslCertPath);
                    keyContent = fs.readFileSync(sslKeyPath);
                    console.log('Successfully read certificate files');
                } catch (readError) {
                    console.error('Error reading certificate files:', readError);
                    throw readError;
                }

                const httpsOptions = {
                    key: keyContent,
                    cert: certContent,
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

                console.log('HTTPS server created successfully');
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