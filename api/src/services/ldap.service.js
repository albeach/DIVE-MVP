const { createLdapClient, bindLdapClient, searchBase, userSearchFilter, userSearchAttributes, groupSearchBase, groupSearchFilter, groupSearchAttributes } = require('../config/ldap.config');
const logger = require('../utils/logger');
const { ApiError } = require('../utils/error.utils');

/**
 * Search for a user in LDAP
 * @param {string} username - Username to search for
 * @returns {Promise<Object>} User attributes
 */
const searchUser = async (username) => {
    const client = createLdapClient();

    try {
        await bindLdapClient(client);

        const searchOptions = {
            scope: 'sub',
            filter: userSearchFilter.replace('{{username}}', username),
            attributes: userSearchAttributes
        };

        return new Promise((resolve, reject) => {
            client.search(searchBase, searchOptions, (err, res) => {
                if (err) {
                    logger.error('LDAP search error:', err);
                    return reject(new ApiError('LDAP search failed', 500));
                }

                let user = null;

                res.on('searchEntry', (entry) => {
                    user = entry.object;
                });

                res.on('error', (err) => {
                    logger.error('LDAP search result error:', err);
                    reject(new ApiError('LDAP search failed', 500));
                });

                res.on('end', (result) => {
                    if (result.status !== 0) {
                        logger.error('LDAP search ended with non-zero status:', result.status);
                        return reject(new ApiError('LDAP search failed', 500));
                    }

                    client.unbind();

                    if (!user) {
                        return reject(new ApiError('User not found', 404));
                    }

                    resolve(user);
                });
            });
        });
    } catch (error) {
        client.unbind();
        logger.error('LDAP search error:', error);
        throw error;
    }
};

/**
 * Get all users from LDAP with pagination
 * @param {number} page - Page number
 * @param {number} limit - Page size
 * @returns {Promise<Object>} Users and pagination info
 */
const getAllUsers = async (page = 1, limit = 10) => {
    const client = createLdapClient();

    try {
        await bindLdapClient(client);

        const searchOptions = {
            scope: 'sub',
            filter: '(objectClass=person)',
            attributes: userSearchAttributes,
            sizeLimit: 0
        };

        return new Promise((resolve, reject) => {
            client.search(searchBase, searchOptions, (err, res) => {
                if (err) {
                    logger.error('LDAP search error:', err);
                    return reject(new ApiError('LDAP search failed', 500));
                }

                const users = [];

                res.on('searchEntry', (entry) => {
                    users.push(entry.object);
                });

                res.on('error', (err) => {
                    logger.error('LDAP search result error:', err);
                    reject(new ApiError('LDAP search failed', 500));
                });

                res.on('end', (result) => {
                    if (result.status !== 0) {
                        logger.error('LDAP search ended with non-zero status:', result.status);
                        return reject(new ApiError('LDAP search failed', 500));
                    }

                    client.unbind();

                    // Calculate pagination
                    const total = users.length;
                    const startIndex = (page - 1) * limit;
                    const endIndex = startIndex + limit;
                    const paginatedUsers = users.slice(startIndex, endIndex);

                    resolve({
                        users: paginatedUsers,
                        pagination: {
                            total,
                            page,
                            limit,
                            totalPages: Math.ceil(total / limit)
                        }
                    });
                });
            });
        });
    } catch (error) {
        client.unbind();
        logger.error('LDAP search error:', error);
        throw error;
    }
};

/**
 * Get user's groups from LDAP
 * @param {string} userDN - User's Distinguished Name
 * @returns {Promise<Array>} List of groups
 */
const getUserGroups = async (userDN) => {
    const client = createLdapClient();

    try {
        await bindLdapClient(client);

        const searchOptions = {
            scope: 'sub',
            filter: groupSearchFilter.replace('{{dn}}', userDN),
            attributes: groupSearchAttributes
        };

        return new Promise((resolve, reject) => {
            client.search(groupSearchBase, searchOptions, (err, res) => {
                if (err) {
                    logger.error('LDAP group search error:', err);
                    return reject(new ApiError('LDAP group search failed', 500));
                }

                const groups = [];

                res.on('searchEntry', (entry) => {
                    groups.push(entry.object);
                });

                res.on('error', (err) => {
                    logger.error('LDAP group search result error:', err);
                    reject(new ApiError('LDAP group search failed', 500));
                });

                res.on('end', (result) => {
                    if (result.status !== 0) {
                        logger.error('LDAP group search ended with non-zero status:', result.status);
                        return reject(new ApiError('LDAP group search failed', 500));
                    }

                    client.unbind();
                    resolve(groups);
                });
            });
        });
    } catch (error) {
        client.unbind();
        logger.error('LDAP group search error:', error);
        throw error;
    }
};

/**
 * Get user with groups
 * @param {string} username - Username to search for
 * @returns {Promise<Object>} User with groups
 */
const getUserWithGroups = async (username) => {
    try {
        const user = await searchUser(username);

        if (user && user.dn) {
            const groups = await getUserGroups(user.dn);
            return {
                ...user,
                groups: groups.map(group => ({
                    cn: group.cn,
                    description: group.description
                }))
            };
        }

        return user;
    } catch (error) {
        logger.error('Error getting user with groups:', error);
        throw error;
    }
};

module.exports = {
    searchUser,
    getAllUsers,
    getUserGroups,
    getUserWithGroups
};
