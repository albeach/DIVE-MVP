import { useMemo } from 'react';
import { useAuth } from '@/context/auth-context';
import { Document, DocumentPermissions, ClassificationLevel } from '@/types/document';
import { hasRequiredClearance } from '@/lib/securityUtils';
import { createLogger } from '@/utils/logger';

const logger = createLogger('usePermissions');

/**
 * Hook for checking user permissions for documents and actions
 */
export function usePermissions() {
    const { user, hasRole, isAuthenticated } = useAuth();

    /**
     * Get the user's permissions for a specific document
     */
    const getDocumentPermissions = useMemo(() => {
        /**
         * Check if user has appropriate permissions for a document
         */
        return (document: Document): DocumentPermissions => {
            if (!isAuthenticated || !user) {
                logger.debug('User is not authenticated, no document permissions');
                return {
                    canView: false,
                    canDownload: false,
                    canEdit: false,
                    canDelete: false,
                    canShare: false,
                };
            }

            // Check security clearance
            const userClearance = user.clearance;
            const docClassification = document.metadata.classification as string;
            const hasClearance = hasRequiredClearance(userClearance, docClassification);

            // Check if user is the document owner
            const isOwner = document.metadata.creator?.id === user.uniqueId;

            // Check if user has admin role
            const isAdmin = hasRole(['admin', 'super_admin']);

            // Check if user has correct caveats
            const hasCaveats = document.metadata.caveats?.every(
                caveat => user.caveats?.includes(caveat)
            ) ?? true;

            // Check if user has correct COI access
            const hasCOI = document.metadata.coi?.every(
                coi => user.coi?.includes(coi)
            ) ?? true;

            // Determine permissions based on checks
            const canView = hasClearance && hasCaveats && hasCOI;
            const canDownload = canView;
            const canEdit = canView && (isOwner || isAdmin);
            const canDelete = canEdit && (isOwner || isAdmin);
            const canShare = canView && (isOwner || isAdmin || hasRole(['content_manager']));

            logger.debug(`Document permissions for ${document._id}:`, {
                canView,
                canDownload,
                canEdit,
                canDelete,
                canShare,
            });

            return {
                canView,
                canDownload,
                canEdit,
                canDelete,
                canShare,
            };
        };
    }, [isAuthenticated, user, hasRole]);

    /**
     * Check if user can create a document with given classification
     */
    const canCreateDocumentWithClassification = (classification: string): boolean => {
        if (!isAuthenticated || !user) {
            return false;
        }

        // User can create documents with classification level equal to or lower than their clearance
        return hasRequiredClearance(user.clearance, classification);
    };

    /**
     * Check if user has a specific system permission
     */
    const hasSystemPermission = (permission: string): boolean => {
        if (!isAuthenticated) {
            return false;
        }

        // Map permissions to required roles
        const permissionToRolesMap: Record<string, string[]> = {
            'manage_users': ['admin', 'super_admin', 'user_manager'],
            'view_audit_logs': ['admin', 'super_admin', 'auditor'],
            'manage_system_settings': ['super_admin'],
            'manage_documents': ['admin', 'super_admin', 'content_manager'],
            'export_data': ['admin', 'super_admin', 'data_exporter'],
        };

        const requiredRoles = permissionToRolesMap[permission] || [];
        return hasRole(requiredRoles);
    };

    return {
        getDocumentPermissions,
        canCreateDocumentWithClassification,
        hasSystemPermission,
    };
} 