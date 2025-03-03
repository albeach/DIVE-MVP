const ldap = require('ldapjs');
const config = require('./index');
const logger = require('../utils/logger');

/**
 * Creates an LDAP client
 * @returns {ldap.Client} LDAP client
 */
const createLdapClient = () => {
    const client = ldap.createClient({
        url: config.ldap.url,
        timeout: 5000,
        connectTimeout: 10000,
    });

    client.on('error', (err) => {
        logger.error('LDAP client error:', err);
    });

    return client;
};

/**
 * Binds to LDAP server using admin credentials
 * @param {ldap.Client} client - LDAP client
 * @returns {Promise<void>}
 */
const bindLdapClient = (client) => {
    return new Promise((resolve, reject) => {
        client.bind(config.ldap.bindDN, config.ldap.bindCredentials, (err) => {
            if (err) {
                logger.error('LDAP bind error:', err);
                reject(err);
            } else {
                logger.debug('LDAP bind successful');
                resolve();
            }
        });
    });
};

module.exports = {
    createLdapClient,
    bindLdapClient,
    searchBase: config.ldap.searchBase,
    userSearchFilter: config.ldap.userSearchFilter,
    userSearchAttributes: config.ldap.userSearchAttributes,
    groupSearchBase: config.ldap.groupSearchBase,
    groupSearchFilter: config.ldap.groupSearchFilter,
    groupSearchAttributes: config.ldap.groupSearchAttributes
};
