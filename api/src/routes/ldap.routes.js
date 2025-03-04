const express = require('express');
const { searchUser, getAllUsers, getUserWithGroups } = require('../services/ldap.service');
const { authenticate } = require('../middleware/auth.middleware');
const { ApiError } = require('../utils/error.utils');
const ldap = require('ldapjs');
const config = require('../config/index');
const logger = require('../utils/logger');

const router = express.Router();

/**
 * @swagger
 * /api/v1/ldap/users:
 *   get:
 *     summary: Get all users from LDAP
 *     description: Retrieves all users from LDAP with pagination
 *     tags: [LDAP]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: page
 *         schema:
 *           type: integer
 *           default: 1
 *         description: Page number
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           default: 10
 *         description: Items per page
 *     responses:
 *       200:
 *         description: Success
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 users:
 *                   type: array
 *                   items:
 *                     type: object
 *                 pagination:
 *                   type: object
 *       401:
 *         description: Unauthorized
 *       500:
 *         description: Server Error
 */
router.get('/users', authenticate, async (req, res, next) => {
    try {
        const page = parseInt(req.query.page, 10) || 1;
        const limit = parseInt(req.query.limit, 10) || 10;

        const result = await getAllUsers(page, limit);

        res.json(result);
    } catch (error) {
        next(error);
    }
});

/**
 * @swagger
 * /api/v1/ldap/users/{username}:
 *   get:
 *     summary: Get user by username
 *     description: Retrieves a user from LDAP by username
 *     tags: [LDAP]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: username
 *         required: true
 *         schema:
 *           type: string
 *         description: Username to search for
 *     responses:
 *       200:
 *         description: Success
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *       401:
 *         description: Unauthorized
 *       404:
 *         description: User not found
 *       500:
 *         description: Server Error
 */
router.get('/users/:username', authenticate, async (req, res, next) => {
    try {
        const { username } = req.params;

        if (!username) {
            throw new ApiError('Username is required', 400);
        }

        const user = await searchUser(username);

        res.json(user);
    } catch (error) {
        next(error);
    }
});

/**
 * @swagger
 * /api/v1/ldap/test:
 *   get:
 *     summary: Test LDAP connection
 *     description: Tests the LDAP connection and retrieves configuration
 *     tags: [LDAP]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Success
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *       401:
 *         description: Unauthorized
 *       500:
 *         description: Server Error
 */
router.get('/test', authenticate, async (req, res, next) => {
    try {
        const ldapConfig = require('../config/index').ldap;

        // Remove sensitive information
        const safeConfig = {
            url: ldapConfig.url,
            bindDN: ldapConfig.bindDN,
            searchBase: ldapConfig.searchBase,
            userSearchFilter: ldapConfig.userSearchFilter
        };

        res.json({
            status: 'success',
            message: 'LDAP configuration loaded',
            config: safeConfig
        });
    } catch (error) {
        next(error);
    }
});

/**
 * @swagger
 * /api/v1/ldap/authenticate:
 *   post:
 *     summary: Test LDAP authentication
 *     description: Tests LDAP authentication with username/password
 *     tags: [LDAP]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - username
 *               - password
 *             properties:
 *               username:
 *                 type: string
 *               password:
 *                 type: string
 *     responses:
 *       200:
 *         description: Authentication successful
 *       401:
 *         description: Authentication failed
 *       500:
 *         description: Server Error
 */
router.post('/authenticate', async (req, res, next) => {
    try {
        const { username, password } = req.body;

        if (!username || !password) {
            throw new ApiError('Username and password are required', 400);
        }

        // Create LDAP client
        const client = ldap.createClient({
            url: config.ldap.url,
            timeout: 5000,
            connectTimeout: 10000,
        });

        // First find the user DN
        const adminClient = ldap.createClient({
            url: config.ldap.url,
            timeout: 5000,
            connectTimeout: 10000,
        });

        try {
            // Bind as admin to search for user
            await new Promise((resolve, reject) => {
                adminClient.bind(config.ldap.bindDN, config.ldap.bindCredentials, (err) => {
                    if (err) {
                        logger.error('Admin LDAP bind error:', err);
                        reject(err);
                    } else {
                        resolve();
                    }
                });
            });

            // Search for user
            const userDN = await new Promise((resolve, reject) => {
                const searchOptions = {
                    scope: 'sub',
                    filter: config.ldap.userSearchFilter.replace('{{username}}', username),
                    attributes: ['dn']
                };

                adminClient.search(config.ldap.searchBase, searchOptions, (err, res) => {
                    if (err) {
                        logger.error('LDAP search error:', err);
                        return reject(new ApiError('LDAP search failed', 500));
                    }

                    let userDN = null;

                    res.on('searchEntry', (entry) => {
                        userDN = entry.objectName;
                    });

                    res.on('error', (err) => {
                        logger.error('LDAP search result error:', err);
                        reject(new ApiError('LDAP search failed', 500));
                    });

                    res.on('end', () => {
                        if (!userDN) {
                            return reject(new ApiError('User not found', 404));
                        }
                        resolve(userDN);
                    });
                });
            });

            // Unbind admin client
            adminClient.unbind();

            // Attempt to bind as user
            await new Promise((resolve, reject) => {
                client.bind(userDN, password, (err) => {
                    if (err) {
                        logger.error('User LDAP bind error:', err);
                        reject(new ApiError('Authentication failed', 401));
                    } else {
                        resolve();
                    }
                });
            });

            // If we get here, authentication succeeded
            client.unbind();
            res.json({
                status: 'success',
                message: 'Authentication successful',
                username: username
            });
        } catch (error) {
            // Make sure to unbind clients
            try { adminClient.unbind(); } catch (e) {
                // Ignore unbind errors during cleanup
            }
            try { client.unbind(); } catch (e) {
                // Ignore unbind errors during cleanup
            }
            throw error;
        }
    } catch (error) {
        next(error);
    }
});

/**
 * @swagger
 * /api/v1/ldap/users/{username}/groups:
 *   get:
 *     summary: Get user with groups
 *     description: Retrieves a user from LDAP by username along with their groups
 *     tags: [LDAP]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: username
 *         required: true
 *         schema:
 *           type: string
 *         description: Username to search for
 *     responses:
 *       200:
 *         description: Success
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *       401:
 *         description: Unauthorized
 *       404:
 *         description: User not found
 *       500:
 *         description: Server Error
 */
router.get('/users/:username/groups', authenticate, async (req, res, next) => {
    try {
        const { username } = req.params;

        if (!username) {
            throw new ApiError('Username is required', 400);
        }

        const userWithGroups = await getUserWithGroups(username);

        res.json(userWithGroups);
    } catch (error) {
        next(error);
    }
});

module.exports = router; 