const express = require('express');
const multer = require('multer');
const {
    create,
    getById,
    getAll,
    update,
    remove,
    download,
    preview
} = require('../controllers/documents.controller');
const { authenticate, authorize } = require('../middleware/auth.middleware');

// Configure multer for file uploads
const upload = multer({
    storage: multer.memoryStorage(),
    limits: {
        fileSize: 10 * 1024 * 1024 // 10MB
    }
});

const router = express.Router();

// Apply authentication middleware to all routes
router.use(authenticate);

// Document routes
router.post('/', upload.single('file'), create);
router.get('/', getAll);
router.get('/:id', getById);
router.get('/:id/download', download);
router.get('/:id/preview', preview);
router.put('/:id', update);
router.delete('/:id', remove);

module.exports = router;
