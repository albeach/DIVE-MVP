// mongodb/scripts/clean-audit-logs.js
/**
 * Cleanup Script for DIVE25 Audit Logs
 * 
 * This script cleans up old audit logs based on the retention policy.
 * Run with: mongosh --file clean-audit-logs.js
 */

// Connect to dive25 database
const db = db.getSiblingDB('dive25');

// Print startup message
print(`Starting audit log cleanup at ${new Date().toISOString()}`);

try {
    // Get retention policy from system settings
    const retentionSetting = db.system_settings.findOne({ key: "auditLogRetentionDays" });

    if (!retentionSetting) {
        print("Error: Audit log retention setting not found");
        quit(1);
    }

    const retentionDays = retentionSetting.value;

    // Calculate cutoff date
    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - retentionDays);

    print(`Deleting audit logs older than ${cutoffDate.toISOString()} (${retentionDays} days retention)`);

    // Delete old audit logs
    const result = db.audit_logs.deleteMany({ timestamp: { $lt: cutoffDate } });

    print(`Deleted ${result.deletedCount} audit log entries`);

    // Update TTL index if needed
    db.audit_logs.dropIndex({ "timestamp": 1 });
    db.audit_logs.createIndex(
        { "timestamp": 1 },
        { expireAfterSeconds: retentionDays * 24 * 60 * 60 }
    );

    print("Updated TTL index for audit logs");

    print(`Audit log cleanup completed at ${new Date().toISOString()}`);
} catch (err) {
    print(`Error cleaning audit logs: ${err.message}`);
    quit(1);
}