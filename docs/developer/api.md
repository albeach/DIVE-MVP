# API Development Guide

This guide provides comprehensive information for developers working with or extending the DIVE25 Document Access System APIs. It covers API design principles, implementation guidelines, authentication, error handling, and versioning.

## API Design Principles

The DIVE25 system follows these core API design principles:

1. **REST-based Architecture**: APIs follow RESTful design patterns
2. **Resource-Oriented**: APIs are organized around resources
3. **Standard HTTP Methods**: Using appropriate HTTP methods for operations
4. **Consistent Naming**: All resources and parameters follow consistent naming conventions
5. **Predictable Behavior**: Consistent patterns for common operations
6. **Secure by Design**: Security incorporated from the ground up
7. **Versioned**: APIs are versioned to allow evolution

## API Structure

### Base URL

All API endpoints are accessed from the base URL:

```
https://api.dive25.example.org/api/v1/
```

### Resource Hierarchy

Resources are organized in a logical hierarchy:

```
/api/v1/documents                   # Document collection
/api/v1/documents/{documentId}      # Specific document
/api/v1/documents/search            # Search documents
/api/v1/documents/{documentId}/versions  # Document versions
/api/v1/users                       # User collection
/api/v1/users/{userId}              # Specific user
/api/v1/groups                      # Group collection
/api/v1/groups/{groupId}/members    # Group members
```

### HTTP Methods

| Method | Purpose | Example |
|--------|---------|---------|
| GET | Retrieve resources | `GET /api/v1/documents` |
| POST | Create resources | `POST /api/v1/documents` |
| PUT | Replace resources | `PUT /api/v1/documents/{id}` |
| PATCH | Update resources | `PATCH /api/v1/documents/{id}` |
| DELETE | Remove resources | `DELETE /api/v1/documents/{id}` |

## Authentication & Authorization

### Authentication

The DIVE25 system uses JWT-based authentication:

1. **Obtaining a Token**:

```http
POST /api/v1/auth/login
Content-Type: application/json

{
  "username": "user@example.org",
  "password": "password"
}
```

Response:

```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "expiresIn": 3600,
  "tokenType": "Bearer"
}
```

2. **Using the Token**:

Include the token in the `Authorization` header:

```http
GET /api/v1/documents
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

3. **Token Refresh**:

```http
POST /api/v1/auth/refresh
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

### Authorization

The system uses a combination of role-based and attribute-based access control:

1. **Role-Based Controls**: User roles determine baseline permissions
2. **Attribute-Based Controls**: Document classification and user clearance
3. **Policy Evaluation**: Open Policy Agent evaluates access requests

Authorization is performed transparently; the API simply returns:

- `403 Forbidden` when permission is denied
- `404 Not Found` for classified resources the user doesn't have clearance to see

## Common API Patterns

### Pagination

Paginated endpoints return data in pages:

```http
GET /api/v1/documents?page=2&pageSize=20
```

Response:

```json
{
  "data": [...],
  "pagination": {
    "page": 2,
    "pageSize": 20,
    "totalPages": 7,
    "totalItems": 134,
    "hasNext": true,
    "hasPrevious": true
  }
}
```

### Filtering

Resources can be filtered using query parameters:

```http
GET /api/v1/documents?classification=UNCLASSIFIED&createdAfter=2023-01-01
```

Common filter parameters:
- `createdAfter`, `createdBefore`
- `updatedAfter`, `updatedBefore`
- `classification`
- `owner`, `contributor`
- `status`

### Sorting

Specify sorting with the `sort` parameter:

```http
GET /api/v1/documents?sort=createdAt:desc,title:asc
```

### Search

Full-text search is available at dedicated endpoints:

```http
GET /api/v1/documents/search?q=classified+information
```

Advanced search options:
- `exactMatch=true` for exact phrase matching
- `field=title` to search specific fields
- `contentType=pdf` to filter by content type

### Field Selection

Select specific fields to return:

```http
GET /api/v1/documents?fields=id,title,classification,createdAt
```

### Bulk Operations

Bulk operations are supported for efficiency:

```http
POST /api/v1/documents/bulk
Content-Type: application/json

{
  "documents": [
    { "id": "doc1", "title": "Updated Title 1" },
    { "id": "doc2", "title": "Updated Title 2" }
  ]
}
```

## Error Handling

### Error Response Format

All error responses follow a consistent format:

```json
{
  "error": {
    "code": "DOCUMENT_NOT_FOUND",
    "message": "The requested document could not be found",
    "status": 404,
    "details": {
      "documentId": "12345"
    },
    "requestId": "req-1234-5678-9012"
  }
}
```

### Common Error Codes

| Status | Code | Description |
|--------|------|-------------|
| 400 | INVALID_REQUEST | Request validation failed |
| 401 | UNAUTHORIZED | Authentication required |
| 403 | FORBIDDEN | Permission denied |
| 404 | NOT_FOUND | Resource not found |
| 409 | CONFLICT | Resource conflict |
| 422 | VALIDATION_FAILED | Validation failed |
| 429 | TOO_MANY_REQUESTS | Rate limit exceeded |
| 500 | SERVER_ERROR | Server error |

### Validation Errors

Validation errors include details about each invalid field:

```json
{
  "error": {
    "code": "VALIDATION_FAILED",
    "message": "Validation failed",
    "status": 422,
    "details": {
      "errors": [
        {
          "field": "title",
          "message": "Title is required"
        },
        {
          "field": "classification",
          "message": "Classification must be one of: UNCLASSIFIED, RESTRICTED, CONFIDENTIAL, SECRET"
        }
      ]
    },
    "requestId": "req-1234-5678-9012"
  }
}
```

## API Versioning

### Version Strategy

The DIVE25 system uses URL path versioning:

- `/api/v1/...` for the current stable version
- `/api/v2/...` for a new major version with breaking changes

### Version Compatibility

For minor, backward-compatible changes:
- New fields are added but not required
- Existing field behaviors are not changed
- New endpoints are added under the same version

For breaking changes:
- A new API version is introduced
- The previous version is maintained during transition
- Clear migration documentation is provided

### Deprecation Process

1. **Announcement**: Deprecation is announced in the documentation
2. **Warning Headers**: `Deprecation` and `Sunset` headers are added
3. **Grace Period**: At least 6 months before removal
4. **Migration Path**: Clear upgrade documentation provided

Example deprecation header:
```
Deprecation: true
Sunset: Sat, 31 Dec 2023 23:59:59 GMT
Link: <https://docs.dive25.example.org/api/migration/v1-to-v2>; rel="deprecation"
```

## Request & Response Format

### Content Types

The API supports the following content types:

- `application/json` (default)
- `application/x-www-form-urlencoded` (for simple form submissions)
- `multipart/form-data` (for file uploads)

### Request Headers

Common request headers:

| Header | Purpose | Example |
|--------|---------|---------|
| Authorization | Authentication | `Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...` |
| Content-Type | Request format | `application/json` |
| Accept | Response format | `application/json` |
| Accept-Language | Language preference | `en-US` |
| X-Request-ID | Request tracing | `req-1234-5678-9012` |

### Response Headers

Common response headers:

| Header | Purpose | Example |
|--------|---------|---------|
| Content-Type | Response format | `application/json` |
| X-Request-ID | Request tracing | `req-1234-5678-9012` |
| X-Rate-Limit-Limit | Rate limit | `1000` |
| X-Rate-Limit-Remaining | Remaining requests | `997` |
| X-Rate-Limit-Reset | Rate limit reset time | `1626969600` |

### Date/Time Format

All dates and times are in ISO 8601 format with UTC timezone:

```
YYYY-MM-DDTHH:MM:SSZ
```

Example: `2023-04-01T14:30:00Z`

## Core API Services

### Document Service API

The Document Service provides document management capabilities:

#### Create Document

```http
POST /api/v1/documents
Content-Type: application/json
Authorization: Bearer <token>

{
  "title": "Operational Plan Alpha",
  "description": "Overview of Operation Alpha",
  "classification": "NATO_CONFIDENTIAL",
  "contentType": "application/pdf",
  "metadata": {
    "author": "John Smith",
    "department": "Operations",
    "keywords": ["operation", "planning", "alpha"]
  }
}
```

Response:

```json
{
  "id": "doc12345",
  "title": "Operational Plan Alpha",
  "description": "Overview of Operation Alpha",
  "classification": "NATO_CONFIDENTIAL",
  "contentType": "application/pdf",
  "metadata": {
    "author": "John Smith",
    "department": "Operations",
    "keywords": ["operation", "planning", "alpha"]
  },
  "status": "PENDING_UPLOAD",
  "createdAt": "2023-04-01T14:30:00Z",
  "createdBy": "user123",
  "links": {
    "self": "/api/v1/documents/doc12345",
    "upload": "/api/v1/documents/doc12345/content"
  }
}
```

#### Upload Document Content

```http
PUT /api/v1/documents/doc12345/content
Content-Type: multipart/form-data
Authorization: Bearer <token>

# Form data:
file: <binary data>
```

Response:

```json
{
  "id": "doc12345",
  "title": "Operational Plan Alpha",
  "status": "ACTIVE",
  "contentSize": 2560124,
  "contentHash": "sha256:a1b2c3d4e5f6...",
  "updatedAt": "2023-04-01T14:35:00Z",
  "links": {
    "self": "/api/v1/documents/doc12345",
    "content": "/api/v1/documents/doc12345/content"
  }
}
```

#### Retrieve Document

```http
GET /api/v1/documents/doc12345
Authorization: Bearer <token>
```

Response:

```json
{
  "id": "doc12345",
  "title": "Operational Plan Alpha",
  "description": "Overview of Operation Alpha",
  "classification": "NATO_CONFIDENTIAL",
  "contentType": "application/pdf",
  "contentSize": 2560124,
  "contentHash": "sha256:a1b2c3d4e5f6...",
  "metadata": {
    "author": "John Smith",
    "department": "Operations",
    "keywords": ["operation", "planning", "alpha"]
  },
  "status": "ACTIVE",
  "createdAt": "2023-04-01T14:30:00Z",
  "createdBy": "user123",
  "updatedAt": "2023-04-01T14:35:00Z",
  "updatedBy": "user123",
  "links": {
    "self": "/api/v1/documents/doc12345",
    "content": "/api/v1/documents/doc12345/content",
    "versions": "/api/v1/documents/doc12345/versions"
  }
}
```

#### Download Document Content

```http
GET /api/v1/documents/doc12345/content
Authorization: Bearer <token>
```

Response:
```
HTTP/1.1 200 OK
Content-Type: application/pdf
Content-Disposition: attachment; filename="Operational Plan Alpha.pdf"
Content-Length: 2560124

<binary data>
```

### Search Service API

The Search Service provides document search capabilities:

#### Basic Search

```http
GET /api/v1/documents/search?q=operational+planning
Authorization: Bearer <token>
```

Response:

```json
{
  "results": [
    {
      "id": "doc12345",
      "title": "Operational Plan Alpha",
      "classification": "NATO_CONFIDENTIAL",
      "contentType": "application/pdf",
      "createdAt": "2023-04-01T14:30:00Z",
      "score": 0.92,
      "highlight": {
        "title": "Operational Plan Alpha",
        "content": "...strategic <em>operational planning</em> for the mission..."
      },
      "links": {
        "self": "/api/v1/documents/doc12345"
      }
    },
    {
      "id": "doc67890",
      "title": "Tactical Operations Manual",
      "classification": "NATO_RESTRICTED",
      "contentType": "application/pdf",
      "createdAt": "2023-03-15T10:45:00Z",
      "score": 0.78,
      "highlight": {
        "content": "...includes <em>operational planning</em> guidelines for field units..."
      },
      "links": {
        "self": "/api/v1/documents/doc67890"
      }
    }
  ],
  "pagination": {
    "page": 1,
    "pageSize": 10,
    "totalPages": 3,
    "totalItems": 23
  },
  "metadata": {
    "query": "operational planning",
    "processingTimeMs": 145,
    "filters": {}
  }
}
```

#### Advanced Search

```http
POST /api/v1/documents/search
Content-Type: application/json
Authorization: Bearer <token>

{
  "query": "operational planning",
  "filters": {
    "classification": ["NATO_UNCLASSIFIED", "NATO_RESTRICTED"],
    "dateRange": {
      "field": "createdAt",
      "from": "2023-01-01T00:00:00Z",
      "to": "2023-04-01T23:59:59Z"
    },
    "metadata": {
      "department": "Operations"
    }
  },
  "fields": ["title", "content", "metadata.keywords"],
  "sort": [
    { "score": "desc" },
    { "createdAt": "desc" }
  ],
  "page": 1,
  "pageSize": 20
}
```

### Authentication Service API

The Authentication Service handles user authentication:

#### Login

```http
POST /api/v1/auth/login
Content-Type: application/json

{
  "username": "john.smith@example.org",
  "password": "password123"
}
```

Response:

```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "expiresIn": 3600,
  "tokenType": "Bearer",
  "user": {
    "id": "user123",
    "username": "john.smith",
    "email": "john.smith@example.org",
    "displayName": "John Smith",
    "roles": ["document_creator", "document_viewer"],
    "clearance": "NATO_SECRET"
  }
}
```

#### Refresh Token

```http
POST /api/v1/auth/refresh
Content-Type: application/json

{
  "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

Response:

```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "expiresIn": 3600,
  "tokenType": "Bearer"
}
```

#### Logout

```http
POST /api/v1/auth/logout
Authorization: Bearer <token>
```

Response:

```
HTTP/1.1 204 No Content
```

## Implementing New API Endpoints

When implementing new API endpoints, follow these guidelines:

### 1. Planning the API

1. **Define the Resource**: Clearly identify the resource and its attributes
2. **Map to HTTP Methods**: Determine which HTTP methods apply
3. **Define URL Structure**: Follow the established patterns
4. **Document Request/Response**: Define the formats clearly
5. **Security Considerations**: Determine authorization requirements

### 2. Creating the Controller

Example controller structure (TypeScript):

```typescript
// src/controllers/document-controller.ts
import { Request, Response, NextFunction } from 'express';
import { DocumentService } from '../services/document-service';
import { validateRequest } from '../middleware/validation';
import { createDocumentSchema } from '../schemas/document-schema';
import { logger } from '../utils/logger';

export class DocumentController {
  constructor(private documentService: DocumentService) {}

  async createDocument(req: Request, res: Response, next: NextFunction) {
    try {
      // Validate request
      const validationResult = validateRequest(req.body, createDocumentSchema);
      if (!validationResult.isValid) {
        return res.status(422).json({
          error: {
            code: 'VALIDATION_FAILED',
            message: 'Validation failed',
            status: 422,
            details: { errors: validationResult.errors },
            requestId: req.id
          }
        });
      }

      // Create document
      const document = await this.documentService.createDocument({
        ...req.body,
        createdBy: req.user.id
      });

      // Return response
      return res.status(201).json(document);
    } catch (error) {
      logger.error('Error creating document', { error, requestId: req.id });
      return next(error);
    }
  }

  // Additional endpoints...
}
```

### 3. Setting Up Routes

Example route configuration:

```typescript
// src/routes/document-routes.ts
import { Router } from 'express';
import { DocumentController } from '../controllers/document-controller';
import { requireAuth } from '../middleware/auth';
import { requirePermission } from '../middleware/authorization';
import { validateRequest } from '../middleware/validation';
import { createDocumentSchema } from '../schemas/document-schema';

export function setupDocumentRoutes(controller: DocumentController): Router {
  const router = Router();

  // Get all documents
  router.get('/', 
    requireAuth,
    controller.getDocuments.bind(controller)
  );

  // Create document
  router.post('/',
    requireAuth,
    requirePermission('document:create'),
    validateRequest(createDocumentSchema),
    controller.createDocument.bind(controller)
  );

  // Get document by ID
  router.get('/:id',
    requireAuth,
    controller.getDocumentById.bind(controller)
  );

  // Update document
  router.put('/:id',
    requireAuth,
    requirePermission('document:update'),
    validateRequest(updateDocumentSchema),
    controller.updateDocument.bind(controller)
  );

  // Delete document
  router.delete('/:id',
    requireAuth,
    requirePermission('document:delete'),
    controller.deleteDocument.bind(controller)
  );

  return router;
}
```

### 4. Implementing Validation

Example validation schema (using Joi):

```typescript
// src/schemas/document-schema.ts
import Joi from 'joi';

export const createDocumentSchema = Joi.object({
  title: Joi.string().required().max(200),
  description: Joi.string().max(2000),
  classification: Joi.string().required().valid(
    'UNCLASSIFIED', 
    'NATO_RESTRICTED', 
    'NATO_CONFIDENTIAL', 
    'NATO_SECRET'
  ),
  contentType: Joi.string().required(),
  metadata: Joi.object({
    author: Joi.string(),
    department: Joi.string(),
    keywords: Joi.array().items(Joi.string())
  })
});

export const updateDocumentSchema = Joi.object({
  title: Joi.string().max(200),
  description: Joi.string().max(2000),
  classification: Joi.string().valid(
    'UNCLASSIFIED', 
    'NATO_RESTRICTED', 
    'NATO_CONFIDENTIAL', 
    'NATO_SECRET'
  ),
  metadata: Joi.object({
    author: Joi.string(),
    department: Joi.string(),
    keywords: Joi.array().items(Joi.string())
  })
});
```

### 5. Implementing Authorization

Example authorization middleware:

```typescript
// src/middleware/authorization.ts
import { Request, Response, NextFunction } from 'express';
import { PolicyService } from '../services/policy-service';

const policyService = new PolicyService();

export function requirePermission(permission: string) {
  return async (req: Request, res: Response, next: NextFunction) => {
    try {
      // Check if user has required permission
      const allowed = await policyService.checkPermission({
        userId: req.user.id,
        permission,
        resource: req.params.id,
        context: {
          resourceType: 'document',
          method: req.method
        }
      });

      if (allowed) {
        return next();
      }

      return res.status(403).json({
        error: {
          code: 'FORBIDDEN',
          message: 'Permission denied',
          status: 403,
          requestId: req.id
        }
      });
    } catch (error) {
      return next(error);
    }
  };
}
```

### 6. Testing the API

Example API test:

```typescript
// src/tests/document-api.test.ts
import request from 'supertest';
import { app } from '../app';
import { createTestToken } from './utils';

describe('Document API', () => {
  describe('POST /api/v1/documents', () => {
    it('should create a document with valid data', async () => {
      // Arrange
      const token = createTestToken({
        id: 'user123',
        roles: ['document_creator'],
        clearance: 'NATO_SECRET'
      });

      const documentData = {
        title: 'Test Document',
        description: 'This is a test document',
        classification: 'NATO_CONFIDENTIAL',
        contentType: 'application/pdf',
        metadata: {
          author: 'Test User',
          department: 'Testing',
          keywords: ['test', 'document']
        }
      };

      // Act
      const response = await request(app)
        .post('/api/v1/documents')
        .set('Authorization', `Bearer ${token}`)
        .send(documentData);

      // Assert
      expect(response.status).toBe(201);
      expect(response.body).toHaveProperty('id');
      expect(response.body.title).toBe(documentData.title);
      expect(response.body.classification).toBe(documentData.classification);
      expect(response.body.status).toBe('PENDING_UPLOAD');
      expect(response.body.createdBy).toBe('user123');
    });

    it('should return 422 for invalid document data', async () => {
      // Arrange
      const token = createTestToken({
        id: 'user123',
        roles: ['document_creator'],
        clearance: 'NATO_SECRET'
      });

      const invalidData = {
        // Missing required fields
        description: 'This is an invalid document'
      };

      // Act
      const response = await request(app)
        .post('/api/v1/documents')
        .set('Authorization', `Bearer ${token}`)
        .send(invalidData);

      // Assert
      expect(response.status).toBe(422);
      expect(response.body.error).toHaveProperty('code', 'VALIDATION_FAILED');
      expect(response.body.error.details.errors).toHaveLength(2); // title and classification
    });
  });
});
```

## API Performance Considerations

When implementing or extending APIs, consider these performance best practices:

### 1. Pagination & Data Volume

- Always paginate list endpoints
- Default to reasonable page sizes (20-50 items)
- Consider using cursor-based pagination for large datasets
- Support field selection to reduce payload size

### 2. Caching Strategy

- Set appropriate cache headers:
  - `Cache-Control: private, max-age=300` for user-specific data
  - `Cache-Control: public, max-age=3600` for common resources
  - `ETag` for conditional requests
- Implement cache invalidation when resources change

### 3. Database Query Optimization

- Ensure proper indexes for commonly queried fields
- Use projection to limit returned fields
- Optimize complex queries with explain plans
- Consider denormalization for performance-critical paths

### 4. API Rate Limiting

- Implement rate limiting for all endpoints
- Set tiered limits based on endpoint sensitivity
- Return clear rate limit headers:
  - `X-Rate-Limit-Limit`
  - `X-Rate-Limit-Remaining`
  - `X-Rate-Limit-Reset`

## API Documentation

### OpenAPI Specifications

All APIs are documented using OpenAPI 3.0:

1. **Central OpenAPI File**: `/docs/api/openapi.yaml`
2. **Generated Documentation**: Available at `/api/docs`
3. **Per-Service Definitions**: In each service repository

Example OpenAPI snippet:

```yaml
openapi: 3.0.0
info:
  title: DIVE25 Document API
  version: 1.0.0
  description: API for managing documents in the DIVE25 system
paths:
  /api/v1/documents:
    get:
      summary: List documents
      description: Returns a paginated list of documents
      parameters:
        - name: page
          in: query
          description: Page number
          schema:
            type: integer
            default: 1
        - name: pageSize
          in: query
          description: Items per page
          schema:
            type: integer
            default: 20
      responses:
        '200':
          description: List of documents
          content:
            application/json:
              schema:
                type: object
                properties:
                  data:
                    type: array
                    items:
                      $ref: '#/components/schemas/Document'
                  pagination:
                    $ref: '#/components/schemas/Pagination'
        '401':
          $ref: '#/components/responses/Unauthorized'
```

### Documentation Generation

API documentation is generated from source code and OpenAPI specs:

```bash
# Generate OpenAPI specs from code annotations
npm run generate:api-docs

# Validate OpenAPI specs
npm run validate:api-docs

# Start API documentation server
npm run docs:serve
```

## API Security Checklist

When implementing new API endpoints, follow this security checklist:

1. **Authentication & Authorization**
   - [ ] Endpoint requires authentication when appropriate
   - [ ] Authorization checks are implemented
   - [ ] User permissions are verified
   - [ ] Document classification is checked against user clearance

2. **Input Validation**
   - [ ] All input parameters are validated
   - [ ] Complex validation rules are properly implemented
   - [ ] Input sanitization is applied
   - [ ] File uploads are validated (type, size, content)

3. **Output Security**
   - [ ] Sensitive data is properly filtered
   - [ ] Error messages don't leak sensitive information
   - [ ] CORS headers are properly configured
   - [ ] Security headers are set correctly

4. **Rate Limiting & Abuse Prevention**
   - [ ] Rate limiting is configured
   - [ ] Resource-intensive operations are protected
   - [ ] Anti-automation measures implemented for sensitive endpoints

5. **Logging & Monitoring**
   - [ ] Appropriate logging is implemented
   - [ ] Security events are properly logged
   - [ ] Sensitive data is excluded from logs
   - [ ] Request IDs are included for traceability

## Related Documentation

- [Contribution Guide](contribution.md)
- [Development Environment Setup](environment.md)
- [Testing Guide](testing.md)
- [Technical API Documentation](../technical/api.md) 