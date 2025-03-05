const express = require('express');
const router = express.Router();
const { checkHealth, checkLiveness } = require('../utils/healthcheck');

/**
 * @swagger
 * /health:
 *   get:
 *     summary: Get application health status
 *     description: Returns health status of all application components
 *     tags: [Health]
 *     responses:
 *       200:
 *         description: Health check successful
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 status:
 *                   type: string
 *                   example: ok
 *                 timestamp:
 *                   type: string
 *                   example: 2023-01-01T00:00:00.000Z
 *                 checks:
 *                   type: object
 */
router.get('/', async (req, res) => {
    try {
        const health = await checkHealth();
        const statusCode = health.status === 'ok' ? 200 : 503;
        res.status(statusCode).json(health);
    } catch (error) {
        res.status(500).json({
            status: 'error',
            timestamp: new Date().toISOString(),
            message: error.message
        });
    }
});

/**
 * @swagger
 * /health/liveness:
 *   get:
 *     summary: Simple liveness check
 *     description: Returns a simple status to indicate the application is running
 *     tags: [Health]
 *     responses:
 *       200:
 *         description: Application is running
 */
router.get('/liveness', (req, res) => {
    const liveness = checkLiveness();
    res.status(200).json(liveness);
});

module.exports = router; 