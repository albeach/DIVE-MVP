/**
 * Logger utility to standardize logging across the application
 * 
 * Benefits:
 * - Consistent formatting
 * - Support for different log levels
 * - Can be switched off in production
 * - Can add timestamps or other metadata
 * - Easy to extend for telemetry or server logging
 */

/**
 * Enum representing different log levels
 */
export enum LogLevel {
    ERROR = 0,
    WARN = 1,
    INFO = 2,
    DEBUG = 3
}

/**
 * Configuration interface for the logger
 */
interface LoggerConfig {
    level: LogLevel;
    enableConsole: boolean;
    prefix?: string;
}

/**
 * Global configuration for all loggers
 */
const globalConfig: LoggerConfig = {
    level: process.env.NODE_ENV === 'production' ? LogLevel.WARN : LogLevel.DEBUG,
    enableConsole: true
};

/**
 * Logger interface
 */
export interface Logger {
    error(message: string, ...data: any[]): void;
    warn(message: string, ...data: any[]): void;
    info(message: string, ...data: any[]): void;
    debug(message: string, ...data: any[]): void;
    setLevel(level: LogLevel): void;
}

/**
 * Create a logger with the specified name
 * @param name - The name for the logger
 * @returns A Logger instance
 */
export function createLogger(name: string): Logger {
    const config = { ...globalConfig, prefix: name };

    const formatMessage = (message: string): string => {
        return config.prefix ? `[${config.prefix}] ${message}` : message;
    };

    return {
        error(message: string, ...data: any[]): void {
            if (config.level >= LogLevel.ERROR && config.enableConsole) {
                if (data.length > 0) {
                    console.error(formatMessage(message), ...data);
                } else {
                    console.error(formatMessage(message));
                }
            }
        },

        warn(message: string, ...data: any[]): void {
            if (config.level >= LogLevel.WARN && config.enableConsole) {
                if (data.length > 0) {
                    console.warn(formatMessage(message), ...data);
                } else {
                    console.warn(formatMessage(message));
                }
            }
        },

        info(message: string, ...data: any[]): void {
            if (config.level >= LogLevel.INFO && config.enableConsole) {
                if (data.length > 0) {
                    console.info(formatMessage(message), ...data);
                } else {
                    console.info(formatMessage(message));
                }
            }
        },

        debug(message: string, ...data: any[]): void {
            if (config.level >= LogLevel.DEBUG && config.enableConsole) {
                if (data.length > 0) {
                    console.debug(formatMessage(message), ...data);
                } else {
                    console.debug(formatMessage(message));
                }
            }
        },

        setLevel(level: LogLevel): void {
            config.level = level;
        }
    };
}

/**
 * Set the global log level
 * @param level - The log level to set
 */
export function setGlobalLogLevel(level: LogLevel): void {
    globalConfig.level = level;
}

/**
 * Enable or disable console logging
 * @param enable - Whether to enable console logging
 */
export function enableConsoleLogging(enable: boolean): void {
    globalConfig.enableConsole = enable;
}

/**
 * Default logger instance
 */
export const logger = createLogger('App'); 