// frontend/src/utils/formatters.ts
import { format } from 'date-fns';

/**
 * Format a date object to a readable string
 * @param date Date object
 * @returns Formatted date string
 */
export function formatDate(date: Date): string {
    return format(date, 'PPP');
}

/**
 * Format a file size in bytes to a human-readable string (KB, MB, GB)
 * @param bytes File size in bytes
 * @param decimals Number of decimal places to show
 * @returns Formatted file size string
 */
export function formatFileSize(bytes: number, decimals: number = 2): string {
    if (bytes === 0) return '0 Bytes';

    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB', 'PB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));

    return parseFloat((bytes / Math.pow(k, i)).toFixed(decimals)) + ' ' + sizes[i];
}