const express = require('express');
const { getAll } = require('../controllers/audit.controller');
const { authenticate, authorize } = require('../middleware/auth.middleware');

const router = express.Router();

// Apply authentication and authorization middleware to all routes
router.use(authenticate);
router.use(authorize(['admin']));

// Audit routes
router.get('/', getAll);

module.exports = router;
