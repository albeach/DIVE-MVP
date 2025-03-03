#!/bin/bash
# opa/setup-api-integration.sh
# Setup script for OPA-API integration

set -e  # Exit on any error

echo "Setting up OPA-API integration..."

# Script configuration
API_DIR="../api"
OPA_BUNDLE_DIR="./bundles"
API_BUNDLES_DIR="${API_DIR}/public/opa/bundles"
API_POLICY_DIR="${API_DIR}/src/policies/opa"

# Create necessary directories
echo "Creating necessary directories..."
mkdir -p "${API_BUNDLES_DIR}"
mkdir -p "${API_POLICY_DIR}"

# Copy policy files to API for reference
echo "Copying policy files to API for reference..."
cp -r ./policies/* "${API_POLICY_DIR}/"

# Set up bundle distribution
echo "Setting up bundle distribution..."
# Check if Node.js is installed
if command -v node >/dev/null 2>&1; then
    # Create environment file for bundle creation
    cat > "${OPA_BUNDLE_DIR}/.env" << EOF
BUNDLE_VERSION=1.0.0
BUNDLE_KEYID=global_key
BUNDLE_SCOPE=dive25
API_SERVER_PATH=${PWD}/${API_DIR}
EOF

    # Run bundle creation script
    echo "Creating initial bundle..."
    (cd "${OPA_BUNDLE_DIR}" && node create-bundle.js)
else
    echo "Warning: Node.js not found. Skipping bundle creation."
    echo "Please install Node.js and run 'node ./bundles/create-bundle.js' manually."
fi

# Create API routes for OPA
echo "Creating API routes for OPA integration..."
OPA_ROUTES_FILE="${API_DIR}/src/routes/opa.routes.js"
if [ ! -f "${OPA_ROUTES_FILE}" ]; then
    cat > "${OPA_ROUTES_FILE}" << EOF
// API routes for OPA integration
const express = require('express');
const router = express.Router();
const path = require('path');
const fs = require('fs');
const { checkAccess } = require('../middleware/auth.middleware');

// Route to serve OPA bundles
router.get('/bundles/:name', (req, res) => {
    const bundleName = req.params.name;
    const bundlePath = path.join(__dirname, '../../public/opa/bundles', \`\${bundleName}-bundle.tar.gz\`);
    
    if (fs.existsSync(bundlePath)) {
        res.download(bundlePath);
    } else {
        res.status(404).json({ message: \`Bundle \${bundleName} not found\` });
    }
});

// Route to check document access
router.post('/check-access', checkAccess, async (req, res) => {
    try {
        const { user, resource } = req.body;
        
        // Call OPA service to check access
        const opaService = require('../services/opa.service');
        const result = await opaService.checkDocumentAccess(user, resource);
        
        res.json(result);
    } catch (error) {
        res.status(500).json({ message: error.message });
    }
});

// Route to get policy information
router.get('/policy', checkAccess, async (req, res) => {
    try {
        const opaService = require('../services/opa.service');
        const policy = await opaService.getPolicy();
        res.json(policy);
    } catch (error) {
        res.status(500).json({ message: error.message });
    }
});

module.exports = router;
EOF

    echo "Created OPA routes file at: ${OPA_ROUTES_FILE}"
    
    # Add routes to API index routes file
    API_ROUTES_INDEX="${API_DIR}/src/routes/index.js"
    if [ -f "${API_ROUTES_INDEX}" ]; then
        # Check if OPA routes are already included
        if ! grep -q "opaRoutes" "${API_ROUTES_INDEX}"; then
            # Add import
            sed -i.bak '/const routes/a const opaRoutes = require("./opa.routes");' "${API_ROUTES_INDEX}"
            # Add route registration
            sed -i.bak '/module.exports = routes/i routes.use("/api/v1/opa", opaRoutes);' "${API_ROUTES_INDEX}"
            rm -f "${API_ROUTES_INDEX}.bak"
            echo "Added OPA routes to API routes index"
        else
            echo "OPA routes already included in API routes index"
        fi
    else
        echo "Warning: API routes index file not found at: ${API_ROUTES_INDEX}"
        echo "Please manually add OPA routes to your API routes configuration."
    fi
else
    echo "OPA routes file already exists at: ${OPA_ROUTES_FILE}"
fi

echo "Setting up scheduled bundle updates..."
CRON_FILE="./cron-bundle-update"
cat > "${CRON_FILE}" << EOF
# Run bundle update every hour
0 * * * * cd ${PWD}/bundles && node create-bundle.js >> ${PWD}/logs/bundle-update.log 2>&1
EOF

echo "Created cron schedule file at: ${CRON_FILE}"
echo "To install the cron job, run: crontab ${CRON_FILE}"

echo "OPA-API integration setup complete!"
echo ""
echo "Next steps:"
echo "1. Review the OPA configuration in opa/config.yaml"
echo "2. Make sure the API environment has OPA_URL set correctly"
echo "3. Restart the API and OPA services"
echo ""
echo "For production deployment:"
echo "- Set up proper authentication for the OPA server"
echo "- Configure TLS/HTTPS for communication between API and OPA"
echo "- Set up proper signing keys for bundles" 