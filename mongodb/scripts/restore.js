// mongodb/scripts/restore.js
/**
 * MongoDB Restore Script for DIVE25
 * 
 * This script restores a MongoDB backup.
 * Run with: mongosh --file restore.js -- backup_file.json
 */

// Get backup file from command line arguments
const args = argumentsFromShell();
if (args.length < 1) {
    print("Error: Please provide a backup file to restore");
    print("Usage: mongosh --file restore.js -- backup_file.json");
    quit(1);
}

const backupFile = args[0];

// Print startup message
print(`Starting MongoDB restore from ${backupFile} at ${new Date().toISOString()}`);

try {
    // Read backup file
    const backupData = JSON.parse(fs.readFileSync(backupFile));

    // Extract database name from filename
    const dbNameMatch = backupFile.match(/([^\/]+)_\d{4}-\d{2}-\d{2}T/);
    if (!dbNameMatch) {
        print("Error: Could not determine database name from filename");
        quit(1);
    }

    const dbName = dbNameMatch[1];
    const db = db.getSiblingDB(dbName);

    // Restore each collection
    for (const collectionName in backupData) {
        print(`Restoring collection: ${collectionName}`);

        // Drop existing collection if it exists
        db[collectionName].drop();

        // Insert data
        if (backupData[collectionName].length > 0) {
            db[collectionName].insertMany(backupData[collectionName]);
        }

        print(`Restored ${backupData[collectionName].length} documents to ${collectionName}`);
    }

    print(`MongoDB restore completed at ${new Date().toISOString()}`);
} catch (err) {
    print(`Error restoring backup: ${err.message}`);
    quit(1);
}