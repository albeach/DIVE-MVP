const mongoose = require('mongoose');
const Joi = require('joi');

// Define the classification levels based on NATO standards
const classificationLevels = [
    'UNCLASSIFIED',
    'RESTRICTED',
    'NATO CONFIDENTIAL',
    'NATO SECRET',
    'COSMIC TOP SECRET'
];

// Define the schema for document metadata
const DocumentSchema = new mongoose.Schema({
    filename: {
        type: String,
        required: true,
        trim: true
    },
    fileId: {
        type: String,
        required: true
    },
    mimeType: {
        type: String,
        required: true
    },
    size: {
        type: Number,
        required: true,
        min: 0
    },
    metadata: {
        classification: {
            type: String,
            required: true,
            enum: classificationLevels
        },
        releasability: {
            type: [String],
            default: []
        },
        caveats: {
            type: [String],
            default: []
        },
        coi: {
            type: [String],
            default: []
        },
        policyIdentifier: {
            type: String,
            required: true,
            default: 'NATO'
        },
        creator: {
            id: {
                type: String,
                required: true
            },
            name: {
                type: String,
                required: true
            },
            organization: {
                type: String,
                required: true
            },
            country: {
                type: String,
                required: true
            }
        }
    },
    uploadDate: {
        type: Date,
        default: Date.now
    },
    lastAccessedDate: {
        type: Date
    },
    lastModifiedDate: {
        type: Date,
        default: Date.now
    }
}, {
    timestamps: true,
    collection: 'documents'
});

// Create indexes for frequently queried fields
DocumentSchema.index({ 'metadata.classification': 1 });
DocumentSchema.index({ 'metadata.releasability': 1 });
DocumentSchema.index({ 'metadata.coi': 1 });
DocumentSchema.index({ 'metadata.creator.country': 1 });
DocumentSchema.index({ uploadDate: -1 });

// Mongoose Model
const Document = mongoose.model('Document', DocumentSchema);

// Validation schema for create/update operations
const documentValidationSchema = Joi.object({
    filename: Joi.string().required(),
    fileId: Joi.string().required(),
    mimeType: Joi.string().required(),
    size: Joi.number().min(0).required(),
    metadata: Joi.object({
        classification: Joi.string().valid(...classificationLevels).required(),
        releasability: Joi.array().items(Joi.string()),
        caveats: Joi.array().items(Joi.string()),
        coi: Joi.array().items(Joi.string()),
        policyIdentifier: Joi.string().default('NATO'),
        creator: Joi.object({
            id: Joi.string().required(),
            name: Joi.string().required(),
            organization: Joi.string().required(),
            country: Joi.string().required()
        }).required()
    }).required()
});

module.exports = {
    Document,
    documentValidationSchema,
    classificationLevels
};
