const mongoose = require('mongoose');
const Joi = require('joi');

// Define clearance levels based on NATO standards
const clearanceLevels = [
    'UNCLASSIFIED',
    'RESTRICTED',
    'CONFIDENTIAL',
    'SECRET',
    'TOP SECRET'
];

// Define the schema for user information
const UserSchema = new mongoose.Schema({
    uniqueId: {
        type: String,
        required: true,
        unique: true
    },
    username: {
        type: String,
        required: true,
        unique: true
    },
    email: {
        type: String,
        required: true,
        lowercase: true,
        trim: true
    },
    givenName: {
        type: String,
        required: true
    },
    surname: {
        type: String,
        required: true
    },
    organization: {
        type: String,
        required: true
    },
    countryOfAffiliation: {
        type: String,
        required: true
    },
    clearance: {
        type: String,
        required: true,
        enum: clearanceLevels
    },
    caveats: {
        type: [String],
        default: []
    },
    coi: {
        type: [String],
        default: []
    },
    lastLogin: {
        type: Date
    },
    active: {
        type: Boolean,
        default: true
    },
    roles: {
        type: [String],
        default: ['user']
    },
    avatar: {
        type: String,
        default: null
    }
}, {
    timestamps: true,
    collection: 'users'
});

// Create indexes for frequently queried fields
UserSchema.index({ uniqueId: 1 }, { unique: true });
UserSchema.index({ username: 1 }, { unique: true });
UserSchema.index({ email: 1 });
UserSchema.index({ clearance: 1 });
UserSchema.index({ countryOfAffiliation: 1 });
UserSchema.index({ coi: 1 });

// Mongoose Model
const User = mongoose.model('User', UserSchema);

// Validation schema for create/update operations
const userValidationSchema = Joi.object({
    uniqueId: Joi.string().required(),
    username: Joi.string().required(),
    email: Joi.string().email().required(),
    givenName: Joi.string().required(),
    surname: Joi.string().required(),
    organization: Joi.string().required(),
    countryOfAffiliation: Joi.string().required(),
    clearance: Joi.string().valid(...clearanceLevels).required(),
    caveats: Joi.array().items(Joi.string()),
    coi: Joi.array().items(Joi.string()),
    roles: Joi.array().items(Joi.string())
});

module.exports = {
    User,
    userValidationSchema,
    clearanceLevels
};
