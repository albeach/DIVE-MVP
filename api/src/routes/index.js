const express = require('express');
const authRoutes = require('./auth.routes');
const documentsRoutes = require('./documents.routes');
const usersRoutes = require('./users.routes');
const auditRoutes = require('./audit.routes');

const router = express.Router();

// Apply routes
router.use('/auth', authRoutes);
router.use('/documents', documentsRoutes);
router.use('/users', usersRoutes);
router.use('/audit', auditRoutes);

module.exports = router;
