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
 * Format a file size in bytes to a human-readable string
 * @param bytes Size in bytes
 * @returns Formatted file size
 */
export function formatFileSize(bytes: number): string {
    if (bytes === 0) return '0 Bytes';

    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));

    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
}