const swaggerJsdoc = require('swagger-jsdoc');
const swaggerUi = require('swagger-ui-express');
const path = require('path');
const config = require('./config');

const options = {
    definition: {
        openapi: '3.0.0',
        info: {
            title: 'DIVE25 API Documentation',
            version: '1.0.0',
            description: 'API documentation for the DIVE25 Document Access System',
            contact: {
                name: 'DIVE25 Support',
                email: 'support@dive25.com',
            },
        },
        servers: [
            {
                url: `${config.env === 'production' ? 'https://api.dive25.com' : 'https://api.dive25.local'}/api/v1`,
                description: `${config.env === 'production' ? 'Production' : 'Development'} server`,
            },
        ],
        components: {
            securitySchemes: {
                bearerAuth: {
                    type: 'http',
                    scheme: 'bearer',
                    bearerFormat: 'JWT',
                },
            },
        },
        security: [
            {
                bearerAuth: [],
            },
        ],
    },
    apis: [
        path.join(__dirname, './routes/*.js'),
        path.join(__dirname, './models/*.js'),
    ],
};

const specs = swaggerJsdoc(options);

module.exports = {
    serve: (app) => {
        app.use('/api/v1/docs', swaggerUi.serve, swaggerUi.setup(specs));
    },
    specs,
};