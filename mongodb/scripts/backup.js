// mongodb/scripts/backup.js
/**
 * MongoDB Backup Script for DIVE25
 * 
 * This script performs a full backup of the MongoDB database.
 * Run with: mongosh --file backup.js
 */

// Configuration
const backupDir = 'backup';
const databases = ['dive25'];
const timestamp = new Date().toISOString().replace(/[:.]/g, '-');

// Print startup message
print(`Starting MongoDB backup at ${new Date().toISOString()}`);

// Create backup directory if it doesn't exist
try {
    if (!fs.existsSync(backupDir)) {
        fs.mkdir(backupDir);
        print(`Created backup directory: ${backupDir}`);
    }
} catch (err) {
    print(`Error creating backup directory: ${err.message}`);
    quit(1);
}

// Backup each database
databases.forEach(dbName => {
    const backupFilename = `${backupDir}/${dbName}_${timestamp}.json`;

    try {
        // Connect to the database
        const db = db.getSiblingDB(dbName);

        // Get all collections
        const collections = db.getCollectionNames();

        const backup = {};

        // Export each collection
        collections.forEach(collectionName => {
            print(`Backing up collection: ${collectionName}`);

            backup[collectionName] = db.getCollection(collectionName).find().toArray();
        });

        // Write backup to file
        fs.writeFileSync(backupFilename, JSON.stringify(backup, null, 2));

        print(`Backup of ${dbName} completed successfully to ${backupFilename}`);
    } catch (err) {
        print(`Error backing up ${dbName}: ${err.message}`);
    }
});

print(`MongoDB backup completed at ${new Date().toISOString()}`);