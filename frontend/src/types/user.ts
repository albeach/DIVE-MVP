// frontend/src/types/user.ts
export interface User {
    uniqueId: string;
    username: string;
    email: string;
    givenName: string;
    surname: string;
    organization: string;
    countryOfAffiliation: string;
    clearance: string;
    caveats?: string[];
    coi?: string[];
    roles?: string[];
    lastLogin?: string;
}