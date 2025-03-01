const pino = require('pino');
const config = require('../config');

// Configure logger
const logger = pino({
    level: config.logLevel,
    formatters: {
        level: (label) => {
            return { level: label };
        },
    },
    timestamp: pino.stdTimeFunctions.isoTime,
    redact: {
        paths: ['password', 'token', 'authorization'],
        censor: '[REDACTED]'
    }
});

module.exports = logger;
