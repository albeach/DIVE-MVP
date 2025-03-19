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
    size: {
        type: Number,
        get: v => Math.floor(v),
        set: v => Math.floor(v)
    },
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

// Convert size to integer before saving
DocumentSchema.pre('save', function (next) {
    if (this.size) {
        this.size = Math.floor(this.size);
    }
    next();
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
            fileSize = Math.floor(Buffer.byteLength(content, 'utf8')); // Use Buffer.byteLength for accurate byte count
            break;

        case 'pdf':
        case 'docx':
        case 'xlsx':
        case 'pptx':
            // For non-text files, create a placeholder file with random size
            const size = Math.floor(Math.random() * 500000) + 10000; // 10KB to 500KB, as integer
            const buffer = Buffer.alloc(size);
            fs.writeFileSync(filePath, buffer);
            fileSize = size;
            break;
    }

    return {
        fileId,
        filePath,
        fileName,
        mimeType: fileType.mimeType,
        size: Math.floor(fileSize) // Ensure integer
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

    // Random dates - ensure they are proper MongoDB dates
    const now = new Date();
    const uploadDate = new Date(randomDate(new Date(2023, 0, 1), now));
    const lastModifiedDate = new Date(randomDate(uploadDate, now));
    // Always set lastAccessedDate to a date, but make it more recent than upload date
    const lastAccessedDate = new Date(randomDate(uploadDate, now));

    // Classification with bias towards lower classifications
    const classificationIndex = Math.floor(Math.random() * Math.random() * CONFIG.classificationLevels.length);
    const classification = CONFIG.classificationLevels[classificationIndex];

    // More caveats for higher classifications
    const maxCaveats = classificationIndex + 1;

    // Generate document object
    const doc = {
        filename: fileInfo.fileName,
        fileId: fileInfo.fileId,
        mimeType: fileInfo.mimeType,
        size: Math.floor(fileInfo.size), // MongoDB will convert to BSON int
        metadata: {
            classification,
            releasability: getRandomItems(CONFIG.releasabilityOptions, 1, 5), // At least 1 releasability
            caveats: getRandomItems(CONFIG.caveatOptions, 0, maxCaveats),
            coi: getRandomItems(CONFIG.coiOptions, 1, 3), // At least 1 COI
            policyIdentifier: 'NATO',
            creator: {
                id: user.id,
                name: `${user.firstName} ${user.lastName}`,
                organization: CONFIG.organizations[Math.floor(Math.random() * CONFIG.organizations.length)],
                country: CONFIG.countries[Math.floor(Math.random() * CONFIG.countries.length)]
            }
        },
        uploadDate: uploadDate,
        lastAccessedDate: lastAccessedDate,
        lastModifiedDate: lastModifiedDate
    };

    // Create and return the document
    return new Document(doc);
}

// Function to generate summary statistics
async function generateSummary(documents) {
    const summary = {
        totalDocuments: documents.length,
        classifications: {},
        caveats: {},
        coi: {},
        releasability: {},
        organizations: {},
        countries: {},
        fileTypes: {},
        totalSize: 0
    };

    documents.forEach(doc => {
        // Count classifications
        const classification = doc.metadata.classification;
        summary.classifications[classification] = (summary.classifications[classification] || 0) + 1;

        // Count caveats
        doc.metadata.caveats.forEach(caveat => {
            summary.caveats[caveat] = (summary.caveats[caveat] || 0) + 1;
        });

        // Count COIs
        doc.metadata.coi.forEach(coi => {
            summary.coi[coi] = (summary.coi[coi] || 0) + 1;
        });

        // Count releasability
        doc.metadata.releasability.forEach(rel => {
            summary.releasability[rel] = (summary.releasability[rel] || 0) + 1;
        });

        // Count organizations
        const org = doc.metadata.creator.organization;
        summary.organizations[org] = (summary.organizations[org] || 0) + 1;

        // Count countries
        const country = doc.metadata.creator.country;
        summary.countries[country] = (summary.countries[country] || 0) + 1;

        // Count file types
        const fileType = doc.filename.split('.').pop();
        summary.fileTypes[fileType] = (summary.fileTypes[fileType] || 0) + 1;

        // Sum total size
        summary.totalSize += doc.size;
    });

    // Format the summary output
    console.log('\nDocument Generation Summary:');
    console.log('==========================');
    console.log(`Total Documents Generated: ${summary.totalDocuments}`);
    console.log(`Total Size: ${(summary.totalSize / 1024 / 1024).toFixed(2)} MB\n`);

    console.log('Classifications:');
    Object.entries(summary.classifications)
        .sort((a, b) => b[1] - a[1])
        .forEach(([classification, count]) => {
            console.log(`  ${classification}: ${count} (${((count / summary.totalDocuments) * 100).toFixed(1)}%)`);
        });

    console.log('\nCaveats:');
    Object.entries(summary.caveats)
        .sort((a, b) => b[1] - a[1])
        .forEach(([caveat, count]) => {
            console.log(`  ${caveat}: ${count}`);
        });

    console.log('\nCommunities of Interest:');
    Object.entries(summary.coi)
        .sort((a, b) => b[1] - a[1])
        .forEach(([coi, count]) => {
            console.log(`  ${coi}: ${count}`);
        });

    console.log('\nReleasability:');
    Object.entries(summary.releasability)
        .sort((a, b) => b[1] - a[1])
        .forEach(([rel, count]) => {
            console.log(`  ${rel}: ${count}`);
        });

    console.log('\nFile Types:');
    Object.entries(summary.fileTypes)
        .sort((a, b) => b[1] - a[1])
        .forEach(([type, count]) => {
            console.log(`  ${type}: ${count} (${((count / summary.totalDocuments) * 100).toFixed(1)}%)`);
        });

    console.log('\nTop Organizations:');
    Object.entries(summary.organizations)
        .sort((a, b) => b[1] - a[1])
        .slice(0, 5)
        .forEach(([org, count]) => {
            console.log(`  ${org}: ${count}`);
        });

    console.log('\nTop Contributing Countries:');
    Object.entries(summary.countries)
        .sort((a, b) => b[1] - a[1])
        .slice(0, 5)
        .forEach(([country, count]) => {
            console.log(`  ${country}: ${count}`);
        });

    return summary;
}

/**
 * Main execution
 */
async function main() {
    const count = process.argv[2] ? parseInt(process.argv[2]) : CONFIG.documentCount;
    console.log(`Generating ${count} documents...`);

    try {
        // Connect to MongoDB
        console.log('Connecting to MongoDB...');
        await mongoose.connect(CONFIG.mongoUri, {
            useNewUrlParser: true,
            useUnifiedTopology: true
        });

        console.log(`Generating ${count} documents...`);
        const documents = [];

        // Generate documents
        for (let i = 0; i < count; i++) {
            try {
                const doc = await generateDocument();
                const validationError = doc.validateSync();
                if (validationError) {
                    console.error('Mongoose validation error:', validationError);
                    continue;
                }

                // Log the document before saving
                console.log('Attempting to save document:', JSON.stringify(doc.toObject(), null, 2));

                await doc.save();
                documents.push(doc);

                // Progress indicator
                const progress = ((i + 1) / count * 100).toFixed(1);
                console.log(`Progress: ${progress}% complete`);
            } catch (err) {
                console.error('Error generating document:', err);
                if (err.errInfo) {
                    console.error('Validation error details:', JSON.stringify(err.errInfo, null, 2));
                }
                throw err; // Re-throw to stop the process
            }
        }

        console.log(`Successfully generated ${documents.length} documents`);

        // Generate and display summary
        const summary = await generateSummary(documents);
        console.log('\nDocument Generation Summary:');
        console.log(JSON.stringify(summary, null, 2));

    } catch (err) {
        console.error('Error generating documents:', err);
        if (err.errInfo) {
            console.error('Validation error details:', JSON.stringify(err.errInfo, null, 2));
        }
    } finally {
        await mongoose.connection.close();
        console.log('Done!');
    }
}

// Main execution
main();