const mongoose = require('mongoose');

// Define the action types for audit logs
const actionTypes = [
    'DOCUMENT_VIEW',
    'DOCUMENT_CREATE',
    'DOCUMENT_UPDATE',
    'DOCUMENT_DELETE',
    'LOGIN',
    'LOGOUT',
    'ACCESS_DENIED',
    'USER_CREATE',
    'USER_UPDATE',
    'USER_DELETE',
    'SYSTEM_ERROR'
];

// Define the schema for audit logs
const AuditSchema = new mongoose.Schema({
    timestamp: {
        type: Date,
        default: Date.now,
        required: true
    },
    userId: {
        type: String,
        required: true
    },
    username: {
        type: String,
        required: true
    },
    action: {
        type: String,
        required: true,
        enum: actionTypes
    },
    resourceId: {
        type: String
    },
    resourceType: {
        type: String
    },
    details: {
        type: mongoose.Schema.Types.Mixed
    },
    ipAddress: {
        type: String
    },
    userAgent: {
        type: String
    },
    success: {
        type: Boolean,
        required: true
    },
    errorMessage: {
        type: String
    }
}, {
    timestamps: true,
    collection: 'audit_logs'
});

// Create indexes for frequently queried fields
AuditSchema.index({ timestamp: -1 });
AuditSchema.index({ userId: 1 });
AuditSchema.index({ action: 1 });
AuditSchema.index({ resourceId: 1 });
AuditSchema.index({ success: 1 });

// TTL index to automatically delete old audit logs after retention period (e.g., 1 year)
AuditSchema.index({ timestamp: 1 }, { expireAfterSeconds: 31536000 });

// Mongoose Model
const Audit = mongoose.model('Audit', AuditSchema);

module.exports = {
    Audit,
    actionTypes
};
