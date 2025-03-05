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

export enum LogLevel {
    DEBUG = 'debug',
    INFO = 'info',
    WARN = 'warn',
    ERROR = 'error'
}

// Determine if we're in production
const isProduction = process.env.NODE_ENV === 'production';

// Configure which levels to enable based on environment
const enabledLevels: Record<LogLevel, boolean> = {
    [LogLevel.DEBUG]: !isProduction,
    [LogLevel.INFO]: true,
    [LogLevel.WARN]: true,
    [LogLevel.ERROR]: true
};

// Format prefix with time, level, and optional context
const formatPrefix = (level: LogLevel, context?: string): string => {
    const timestamp = new Date().toISOString();
    const levelFormatted = level.toUpperCase().padEnd(5, ' ');

    return context
        ? `[${timestamp}] ${levelFormatted} [${context}]:`
        : `[${timestamp}] ${levelFormatted}:`;
};

/**
 * Log a debug message
 */
export function debug(message: string, context?: string, ...args: any[]): void {
    if (!enabledLevels[LogLevel.DEBUG]) return;

    const prefix = formatPrefix(LogLevel.DEBUG, context);
    console.debug(prefix, message, ...args);
}

/**
 * Log an info message
 */
export function info(message: string, context?: string, ...args: any[]): void {
    if (!enabledLevels[LogLevel.INFO]) return;

    const prefix = formatPrefix(LogLevel.INFO, context);
    console.info(prefix, message, ...args);
}

/**
 * Log a warning message
 */
export function warn(message: string, context?: string, ...args: any[]): void {
    if (!enabledLevels[LogLevel.WARN]) return;

    const prefix = formatPrefix(LogLevel.WARN, context);
    console.warn(prefix, message, ...args);
}

/**
 * Log an error message
 */
export function error(message: string, context?: string, error?: any, ...args: any[]): void {
    if (!enabledLevels[LogLevel.ERROR]) return;

    const prefix = formatPrefix(LogLevel.ERROR, context);

    if (error instanceof Error) {
        console.error(prefix, message, error.message, ...args);
        console.error(error.stack);
    } else {
        console.error(prefix, message, error, ...args);
    }
}

/**
 * Create a logger instance for a specific context
 */
export function createLogger(context: string) {
    return {
        debug: (message: string, ...args: any[]) => debug(message, context, ...args),
        info: (message: string, ...args: any[]) => info(message, context, ...args),
        warn: (message: string, ...args: any[]) => warn(message, context, ...args),
        error: (message: string, errorObj?: any, ...args: any[]) => error(message, context, errorObj, ...args)
    };
}

// Default export with all methods
export default {
    debug,
    info,
    warn,
    error,
    createLogger
}; 