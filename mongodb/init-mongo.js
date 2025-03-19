// mongodb/init-mongo.js
// MongoDB initialization script for DIVE25

// Connect with admin credentials
db = db.getSiblingDB('admin');

// Create application database
db = db.getSiblingDB('dive25');

// Create application user
db.createUser({
    user: 'dive25_app',
    pwd: 'app_password',  // Should be set via environment variable in production
    roles: [
        { role: 'readWrite', db: 'dive25' }
    ],
    mechanisms: ['SCRAM-SHA-256']
});

// Create admin user for the dive25 database
db.createUser({
    user: 'dive25_admin',
    pwd: 'admin_password',  // Should be set via environment variable in production
    roles: [
        { role: 'dbAdmin', db: 'dive25' },
        { role: 'readWrite', db: 'dive25' }
    ],
    mechanisms: ['SCRAM-SHA-256']
});

// Create read-only user for the dive25 database
db.createUser({
    user: 'dive25_readonly',
    pwd: 'readonly_password',  // Should be set via environment variable in production
    roles: [
        { role: 'read', db: 'dive25' }
    ],
    mechanisms: ['SCRAM-SHA-256']
});

// Create collections with schema validation

// Documents collection - stores document metadata
db.createCollection('documents', {
    validator: {
        $jsonSchema: {
            bsonType: 'object',
            required: ['filename', 'fileId', 'mimeType', 'size', 'metadata', 'uploadDate'],
            properties: {
                filename: {
                    bsonType: 'string',
                    description: 'Filename must be a string and is required'
                },
                fileId: {
                    bsonType: 'string',
                    description: 'File ID must be a string and is required'
                },
                mimeType: {
                    bsonType: 'string',
                    description: 'MIME type must be a string and is required'
                },
                size: {
                    bsonType: 'int',
                    minimum: 0,
                    description: 'Size must be a non-negative integer and is required'
                },
                metadata: {
                    bsonType: 'object',
                    required: ['classification', 'creator'],
                    properties: {
                        classification: {
                            bsonType: 'string',
                            enum: ['UNCLASSIFIED', 'RESTRICTED', 'NATO CONFIDENTIAL', 'NATO SECRET', 'COSMIC TOP SECRET'],
                            description: 'Classification must be one of the allowed values and is required'
                        },
                        releasability: {
                            bsonType: 'array',
                            items: {
                                bsonType: 'string'
                            },
                            description: 'Releasability must be an array of strings'
                        },
                        caveats: {
                            bsonType: 'array',
                            items: {
                                bsonType: 'string'
                            },
                            description: 'Caveats must be an array of strings'
                        },
                        coi: {
                            bsonType: 'array',
                            items: {
                                bsonType: 'string'
                            },
                            description: 'COI tags must be an array of strings'
                        },
                        policyIdentifier: {
                            bsonType: 'string',
                            description: 'Policy identifier must be a string'
                        },
                        creator: {
                            bsonType: 'object',
                            required: ['id', 'name', 'organization', 'country'],
                            properties: {
                                id: {
                                    bsonType: 'string',
                                    description: 'Creator ID must be a string and is required'
                                },
                                name: {
                                    bsonType: 'string',
                                    description: 'Creator name must be a string and is required'
                                },
                                organization: {
                                    bsonType: 'string',
                                    description: 'Creator organization must be a string and is required'
                                },
                                country: {
                                    bsonType: 'string',
                                    description: 'Creator country must be a string and is required'
                                }
                            }
                        }
                    }
                },
                uploadDate: {
                    bsonType: 'date',
                    description: 'Upload date must be a date and is required'
                },
                lastAccessedDate: {
                    bsonType: 'date',
                    description: 'Last accessed date must be a date'
                },
                lastModifiedDate: {
                    bsonType: 'date',
                    description: 'Last modified date must be a date'
                }
            }
        }
    },
    validationLevel: 'strict',
    validationAction: 'error'
});

// Users collection - stores user information
db.createCollection('users', {
    validator: {
        $jsonSchema: {
            bsonType: 'object',
            required: ['uniqueId', 'username', 'email', 'givenName', 'surname', 'organization', 'countryOfAffiliation', 'clearance'],
            properties: {
                uniqueId: {
                    bsonType: 'string',
                    description: 'Unique ID must be a string and is required'
                },
                username: {
                    bsonType: 'string',
                    description: 'Username must be a string and is required'
                },
                email: {
                    bsonType: 'string',
                    pattern: '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$',
                    description: 'Email must be a valid email address and is required'
                },
                givenName: {
                    bsonType: 'string',
                    description: 'Given name must be a string and is required'
                },
                surname: {
                    bsonType: 'string',
                    description: 'Surname must be a string and is required'
                },
                organization: {
                    bsonType: 'string',
                    description: 'Organization must be a string and is required'
                },
                countryOfAffiliation: {
                    bsonType: 'string',
                    description: 'Country of affiliation must be a string and is required'
                },
                clearance: {
                    bsonType: 'string',
                    enum: ['UNCLASSIFIED', 'RESTRICTED', 'NATO CONFIDENTIAL', 'NATO SECRET', 'COSMIC TOP SECRET'],
                    description: 'Clearance must be one of the allowed values and is required'
                },
                caveats: {
                    bsonType: 'array',
                    items: {
                        bsonType: 'string'
                    },
                    description: 'Caveats must be an array of strings'
                },
                coi: {
                    bsonType: 'array',
                    items: {
                        bsonType: 'string'
                    },
                    description: 'COI tags must be an array of strings'
                },
                lastLogin: {
                    bsonType: 'date',
                    description: 'Last login must be a date'
                },
                active: {
                    bsonType: 'bool',
                    description: 'Active must be a boolean'
                },
                roles: {
                    bsonType: 'array',
                    items: {
                        bsonType: 'string'
                    },
                    description: 'Roles must be an array of strings'
                }
            }
        }
    },
    validationLevel: 'strict',
    validationAction: 'error'
});

// Audit logs collection - stores system audit records
db.createCollection('audit_logs', {
    validator: {
        $jsonSchema: {
            bsonType: 'object',
            required: ['timestamp', 'userId', 'username', 'action', 'success'],
            properties: {
                timestamp: {
                    bsonType: 'date',
                    description: 'Timestamp must be a date and is required'
                },
                userId: {
                    bsonType: 'string',
                    description: 'User ID must be a string and is required'
                },
                username: {
                    bsonType: 'string',
                    description: 'Username must be a string and is required'
                },
                action: {
                    bsonType: 'string',
                    enum: ['DOCUMENT_VIEW', 'DOCUMENT_CREATE', 'DOCUMENT_UPDATE', 'DOCUMENT_DELETE',
                        'LOGIN', 'LOGOUT', 'ACCESS_DENIED', 'USER_CREATE', 'USER_UPDATE',
                        'USER_DELETE', 'SYSTEM_ERROR'],
                    description: 'Action must be one of the allowed values and is required'
                },
                resourceId: {
                    bsonType: 'string',
                    description: 'Resource ID must be a string'
                },
                resourceType: {
                    bsonType: 'string',
                    description: 'Resource type must be a string'
                },
                details: {
                    bsonType: 'object',
                    description: 'Details must be an object'
                },
                ipAddress: {
                    bsonType: 'string',
                    description: 'IP address must be a string'
                },
                userAgent: {
                    bsonType: 'string',
                    description: 'User agent must be a string'
                },
                success: {
                    bsonType: 'bool',
                    description: 'Success must be a boolean and is required'
                },
                errorMessage: {
                    bsonType: 'string',
                    description: 'Error message must be a string'
                }
            }
        }
    },
    validationLevel: 'strict',
    validationAction: 'error'
});

// System settings collection - stores configuration settings
db.createCollection('system_settings', {
    validator: {
        $jsonSchema: {
            bsonType: 'object',
            required: ['key', 'value', 'updatedAt'],
            properties: {
                key: {
                    bsonType: 'string',
                    description: 'Key must be a string and is required'
                },
                value: {
                    description: 'Value can be of any type and is required'
                },
                description: {
                    bsonType: 'string',
                    description: 'Description must be a string'
                },
                updatedAt: {
                    bsonType: 'date',
                    description: 'Updated at must be a date and is required'
                },
                updatedBy: {
                    bsonType: 'string',
                    description: 'Updated by must be a string'
                }
            }
        }
    },
    validationLevel: 'strict',
    validationAction: 'error'
});

// Create indexes for optimal performance

// Indexes for documents collection
db.documents.createIndex({ "filename": 1 });
db.documents.createIndex({ "uploadDate": -1 });
db.documents.createIndex({ "metadata.classification": 1 });
db.documents.createIndex({ "metadata.releasability": 1 });
db.documents.createIndex({ "metadata.coi": 1 });
db.documents.createIndex({ "metadata.creator.country": 1 });
db.documents.createIndex({ "metadata.creator.id": 1 });
db.documents.createIndex(
    {
        "filename": "text",
        "metadata.classification": "text",
        "metadata.releasability": "text",
        "metadata.coi": "text"
    },
    {
        name: "documentSearchIndex",
        weights: {
            "filename": 10,
            "metadata.classification": 5,
            "metadata.releasability": 3,
            "metadata.coi": 2
        }
    }
);

// Indexes for users collection
db.users.createIndex({ "uniqueId": 1 }, { unique: true });
db.users.createIndex({ "username": 1 }, { unique: true });
db.users.createIndex({ "email": 1 });
db.users.createIndex({ "countryOfAffiliation": 1 });
db.users.createIndex({ "clearance": 1 });
db.users.createIndex({ "coi": 1 });
db.users.createIndex({ "roles": 1 });

// Indexes for audit_logs collection
db.audit_logs.createIndex({ "timestamp": -1 });
db.audit_logs.createIndex({ "userId": 1 });
db.audit_logs.createIndex({ "action": 1 });
db.audit_logs.createIndex({ "resourceId": 1 });
db.audit_logs.createIndex({ "success": 1 });
// TTL index to automatically delete old audit logs after retention period (e.g., 1 year)
db.audit_logs.createIndex({ "timestamp": 1 }, { expireAfterSeconds: 31536000 });

// Indexes for system_settings collection
db.system_settings.createIndex({ "key": 1 }, { unique: true });

// Insert default system settings
db.system_settings.insertMany([
    {
        key: "auditLogRetentionDays",
        value: 365,
        description: "Number of days to retain audit logs",
        updatedAt: new Date(),
        updatedBy: "system"
    },
    {
        key: "allowedClassifications",
        value: ["UNCLASSIFIED", "RESTRICTED", "NATO CONFIDENTIAL", "NATO SECRET", "COSMIC TOP SECRET"],
        description: "Allowed classification levels",
        updatedAt: new Date(),
        updatedBy: "system"
    },
    {
        key: "allowedCaveats",
        value: ["FVEY", "NATO", "EU", "NOFORN", "ORCON", "PROPIN", "REL"],
        description: "Allowed caveats",
        updatedAt: new Date(),
        updatedBy: "system"
    },
    {
        key: "allowedCOIs",
        value: ["OpAlpha", "OpBravo", "OpGamma", "MissionX", "MissionZ"],
        description: "Allowed Communities of Interest",
        updatedAt: new Date(),
        updatedBy: "system"
    },
    {
        key: "allowedCountries",
        value: [
            "AUS", "CAN", "NZL", "GBR", "USA",  // FVEY
            "ALB", "BEL", "BGR", "HRV", "CZE", "DNK", "EST", "FIN", "FRA", "DEU",
            "GRC", "HUN", "ISL", "ITA", "LVA", "LTU", "LUX", "MNE", "NLD", "MKD",
            "NOR", "POL", "PRT", "ROU", "SVK", "SVN", "ESP", "SWE", "TUR"  // NATO
        ],
        description: "Allowed countries",
        updatedAt: new Date(),
        updatedBy: "system"
    }
]);

// Insert sample users (for development only)
if (process.env.NODE_ENV !== "production") {
    db.users.insertMany([
        {
            uniqueId: "alice123",
            username: "alice",
            email: "alice@us.gov",
            givenName: "Alice",
            surname: "Johnson",
            organization: "Department of Defense",
            countryOfAffiliation: "USA",
            clearance: "COSMIC TOP SECRET",
            caveats: ["FVEY", "NATO"],
            coi: ["OpAlpha", "OpBravo"],
            lastLogin: new Date(),
            active: true,
            roles: ["user", "admin"],
            createdAt: new Date(),
            updatedAt: new Date()
        },
        {
            uniqueId: "bob456",
            username: "bob",
            email: "bob@mod.uk",
            givenName: "Bob",
            surname: "Smith",
            organization: "Ministry of Defence",
            countryOfAffiliation: "GBR",
            clearance: "NATO SECRET",
            caveats: ["FVEY"],
            coi: ["OpAlpha"],
            lastLogin: new Date(),
            active: true,
            roles: ["user"],
            createdAt: new Date(),
            updatedAt: new Date()
        },
        {
            uniqueId: "charlie789",
            username: "charlie",
            email: "charlie@forces.gc.ca",
            givenName: "Charlie",
            surname: "Brown",
            organization: "Canadian Armed Forces",
            countryOfAffiliation: "CAN",
            clearance: "NATO SECRET",
            caveats: ["FVEY", "NATO"],
            coi: ["OpBravo", "MissionZ"],
            lastLogin: new Date(),
            active: true,
            roles: ["user"],
            createdAt: new Date(),
            updatedAt: new Date()
        }
    ]);
}

print("MongoDB initialization completed successfully!");