/**
 * MongoDB seed script to create test documents for multiple test users
 *
 * This script ensures users have documents with appropriate security attributes
 * to test access control in the UI. Run with:
 * 
 * docker exec dive25-staging-api node /app/scripts/seed-alice-documents.js
 */

const mongoose = require('mongoose');
const logger = console;

// Create a MongoDB connection
const createDbConnection = async () => {
    try {
        logger.info('Connecting to MongoDB...');
        const db = await mongoose.createConnection('mongodb://dive25_app:app_password@mongodb:27017/dive25');
        logger.info('MongoDB connected successfully');
        return db;
    } catch (err) {
        logger.error('Error connecting to MongoDB:', err);
        throw err;
    }
};

// Test users configuration
const testUsers = [
    {
        id: 'alice123',
        name: 'Alice Johnson',
        organization: 'Department of Defense',
        country: 'USA',
        docs: {
            count: 20,
            classification: 'UNCLASSIFIED',
            releasability: ['USA'],
            caveats: ['FVEY', 'NATO'],
            coi: ['OpAlpha']
        }
    },
    {
        id: 'bob456',
        name: 'Bob Smith',
        organization: 'Department of Defense',
        country: 'USA',
        docs: {
            count: 15,
            classification: 'CONFIDENTIAL',
            releasability: ['USA', 'GBR'],
            caveats: ['FVEY'],
            coi: ['OpBravo']
        }
    },
    {
        id: 'charlie789',
        name: 'Charlie Williams',
        organization: 'Ministry of Defence',
        country: 'GBR',
        docs: {
            count: 10,
            classification: 'SECRET',
            releasability: ['GBR'],
            caveats: ['NATO'],
            coi: ['OpCharlie']
        }
    }
];

// Create test documents for all test users
const createTestDocuments = async (db) => {
    try {
        logger.info('Creating test documents for users...');

        for (const user of testUsers) {
            // Check if test documents already exist for this user
            const existingDocs = await db.collection('documents').countDocuments({
                'metadata.creator.id': user.id
            });

            logger.info(`Found ${existingDocs} existing documents for ${user.name}`);

            // Only create new documents if we don't have enough
            if (existingDocs < user.docs.count) {
                const docsToCreate = user.docs.count - existingDocs;
                logger.info(`Creating ${docsToCreate} new documents for ${user.name}`);

                const documents = [];
                for (let i = 1; i <= docsToCreate; i++) {
                    documents.push({
                        filename: `${user.name.toLowerCase().split(' ')[0]}-document-${i}.pdf`,
                        fileId: `${user.id}-${i}`,
                        mimeType: 'application/pdf',
                        size: 1024,
                        metadata: {
                            classification: user.docs.classification,
                            releasability: user.docs.releasability,
                            caveats: user.docs.caveats,
                            coi: user.docs.coi,
                            creator: {
                                id: user.id,
                                name: user.name,
                                organization: user.organization,
                                country: user.country
                            },
                            policyIdentifier: user.docs.caveats.includes('NATO') ? 'NATO' : 'DEFAULT'
                        },
                        uploadDate: new Date(),
                        lastModifiedDate: new Date()
                    });
                }

                if (documents.length > 0) {
                    const result = await db.collection('documents').insertMany(documents);
                    logger.info(`Created ${result.insertedCount} documents for ${user.name}`);
                }
            } else {
                logger.info(`Sufficient documents already exist for ${user.name}, skipping creation`);
            }
        }

        logger.info('Document creation completed successfully');
    } catch (err) {
        logger.error('Error creating documents:', err);
        throw err;
    }
};

// Main function
const main = async () => {
    let db;
    try {
        db = await createDbConnection();
        await createTestDocuments(db);
        logger.info('Seed script completed successfully');
    } catch (err) {
        logger.error('Seed script failed:', err);
        process.exit(1);
    } finally {
        if (db) {
            await db.close();
            logger.info('Database connection closed');
        }
        process.exit(0);
    }
};

// Run the main function
main(); 