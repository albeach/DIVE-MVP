// frontend/src/utils/date.ts
import { format } from 'date-fns';

/**
 * Format a date to a human-readable string
 * @param date Date object or string
 * @returns Formatted date string
 */
export function formatDate(date: Date | string): string {
    const parsedDate = typeof date === 'string' ? new Date(date) : date;
    return format(parsedDate, 'PPP');
}

/**
 * Format a relative date/time
 * @param date Date object or string
 * @returns Relative time string
 */
export function formatRelativeDate(date: Date | string): string {
    const parsedDate = typeof date === 'string' ? new Date(date) : date;
    return format(parsedDate, 'PP');
}

/**
 * Check if a date is recent (within the last week)
 * @param date Date object or string
 * @returns Boolean indicating if date is recent
 */
export function isRecentDate(date: Date | string): boolean {
    const parsedDate = typeof date === 'string' ? new Date(date) : date;
    const oneWeekAgo = new Date();
    oneWeekAgo.setDate(oneWeekAgo.getDate() - 7);
    return parsedDate > oneWeekAgo;
}