# DIVE25 Document Generator

This tool generates sample documents with realistic metadata for the DIVE25 system.

## Features

- Generates a configurable number of sample documents (default: 300)
- Creates documents with various file types (PDF, DOCX, XLSX, PPTX, TXT)
- Applies realistic metadata including:
  - Classification levels
  - Releasability markings
  - Security caveats
  - Communities of interest
  - Creator information

## Prerequisites

- Node.js (v14+)
- Access to a running MongoDB instance
- A DIVE25 application environment

## Installation

1. Navigate to the scripts directory:

```sh
cd scripts
```

2. Install dependencies:

```sh
npm install
```

## Usage

### Inside Docker Environment

Run the script directly from the api container:

```sh
docker-compose exec api node /app/scripts/generate-sample-documents.js
```

### Local Development Environment

1. Run the script directly:

```sh
npm run generate
```

2. Or run it with custom environment variables:

```sh
MONGODB_AUTH_URL="mongodb://username:password@localhost:27017/dive25" STORAGE_PATH="/path/to/storage" npm run generate
```

## Configuration

You can modify the script's behavior by editing the CONFIG object at the top of the generate-sample-documents.js file:

- `documentCount`: Number of documents to generate
- `mongoUri`: MongoDB connection string
- `storagePath`: Path to store document files
- `fileTypes`: Types of files to generate
- `classificationLevels`: Available classification levels
- `releasabilityOptions`: Available releasability markings
- `caveatOptions`: Available security caveats
- `coiOptions`: Available communities of interest
- `organizations`: Sample organizations
- `countries`: Sample countries
- `sampleUsers`: User information for document creators

## Cleanup

If you need to remove all generated documents:

```js
// In MongoDB shell
use dive25
db.documents.deleteMany({ filename: { $regex: /^sample-/ } })
```

## Notes

- The script creates both database entries and actual files in the storage directory
- Files are placeholder files with random data, not actual documents
- The distribution of classification levels is skewed towards lower classifications to be more realistic 