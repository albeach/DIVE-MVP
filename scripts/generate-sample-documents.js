#!/usr/bin/env node

/**
 * Script to generate sample documents for the DIVE25 system
 * This creates synthetic documents with realistic metadata for testing purposes
 */

const mongoose = require('mongoose');
const fs = require('fs');
const path = require('path');
const { v4: uuidv4 } = require('uuid');
const { execSync } = require('child_process');
const faker = require('faker');
const dotenv = require('dotenv');

// Load environment variables
dotenv.config();

// Configuration
const CONFIG = {
    // How many documents to generate
    documentCount: process.env.DOCUMENT_COUNT ? parseInt(process.env.DOCUMENT_COUNT) : 300,

    // MongoDB connection
    mongoUri: process.env.MONGODB_AUTH_URL || 'mongodb://dive25_app:app_password@mongodb:27017/dive25',

    // Storage paths
    storagePath: process.env.STORAGE_PATH || path.join(__dirname, '../storage'),
    tempPath: path.join(__dirname, '../temp'),

    // Sample file types to generate
    fileTypes: [
        { ext: 'pdf', mimeType: 'application/pdf' },
        { ext: 'docx', mimeType: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document' },
        { ext: 'xlsx', mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' },
        { ext: 'pptx', mimeType: 'application/vnd.openxmlformats-officedocument.presentationml.presentation' },
        { ext: 'txt', mimeType: 'text/plain' },
    ],

    // Classification levels
    classificationLevels: [
        'UNCLASSIFIED',
        'RESTRICTED',
        'NATO CONFIDENTIAL',
        'NATO SECRET',
        'COSMIC TOP SECRET'
    ],

    // Sample releasability options
    releasabilityOptions: [
        'NATO', 'USA', 'GBR', 'FRA', 'DEU', 'ITA', 'CAN',
        'AUS', 'NZL', 'NLD', 'BEL', 'DNK', 'NOR', 'ESP', 'PRT'
    ],

    // Sample caveats
    caveatOptions: [
        'NOFORN', 'ORCON', 'REL TO', 'EYES ONLY', 'SPECIAL HANDLING REQUIRED',
        'PROPRIETARY', 'SCI', 'HCS', 'SPECIAL ACCESS REQUIRED'
    ],

    // Sample Communities of Interest (COI)
    coiOptions: [
        'CYBER', 'INTEL', 'OPERATIONS', 'LOGISTICS', 'MEDICAL',
        'PLANNING', 'TRAINING', 'STRATEGIC', 'TACTICAL', 'TECHNICAL'
    ],

    // Sample policy identifiers
    policyIdentifiers: ['NATO'],

    // Sample organizations
    organizations: [
        'NATO HQ', 'SHAPE', 'Pentagon', 'Ministry of Defense', 'Department of Defense',
        'Intelligence Agency', 'Joint Command', 'Strategic Command', 'Cyber Command'
    ],

    // Sample countries
    countries: [
        'USA', 'GBR', 'FRA', 'DEU', 'ITA', 'CAN', 'AUS', 'NZL', 'NLD',
        'BEL', 'DNK', 'NOR', 'ESP', 'PRT', 'POL', 'TUR', 'GRC'
    ],

    // Sample users for document creation
    sampleUsers: [
        { id: 'user-001', firstName: 'John', lastName: 'Smith', username: 'jsmith' },
        { id: 'user-002', firstName: 'Jane', lastName: 'Doe', username: 'jdoe' },
        { id: 'user-003', firstName: 'Robert', lastName: 'Johnson', username: 'rjohnson' },
        { id: 'user-004', firstName: 'Emily', lastName: 'Williams', username: 'ewilliams' },
        { id: 'user-005', firstName: 'Michael', lastName: 'Brown', username: 'mbrown' }
    ]
};

// Document Schema (simplified version for generation purposes)
const DocumentSchema = new mongoose.Schema({
    filename: String,
    fileId: String,
    mimeType: String,
    size: Number,
    metadata: {
        classification: String,
        releasability: [String],
        caveats: [String],
        coi: [String],
        policyIdentifier: String,
        creator: {
            id: String,
            name: String,
            organization: String,
            country: String
        }
    },
    uploadDate: Date,
    lastAccessedDate: Date,
    lastModifiedDate: Date
}, {
    timestamps: true,
    collection: 'documents'
});

const Document = mongoose.model('Document', DocumentSchema);

/**
 * Generate a random date between two dates
 */
function randomDate(start, end) {
    return new Date(start.getTime() + Math.random() * (end.getTime() - start.getTime()));
}

/**
 * Get random items from an array
 */
function getRandomItems(array, min = 0, max = 3) {
    const count = Math.floor(Math.random() * (max - min + 1)) + min;
    const shuffled = [...array].sort(() => 0.5 - Math.random());
    return shuffled.slice(0, count);
}

/**
 * Generate a random file
 */
async function generateRandomFile(fileType) {
    const tempDir = CONFIG.tempPath;

    // Create temp directory if it doesn't exist
    if (!fs.existsSync(tempDir)) {
        fs.mkdirSync(tempDir, { recursive: true });
    }

    const fileId = uuidv4();
    const fileName = `sample-${faker.lorem.slug(3)}.${fileType.ext}`;
    const filePath = path.join(tempDir, fileName);

    // Generate sample file content based on type
    let fileSize = 0;

    switch (fileType.ext) {
        case 'txt':
            const content = faker.lorem.paragraphs(10);
            fs.writeFileSync(filePath, content);
            fileSize = content.length;
            break;

        case 'pdf':
        case 'docx':
        case 'xlsx':
        case 'pptx':
            // For non-text files, create a placeholder file with random size
            const size = Math.floor(Math.random() * 500000) + 10000; // 10KB to 500KB
            const buffer = Buffer.alloc(size, 'x');
            fs.writeFileSync(filePath, buffer);
            fileSize = size;
            break;
    }

    return {
        fileId,
        filePath,
        fileName,
        mimeType: fileType.mimeType,
        size: fileSize
    };
}

/**
 * Store file in the document storage system
 */
async function storeFile(fileInfo) {
    // Create storage directory
    const storageDir = path.join(CONFIG.storagePath, fileInfo.fileId.substring(0, 2));

    if (!fs.existsSync(storageDir)) {
        fs.mkdirSync(storageDir, { recursive: true });
    }

    // Store file
    const destPath = path.join(storageDir, fileInfo.fileId);
    fs.copyFileSync(fileInfo.filePath, destPath);

    // Clean up temp file
    fs.unlinkSync(fileInfo.filePath);

    return fileInfo;
}

/**
 * Generate a random document
 */
async function generateDocument() {
    // Select random file type
    const fileType = CONFIG.fileTypes[Math.floor(Math.random() * CONFIG.fileTypes.length)];

    // Generate file
    const fileInfo = await generateRandomFile(fileType);

    // Store file
    await storeFile(fileInfo);

    // Random user
    const user = CONFIG.sampleUsers[Math.floor(Math.random() * CONFIG.sampleUsers.length)];

    // Random dates
    const uploadDate = randomDate(new Date(2023, 0, 1), new Date());
    const lastModifiedDate = randomDate(uploadDate, new Date());
    const lastAccessedDate = Math.random() > 0.3 ? randomDate(uploadDate, new Date()) : null;

    // Classification with bias towards lower classifications
    const classificationIndex = Math.floor(Math.random() * Math.random() * CONFIG.classificationLevels.length);
    const classification = CONFIG.classificationLevels[classificationIndex];

    // More caveats for higher classifications
    const maxCaveats = classificationIndex + 1;

    // Generate document object
    return new Document({
        filename: fileInfo.fileName,
        fileId: fileInfo.fileId,
        mimeType: fileInfo.mimeType,
        size: fileInfo.size,
        metadata: {
            classification,
            releasability: getRandomItems(CONFIG.releasabilityOptions, 0, 5),
            caveats: getRandomItems(CONFIG.caveatOptions, 0, maxCaveats),
            coi: getRandomItems(CONFIG.coiOptions, 0, 3),
            policyIdentifier: 'NATO',
            creator: {
                id: user.id,
                name: `${user.firstName} ${user.lastName}`,
                organization: CONFIG.organizations[Math.floor(Math.random() * CONFIG.organizations.length)],
                country: CONFIG.countries[Math.floor(Math.random() * CONFIG.countries.length)]
            }
        },
        uploadDate,
        lastModifiedDate,
        lastAccessedDate
    });
}

/**
 * Main function to generate documents
 */
async function generateDocuments() {
    try {
        console.log(`Connecting to MongoDB at ${CONFIG.mongoUri}...`);
        await mongoose.connect(CONFIG.mongoUri, {
            useNewUrlParser: true,
            useUnifiedTopology: true
        });

        console.log('Connected to MongoDB');

        console.log(`Generating ${CONFIG.documentCount} sample documents...`);

        // Create temporary directory
        if (!fs.existsSync(CONFIG.tempPath)) {
            fs.mkdirSync(CONFIG.tempPath, { recursive: true });
        }

        // Generate and save documents one by one
        let successCount = 0;
        let failureCount = 0;

        for (let i = 0; i < CONFIG.documentCount; i++) {
            try {
                const doc = await generateDocument();
                await doc.save(); // Save one by one instead of bulk insert
                successCount++;

                if ((i + 1) % 10 === 0 || i === CONFIG.documentCount - 1) {
                    console.log(`Generated ${i + 1}/${CONFIG.documentCount} documents (Success: ${successCount}, Failed: ${failureCount})`);
                }
            } catch (error) {
                failureCount++;
                console.error(`Error saving document ${i + 1}:`, error.message);
                // Continue generating the next document
            }
        }

        console.log(`Document generation completed. Successfully saved ${successCount} documents to the database.`);

        // Clean up
        try {
            if (fs.existsSync(CONFIG.tempPath)) {
                // Use fs.rm with recursive option instead of rmdirSync
                fs.rmSync(CONFIG.tempPath, { recursive: true, force: true });
            }
        } catch (cleanupError) {
            console.warn('Warning: Could not clean up temp directory:', cleanupError.message);
        }

    } catch (error) {
        console.error('Error generating documents:', error);
    } finally {
        await mongoose.connection.close();
        console.log('Database connection closed');
    }
}

// Run the script
generateDocuments().catch(console.error); 