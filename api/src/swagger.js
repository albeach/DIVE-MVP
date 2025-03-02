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
                url: `http://localhost:3000/api/v1`,
                description: 'Local Development server (http)',
            },
            {
                url: `https://localhost:3000/api/v1`,
                description: 'Local Development server (https)',
            },
            {
                url: `http://api.dive25.local/api/v1`,
                description: 'Development server (http)',
            },
            {
                url: `https://api.dive25.local/api/v1`,
                description: 'Development server (https)',
            },
            {
                url: `https://api.dive25.com/api/v1`,
                description: 'Production server',
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
            schemas: {
                Error: {
                    type: 'object',
                    properties: {
                        message: {
                            type: 'string'
                        },
                        code: {
                            type: 'string'
                        }
                    }
                },
                GenericResponse: {
                    type: 'object',
                    properties: {
                        success: {
                            type: 'boolean'
                        },
                        message: {
                            type: 'string'
                        }
                    }
                }
            }
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
        // First, serve the OpenAPI spec
        app.get('/api/v1/docs/swagger.json', (req, res) => {
            res.setHeader('Content-Type', 'application/json');
            res.send(specs);
        });

        // Then, serve Swagger UI
        app.use('/api/v1/docs', swaggerUi.serve, swaggerUi.setup(specs, {
            explorer: true,
            swaggerOptions: {
                persistAuthorization: true,
                filter: true,
                displayRequestDuration: true
            }
        }));
    },
    specs,
};