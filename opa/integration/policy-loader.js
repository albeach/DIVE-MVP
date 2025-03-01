// opa/integration/policy-loader.js
/**
 * Policy Loader for DIVE25
 * Automatically loads and updates policies in OPA
 */

const fs = require('fs');
const path = require('path');
const axios = require('axios');
const { watch } = require('chokidar');
const logger = require('./logger');

class PolicyLoader {
    /**
     * Creates a new policy loader
     * @param {string} policiesDir - Directory containing policy files
     * @param {string} opaUrl - Base URL for the OPA service
     */
    constructor(policiesDir = path.resolve(__dirname, '../policies'), opaUrl = 'http://localhost:8181') {
        this.policiesDir = policiesDir;
        this.opaUrl = opaUrl;
        this.client = axios.create({
            baseURL: this.opaUrl,
            timeout: 5000,
            headers: {
                'Content-Type': 'text/plain'
            }
        });
    }

    /**
     * Load all policies from the policies directory
     */
    async loadAllPolicies() {
        try {
            logger.info('Loading all policies into OPA...');

            const files = this.findPolicyFiles(this.policiesDir);

            for (const file of files) {
                await this.loadPolicyFile(file);
            }

            logger.info(`Successfully loaded ${files.length} policies.`);
        } catch (error) {
            logger.error('Error loading policies:', error);
            throw error;
        }
    }

    /**
     * Find all Rego policy files in a directory
     * @param {string} dir - Directory to search
     * @param {Array} files - Accumulator for found files
     * @returns {Array} - Array of file paths
     */
    findPolicyFiles(dir, files = []) {
        const entries = fs.readdirSync(dir, { withFileTypes: true });

        for (const entry of entries) {
            const fullPath = path.join(dir, entry.name);

            if (entry.isDirectory()) {
                this.findPolicyFiles(fullPath, files);
            } else if (entry.isFile() && entry.name.endsWith('.rego')) {
                files.push(fullPath);
            }
        }

        return files;
    }

    /**
     * Load a single policy file into OPA
     * @param {string} filePath - Path to the policy file
     */
    async loadPolicyFile(filePath) {
        try {
            const content = fs.readFileSync(filePath, 'utf8');
            const packageMatch = content.match(/^package\s+([^\s]+)/m);

            if (!packageMatch) {
                logger.warn(`Could not determine package for ${filePath}, skipping.`);
                return;
            }

            const packageName = packageMatch[1];
            const policyId = packageName.replace(/\./g, '/');

            logger.info(`Loading policy ${packageName} from ${filePath}...`);

            await this.client.put(`/v1/policies/${policyId}`, content);

            logger.info(`Successfully loaded policy ${packageName}.`);
        } catch (error) {
            logger.error(`Error loading policy file ${filePath}:`, error.response?.data || error.message);
            throw error;
        }
    }

    /**
     * Watch the policies directory for changes and reload policies automatically
     */
    watchPolicies() {
        logger.info(`Watching ${this.policiesDir} for policy changes...`);

        const watcher = watch(this.policiesDir, {
            persistent: true,
            ignoreInitial: true,
            awaitWriteFinish: {
                stabilityThreshold: 2000,
                pollInterval: 100
            }
        });

        watcher.on('add', (filePath) => {
            if (filePath.endsWith('.rego')) {
                logger.info(`New policy file detected: ${filePath}`);
                this.loadPolicyFile(filePath).catch(error => {
                    logger.error(`Failed to load new policy ${filePath}:`, error);
                });
            }
        });

        watcher.on('change', (filePath) => {
            if (filePath.endsWith('.rego')) {
                logger.info(`Policy file changed: ${filePath}`);
                this.loadPolicyFile(filePath).catch(error => {
                    logger.error(`Failed to reload policy ${filePath}:`, error);
                });
            }
        });

        watcher.on('unlink', (filePath) => {
            if (filePath.endsWith('.rego')) {
                logger.info(`Policy file removed: ${filePath}`);
                // You might want to handle policy removal here
            }
        });

        watcher.on('error', (error) => {
            logger.error('Policy watcher error:', error);
        });

        return watcher;
    }
}

module.exports = PolicyLoader;

// If this script is run directly, load all policies
if (require.main === module) {
    const loader = new PolicyLoader();
    loader.loadAllPolicies().then(() => {
        logger.info('Policy loading completed.');
        process.exit(0);
    }).catch(error => {
        logger.error('Policy loading failed:', error);
        process.exit(1);
    });
}