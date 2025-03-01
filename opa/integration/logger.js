// opa/integration/logger.js
/**
 * Logger for OPA integration
 */

const { createLogger, format, transports } = require('winston');
const { combine, timestamp, printf, colorize } = format;

// Custom format for log messages
const myFormat = printf(({ level, message, timestamp, ...rest }) => {
    let logMessage = `${timestamp} ${level}: ${message}`;

    // Add any additional data if present
    if (Object.keys(rest).length > 0) {
        logMessage += ` ${JSON.stringify(rest)}`;
    }

    return logMessage;
});

// Create the logger
const logger = createLogger({
    level: process.env.LOG_LEVEL || 'info',
    format: combine(
        timestamp(),
        myFormat
    ),
    transports: [
        new transports.Console({
            format: combine(
                colorize(),
                timestamp(),
                myFormat
            )
        }),
        new transports.File({
            filename: 'opa-integration.log',
            dirname: process.env.LOG_DIR || './logs'
        })
    ]
});

module.exports = logger;