const express = require('express');
const {
    getById,
    getByUniqueId,
    getAll,
    create,
    update,
    remove
} = require('../controllers/users.controller');
const { authenticate, authorize } = require('../middleware/auth.middleware');

const router = express.Router();

// Apply authentication middleware to all routes
router.use(authenticate);

// User routes
router.get('/', authorize(['admin']), getAll);
router.post('/', authorize(['admin']), create);
router.get('/me', (req, res) => res.status(200).json({ success: true, user: req.user }));
router.get('/:id', authorize(['admin']), getById);
router.get('/uniqueId/:uniqueId', authorize(['admin']), getByUniqueId);
router.put('/:id', update); // Users can update their own profile, authorization is checked in the service
router.delete('/:id', authorize(['admin']), remove);

module.exports = router;
