// opa/bundles/create-bundle.js
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');
const crypto = require('crypto');

// Configuration
const POLICIES_DIR = path.join(__dirname, '../policies');
const DATA_DIR = path.join(__dirname, '../data');
const BUNDLE_DIR = path.join(__dirname, 'dive25');
const BUNDLE_TAR = path.join(__dirname, 'dive25-bundle.tar.gz');

// Environment variables with defaults
const BUNDLE_VERSION = process.env.BUNDLE_VERSION || '1.0.0';
const BUNDLE_KEYID = process.env.BUNDLE_KEYID || 'global_key';
const BUNDLE_SCOPE = process.env.BUNDLE_SCOPE || 'dive25';

console.log('Creating OPA policy bundle...');

// Create bundle directory if it doesn't exist
if (!fs.existsSync(BUNDLE_DIR)) {
    fs.mkdirSync(BUNDLE_DIR, { recursive: true });
} else {
    // Clean existing bundle directory
    execSync(`rm -rf ${BUNDLE_DIR}/*`);
}

// Copy policies to bundle directory
console.log('Copying policies...');
execSync(`cp -r ${POLICIES_DIR}/* ${BUNDLE_DIR}/`);

// Copy data to bundle directory if it exists
if (fs.existsSync(DATA_DIR)) {
    console.log('Copying data...');
    if (!fs.existsSync(path.join(BUNDLE_DIR, 'data'))) {
        fs.mkdirSync(path.join(BUNDLE_DIR, 'data'), { recursive: true });
    }
    execSync(`cp -r ${DATA_DIR}/* ${BUNDLE_DIR}/data/`);
}

// Create .manifest file for the bundle
console.log('Creating bundle manifest...');
const manifest = {
    revision: BUNDLE_VERSION,
    roots: ['dive25', 'access_policy'],
    metadata: {
        created_at: new Date().toISOString(),
        created_by: 'dive25-bundle-tool'
    }
};

fs.writeFileSync(path.join(BUNDLE_DIR, '.manifest'), JSON.stringify(manifest, null, 2));

// Generate a signature file if keys are available
const privateKeyPath = process.env.OPA_PRIVATE_KEY_PATH;
if (privateKeyPath && fs.existsSync(privateKeyPath)) {
    console.log('Signing bundle...');

    try {
        // Read private key
        const privateKey = fs.readFileSync(privateKeyPath, 'utf8');

        // Create a signature object
        const signature = {
            keyid: BUNDLE_KEYID,
            algorithm: 'RS256',
            scope: BUNDLE_SCOPE,
            signed: {
                manifest: manifest,
                timestamp: new Date().toISOString()
            }
        };

        // Stringify the payload that will be signed
        const payload = JSON.stringify(signature.signed);

        // Create a signature
        const sign = crypto.createSign('RSA-SHA256');
        sign.update(payload);
        const signatureValue = sign.sign({
            key: privateKey,
            padding: crypto.constants.RSA_PKCS1_PADDING
        }, 'base64');

        // Add the signature value to the signature object
        signature.signature = signatureValue;

        // Write the signature file
        fs.writeFileSync(path.join(BUNDLE_DIR, '.signatures.json'), JSON.stringify([signature], null, 2));
        console.log('Bundle signed successfully');
    } catch (error) {
        console.error('Error signing bundle:', error);
        console.log('Continuing without signature...');
    }
} else {
    console.log('No private key found. Skipping bundle signing.');
}

// Create bundle tar file
console.log('Creating bundle archive...');
execSync(`tar -czf ${BUNDLE_TAR} -C ${path.dirname(BUNDLE_DIR)} ${path.basename(BUNDLE_DIR)}`);

console.log(`Bundle created at: ${BUNDLE_TAR}`);

// Create an API endpoint to serve the bundle if API_SERVER_PATH is specified
const API_SERVER_PATH = process.env.API_SERVER_PATH;
if (API_SERVER_PATH && fs.existsSync(API_SERVER_PATH)) {
    console.log('Copying bundle to API server...');
    const bundleApiDir = path.join(API_SERVER_PATH, 'public/opa/bundles');

    if (!fs.existsSync(bundleApiDir)) {
        fs.mkdirSync(bundleApiDir, { recursive: true });
    }

    fs.copyFileSync(BUNDLE_TAR, path.join(bundleApiDir, 'dive25-bundle.tar.gz'));
    console.log(`Bundle copied to API server at: ${bundleApiDir}`);
}

console.log('Bundle creation completed successfully.');