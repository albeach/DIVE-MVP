// frontend/src/lib/securityUtils.ts
export interface SecurityOption {
    value: string;
    label: string;
}

/**
 * Get available classification options
 */
export function getClassifications(): SecurityOption[] {
    return [
        { value: 'UNCLASSIFIED', label: 'UNCLASSIFIED' },
        { value: 'RESTRICTED', label: 'RESTRICTED' },
        { value: 'CONFIDENTIAL', label: 'CONFIDENTIAL' },
        { value: 'NATO CONFIDENTIAL', label: 'NATO CONFIDENTIAL' },
        { value: 'SECRET', label: 'SECRET' },
        { value: 'NATO SECRET', label: 'NATO SECRET' },
        { value: 'TOP SECRET', label: 'TOP SECRET' },
        { value: 'COSMIC TOP SECRET', label: 'COSMIC TOP SECRET' },
    ];
}

/**
 * Get available caveat options
 */
export function getCaveats(): SecurityOption[] {
    return [
        { value: 'FVEY', label: 'FVEY' },
        { value: 'NATO', label: 'NATO' },
        { value: 'EU', label: 'EU' },
        { value: 'NOFORN', label: 'NOFORN' },
        { value: 'ORCON', label: 'ORCON' },
        { value: 'PROPIN', label: 'PROPIN' },
    ];
}

/**
 * Get available releasability options (countries/orgs)
 */
export function getReleasability(): SecurityOption[] {
    return [
        { value: 'USA', label: 'USA' },
        { value: 'GBR', label: 'United Kingdom' },
        { value: 'CAN', label: 'Canada' },
        { value: 'AUS', label: 'Australia' },
        { value: 'NZL', label: 'New Zealand' },
        { value: 'FVEY', label: 'Five Eyes' },
        { value: 'NATO', label: 'NATO' },
        { value: 'EU', label: 'European Union' },
    ];
}

/**
 * Get available Communities of Interest (COI) options
 */
export function getCOIs(): SecurityOption[] {
    return [
        { value: 'OpAlpha', label: 'Operation Alpha' },
        { value: 'OpBravo', label: 'Operation Bravo' },
        { value: 'OpGamma', label: 'Operation Gamma' },
        { value: 'MissionX', label: 'Mission X' },
        { value: 'MissionZ', label: 'Mission Z' },
    ];
}

/**
 * Get classification level as a numeric value for comparison
 */
export function getClassificationLevel(classification: string): number {
    const levels: Record<string, number> = {
        'UNCLASSIFIED': 0,
        'RESTRICTED': 1,
        'CONFIDENTIAL': 2,
        'NATO CONFIDENTIAL': 2,
        'SECRET': 3,
        'NATO SECRET': 3,
        'TOP SECRET': 4,
        'COSMIC TOP SECRET': 4
    };

    return levels[classification] || 0;
}

/**
 * Check if user has clearance for a given classification level
 */
export function hasRequiredClearance(userClearance: string, requiredClearance: string): boolean {
    return getClassificationLevel(userClearance) >= getClassificationLevel(requiredClearance);
} 