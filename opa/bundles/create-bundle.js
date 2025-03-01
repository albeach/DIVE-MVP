// opa/bundles/create-bundle.js
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// Configuration
const POLICIES_DIR = path.join(__dirname, '../policies');
const DATA_DIR = path.join(__dirname, '../data');
const BUNDLE_DIR = path.join(__dirname, 'dive25-policies');
const BUNDLE_TAR = path.join(__dirname, 'dive25-policies.tar.gz');

console.log('Creating OPA policy bundle...');

// Create bundle directory if it doesn't exist
if (!fs.existsSync(BUNDLE_DIR)) {
    fs.mkdirSync(BUNDLE_DIR, { recursive: true });
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

// Create bundle tar file
console.log('Creating bundle archive...');
execSync(`tar -czf ${BUNDLE_TAR} -C ${path.dirname(BUNDLE_DIR)} ${path.basename(BUNDLE_DIR)}`);

console.log(`Bundle created at: ${BUNDLE_TAR}`);