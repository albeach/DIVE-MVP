# DIVE25 API Documentation

This document provides comprehensive documentation for the DIVE25 Document Access System API, including endpoints, authentication, request/response formats, and error handling.

## API Overview

The DIVE25 API follows RESTful principles and provides secure access to document metadata and content. All API interactions are secured through OAuth2/OpenID Connect authentication and role-based access control.

### Base URL

- Production: `https://api.dive25.local` (or your configured domain)
- Development: `https://api.dive25.local` (local development setup)

### API Versioning

The API uses URL versioning:

- Current version: `/api/v1`
- Full base path: `https://api.dive25.local/api/v1`

### Response Format

All API responses are in JSON format and follow a consistent structure:

```json
{
  "success": true|false,
  "data": { ... },  // Only present on successful requests
  "error": {        // Only present on failed requests
    "code": "ERROR_CODE",
    "message": "Human readable error message"
  },
  "meta": {
    "pagination": { ... },  // Pagination details if applicable
    "timestamp": "2023-03-01T12:00:00Z"
  }
}
```

## Authentication and Authorization

### Authentication

All API requests must include a valid OAuth2 Bearer token in the Authorization header:

```
Authorization: Bearer <jwt_token>
```

Tokens are obtained through the Keycloak OpenID Connect provider.

### Authorization

Access to API endpoints is controlled by:

1. User roles and permissions
2. Document classification levels
3. Need-to-know attributes
4. Open Policy Agent (OPA) policy rules

### Obtaining Authentication Tokens

1. **Client Credentials Flow** (for service-to-service communication):

```
POST /auth/realms/dive25/protocol/openid-connect/token
Content-Type: application/x-www-form-urlencoded

grant_type=client_credentials&
client_id=YOUR_CLIENT_ID&
client_secret=YOUR_CLIENT_SECRET
```

2. **Authorization Code Flow** (for user authentication):

Redirect users to:

```
GET /auth/realms/dive25/protocol/openid-connect/auth?
response_type=code&
client_id=YOUR_CLIENT_ID&
redirect_uri=YOUR_CALLBACK_URL&
scope=openid profile email
```

Then exchange the code for tokens:

```
POST /auth/realms/dive25/protocol/openid-connect/token
Content-Type: application/x-www-form-urlencoded

grant_type=authorization_code&
code=AUTHORIZATION_CODE&
client_id=YOUR_CLIENT_ID&
client_secret=YOUR_CLIENT_SECRET&
redirect_uri=YOUR_CALLBACK_URL
```

## API Endpoints

### Document Management

#### List Documents

```
GET /api/v1/documents
```

Query parameters:
- `page`: Page number (default: 1)
- `limit`: Items per page (default: 20, max: 100)
- `sort`: Sort field (default: "updatedAt")
- `order`: Sort order ("asc" or "desc", default: "desc")
- `search`: Text search query
- `classification`: Filter by classification level
- `fromDate`: Filter by creation date (ISO format)
- `toDate`: Filter by creation date (ISO format)
- `tags`: Filter by tags (comma-separated)

Response:

```json
{
  "success": true,
  "data": [
    {
      "id": "doc123",
      "title": "NATO Operation Report",
      "description": "Confidential report on recent operations",
      "classification": "CONFIDENTIAL",
      "creator": {
        "id": "user456",
        "name": "John Smith"
      },
      "createdAt": "2023-02-15T14:30:00Z",
      "updatedAt": "2023-02-16T09:45:00Z",
      "tags": ["operations", "report", "2023"],
      "metadata": {
        "version": "1.2",
        "country": "Multiple",
        "documentType": "Report"
      }
    },
    // ...more documents
  ],
  "meta": {
    "pagination": {
      "page": 1,
      "limit": 20,
      "total": 156,
      "pages": 8
    },
    "timestamp": "2023-03-01T12:00:00Z"
  }
}
```

#### Get Document Details

```
GET /api/v1/documents/{documentId}
```

Response:

```json
{
  "success": true,
  "data": {
    "id": "doc123",
    "title": "NATO Operation Report",
    "description": "Confidential report on recent operations",
    "classification": "CONFIDENTIAL",
    "creator": {
      "id": "user456",
      "name": "John Smith"
    },
    "createdAt": "2023-02-15T14:30:00Z",
    "updatedAt": "2023-02-16T09:45:00Z",
    "tags": ["operations", "report", "2023"],
    "metadata": {
      "version": "1.2",
      "country": "Multiple",
      "documentType": "Report",
      "language": "English",
      "pageCount": 42,
      "references": ["DOC-987", "DOC-654"]
    },
    "accessControl": {
      "clearanceRequired": "CONFIDENTIAL",
      "needToKnow": ["OPERATION_ALPHA", "REGION_EUROPE"],
      "allowedCountries": ["USA", "UK", "FRA", "DEU"]
    }
  },
  "meta": {
    "timestamp": "2023-03-01T12:00:00Z"
  }
}
```

#### Download Document Content

```
GET /api/v1/documents/{documentId}/content
```

Response: Document file with appropriate Content-Type header (PDF, DOCX, etc.)

#### Create New Document

```
POST /api/v1/documents
Content-Type: multipart/form-data
```

Form parameters:
- `title`: Document title (required)
- `description`: Document description
- `classification`: Classification level (required)
- `file`: Document file (required)
- `tags`: Array of tags
- `metadata`: JSON object with additional metadata
- `accessControl`: JSON object with access control settings

Response:

```json
{
  "success": true,
  "data": {
    "id": "doc789",
    "title": "New Document",
    // ...other document fields
  },
  "meta": {
    "timestamp": "2023-03-01T12:00:00Z"
  }
}
```

#### Update Document Metadata

```
PUT /api/v1/documents/{documentId}
Content-Type: application/json
```

Request body:

```json
{
  "title": "Updated Title",
  "description": "Updated description",
  "tags": ["updated", "tags"],
  "metadata": {
    "version": "2.0",
    "status": "Final"
  }
}
```

Response:

```json
{
  "success": true,
  "data": {
    "id": "doc123",
    "title": "Updated Title",
    // ...other document fields with updates
  },
  "meta": {
    "timestamp": "2023-03-01T12:00:00Z"
  }
}
```

#### Delete Document

```
DELETE /api/v1/documents/{documentId}
```

Response:

```json
{
  "success": true,
  "data": {
    "message": "Document successfully deleted"
  },
  "meta": {
    "timestamp": "2023-03-01T12:00:00Z"
  }
}
```

### User Management

#### Get Current User Profile

```
GET /api/v1/users/me
```

Response:

```json
{
  "success": true,
  "data": {
    "id": "user456",
    "username": "jsmith",
    "firstName": "John",
    "lastName": "Smith",
    "email": "john.smith@example.com",
    "organization": "NATO HQ",
    "clearanceLevel": "SECRET",
    "attributes": {
      "country": "USA",
      "department": "Intelligence",
      "needToKnow": ["OPERATION_ALPHA", "REGION_EUROPE"]
    },
    "roles": ["user", "analyst"],
    "lastLogin": "2023-03-01T08:30:00Z"
  },
  "meta": {
    "timestamp": "2023-03-01T12:00:00Z"
  }
}
```

#### Update User Profile

```
PUT /api/v1/users/me
Content-Type: application/json
```

Request body:

```json
{
  "firstName": "John",
  "lastName": "Smith",
  "email": "john.smith@example.com",
  "preferences": {
    "theme": "dark",
    "notifications": {
      "email": true,
      "inApp": true
    }
  }
}
```

Response:

```json
{
  "success": true,
  "data": {
    "id": "user456",
    // ...updated user fields
  },
  "meta": {
    "timestamp": "2023-03-01T12:00:00Z"
  }
}
```

### Admin Endpoints (Admin role required)

#### List Users

```
GET /api/v1/admin/users
```

Query parameters:
- `page`: Page number (default: 1)
- `limit`: Items per page (default: 20, max: 100)
- `search`: Text search by name, username, or email
- `role`: Filter by role
- `clearance`: Filter by clearance level
- `organization`: Filter by organization

Response:

```json
{
  "success": true,
  "data": [
    {
      "id": "user456",
      "username": "jsmith",
      "firstName": "John",
      "lastName": "Smith",
      "email": "john.smith@example.com",
      "organization": "NATO HQ",
      "clearanceLevel": "SECRET",
      "roles": ["user", "analyst"],
      "status": "active",
      "lastLogin": "2023-03-01T08:30:00Z"
    },
    // ...more users
  ],
  "meta": {
    "pagination": {
      "page": 1,
      "limit": 20,
      "total": 85,
      "pages": 5
    },
    "timestamp": "2023-03-01T12:00:00Z"
  }
}
```

#### Get User Details

```
GET /api/v1/admin/users/{userId}
```

Response: Detailed user information

#### Update User

```
PUT /api/v1/admin/users/{userId}
Content-Type: application/json
```

Request body: User update fields

Response: Updated user details

#### Get System Statistics

```
GET /api/v1/admin/statistics
```

Response:

```json
{
  "success": true,
  "data": {
    "users": {
      "total": 156,
      "active": 143,
      "newLastMonth": 12
    },
    "documents": {
      "total": 3456,
      "byClassification": {
        "UNCLASSIFIED": 1245,
        "RESTRICTED": 876,
        "CONFIDENTIAL": 987,
        "SECRET": 340,
        "TOP_SECRET": 8
      },
      "newLastMonth": 123
    },
    "access": {
      "totalRequests": 28765,
      "approvedRequests": 25432,
      "deniedRequests": 3333
    }
  },
  "meta": {
    "timestamp": "2023-03-01T12:00:00Z"
  }
}
```

### Access Control

#### Request Document Access

When a user doesn't have access to a document but believes they should:

```
POST /api/v1/documents/{documentId}/access-request
Content-Type: application/json
```

Request body:

```json
{
  "reason": "Required for ongoing investigation",
  "duration": "7d",  // Access duration (1d, 7d, 30d, permanent)
  "additionalInfo": "Reference case #12345"
}
```

Response:

```json
{
  "success": true,
  "data": {
    "requestId": "req789",
    "status": "pending",
    "documentId": "doc123",
    "reason": "Required for ongoing investigation",
    "duration": "7d",
    "requestedAt": "2023-03-01T12:00:00Z",
    "expiresAt": "2023-03-08T12:00:00Z"
  },
  "meta": {
    "timestamp": "2023-03-01T12:00:00Z"
  }
}
```

#### Check Access Status

```
GET /api/v1/documents/{documentId}/access
```

Response:

```json
{
  "success": true,
  "data": {
    "documentId": "doc123",
    "hasAccess": true,
    "accessLevel": "read",
    "reason": "Appropriate clearance and need-to-know",
    "expiresAt": null,  // null for permanent access
    "requestStatus": null  // null or pending/approved/denied if an access request exists
  },
  "meta": {
    "timestamp": "2023-03-01T12:00:00Z"
  }
}
```

## Error Handling

The API uses standard HTTP status codes and detailed error responses:

### Error Codes

- `400 Bad Request`: Invalid request parameters
- `401 Unauthorized`: Missing or invalid authentication
- `403 Forbidden`: Insufficient permissions
- `404 Not Found`: Resource not found
- `409 Conflict`: Request conflicts with current state
- `422 Unprocessable Entity`: Validation errors
- `429 Too Many Requests`: Rate limit exceeded
- `500 Internal Server Error`: Server-side error

### Error Response Example

```json
{
  "success": false,
  "error": {
    "code": "DOCUMENT_ACCESS_DENIED",
    "message": "You do not have sufficient clearance to access this document",
    "details": {
      "documentId": "doc123",
      "requiredClearance": "SECRET",
      "userClearance": "CONFIDENTIAL",
      "missingAttributes": ["OPERATION_ALPHA"]
    }
  },
  "meta": {
    "timestamp": "2023-03-01T12:00:00Z"
  }
}
```

## Rate Limiting

API requests are rate-limited to prevent abuse:

- Standard users: 100 requests per minute
- Admin users: 300 requests per minute
- System services: 1000 requests per minute

Rate limit information is included in response headers:

- `X-RateLimit-Limit`: Total requests allowed per time window
- `X-RateLimit-Remaining`: Remaining requests in current window
- `X-RateLimit-Reset`: Time (in seconds) until rate limit resets

## API Versioning Policy

- The current API version is v1
- We maintain backward compatibility within the same major version
- Breaking changes will be introduced in new major versions
- Deprecated endpoints will be maintained for at least 6 months
- Advance notice will be given before endpoints are deprecated

## Webhook Notifications

The system can send webhook notifications for events:

### Configure Webhooks (Admin only)

```
POST /api/v1/admin/webhooks
Content-Type: application/json
```

Request body:

```json
{
  "url": "https://your-service.example.com/dive25-webhook",
  "events": ["document.created", "document.updated", "access.granted"],
  "secret": "your-webhook-secret"
}
```

### Webhook Payload Format

```json
{
  "event": "document.created",
  "timestamp": "2023-03-01T12:00:00Z",
  "data": {
    // Event-specific data
  },
  "signature": "HMAC-SHA256 signature using your webhook secret"
}
```

## SDKs and Client Libraries

Official client libraries are available for:

- JavaScript/TypeScript (Node.js and browser)
- Python
- Java
- C#

See the [client libraries documentation](./client-libraries.md) for usage details.

## API Changelog

### v1.0.0 (2025-02-13)

- Initial API release

### v1.1.0 (2025-03-02)

- Added document version history endpoints
- Added bulk document operations
- Improved search capabilities with advanced filters

## Support and Feedback

For API support or feedback:

- Email: api-support@dive25.example.com
- Documentation Issues: Create an issue in the GitHub repository
- Feature Requests: Submit through the developer portal 
