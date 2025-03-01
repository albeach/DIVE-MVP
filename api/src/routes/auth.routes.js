const express = require('express');
const { verifyUser, logout } = require('../controllers/auth.controller');
const { authenticate } = require('../middleware/auth.middleware');

const router = express.Router();

// Authentication routes
router.get('/verify', authenticate, verifyUser);
router.post('/logout', authenticate, logout);

module.exports = router;
