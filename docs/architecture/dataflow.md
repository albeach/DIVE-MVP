# Data Flow

This document describes how data flows through the DIVE25 Document Access System, illustrating the paths that documents, user data, and metadata take through the various system components.

## Overview

The DIVE25 Document Access System handles several types of data:

1. **Documents**: The actual files being stored and accessed
2. **Metadata**: Information about documents (title, author, classification, etc.)
3. **User Data**: Authentication information and user attributes
4. **Audit Information**: Records of system and user activities
5. **Configuration Data**: System settings and operational parameters

## Primary Data Flows

### Document Upload Flow

```
┌────────┐      ┌─────────────┐      ┌─────────────┐      ┌──────────────┐
│ Client │─────▶│ API Gateway │─────▶│  Document   │─────▶│   Storage    │
└────────┘      └─────────────┘      │   Service   │      │   Service    │
                                     └──────┬──────┘      └──────────────┘
                                            │
                  ┌──────────────────┬─────┴─────┐
                  │                  │           │
                  ▼                  ▼           ▼
         ┌─────────────────┐ ┌─────────────┐ ┌─────────────┐
         │  Policy Service │ │  Database   │ │   Search    │
         │                 │ │  Service    │ │   Service   │
         └─────────────────┘ └─────────────┘ └──────┬──────┘
                                                    │
                                                    ▼
                                            ┌──────────────┐
                                            │Elasticsearch │
                                            └──────────────┘
```

**Data Flow Steps:**

1. **Client → API Gateway**
   - Document binary data
   - Document metadata (title, author, classification, etc.)
   - Authentication token

2. **API Gateway → Document Service**
   - Validated user identity
   - Document data and metadata
   - Request context

3. **Document Service → Policy Service**
   - User attributes
   - Document metadata
   - Action type (upload)

4. **Policy Service → Document Service**
   - Authorization decision
   - Applicable security constraints

5. **Document Service → Storage Service**
   - Document binary data
   - Storage metadata (content type, encryption parameters)

6. **Document Service → Database Service**
   - Document metadata
   - Access control information
   - Versioning information

7. **Document Service → Search Service**
   - Document content for indexing
   - Searchable metadata 
   - Security classification information

8. **Search Service → Elasticsearch**
   - Indexed document content
   - Processed metadata for search optimization
   - Security filters

### Document Retrieval Flow

```
┌────────┐      ┌─────────────┐      ┌─────────────┐      ┌──────────────┐
│ Client │─────▶│ API Gateway │─────▶│   Search    │─────▶│Elasticsearch │
└───┬────┘      └─────────────┘      │   Service   │      └──────────────┘
    │                                 └──────┬──────┘
    │                                        │
    │                                        ▼
    │                                ┌─────────────┐
    │                                │  Document   │
    │                                │   Service   │
    │                                └──────┬──────┘
    │                                       │
    │               ┌─────────────────┬─────┴─────┐
    │               │                 │           │
    │               ▼                 ▼           ▼
    │      ┌─────────────────┐ ┌─────────────┐ ┌──────────────┐
    │      │  Policy Service │ │  Database   │ │   Storage    │
    │      │                 │ │  Service    │ │   Service    │
    │      └─────────────────┘ └─────────────┘ └──────┬───────┘
    │                                                  │
    └──────────────────────────────────────────────────┘
```

**Data Flow Steps:**

1. **Client → API Gateway**
   - Search query or document ID
   - Authentication token

2. **API Gateway → Search Service**
   - Validated user identity
   - Search parameters
   - Request context

3. **Search Service → Elasticsearch**
   - Query parameters
   - Security filters based on user attributes

4. **Search Service → Document Service**
   - Document identifiers from search results
   - User context

5. **Document Service → Policy Service**
   - User attributes
   - Document metadata
   - Action type (retrieve)

6. **Policy Service → Document Service**
   - Authorization decision
   - Content redaction rules (if applicable)

7. **Document Service → Database Service**
   - Query for complete document metadata

8. **Document Service → Storage Service**
   - Request for document binary data

9. **Storage Service → Client**
   - Document binary data (potentially via Document Service)
   - Content type information

### Authentication Flow

```
┌────────┐      ┌─────────────┐      ┌─────────────┐      ┌──────────────┐
│ Client │─────▶│ API Gateway │─────▶│Authentication│─────▶│  Directory   │
└───┬────┘      └─────────────┘      │   Service   │      │   Service    │
    │                                 └──────┬──────┘      └──────────────┘
    │                                        │
    └────────────────────────────────────────┘
```

**Data Flow Steps:**

1. **Client → API Gateway**
   - User credentials or token refresh request
   - Client identifier

2. **API Gateway → Authentication Service**
   - Credentials
   - Client context

3. **Authentication Service → Directory Service**
   - User identifier
   - Authentication request

4. **Directory Service → Authentication Service**
   - User attributes
   - Group memberships
   - Authentication result

5. **Authentication Service → Client**
   - JWT token containing:
     - User identity
     - Role information
     - Authorization scopes
     - Expiration time

## Secondary Data Flows

### Audit Logging

```
┌─────────────┐      ┌─────────────┐
│   Service   │─────▶│  Database   │
│  Components │      │   Service   │
└─────────────┘      └─────────────┘
```

All system components generate audit logs for security-relevant events:

1. **Components → Database Service**
   - Timestamp
   - Event type
   - User identifier
   - Action details
   - Result status
   - System identifiers (IP, service ID)

### Configuration Updates

```
┌────────────┐      ┌─────────────┐      ┌─────────────┐
│ Admin User │─────▶│ API Gateway │─────▶│ Config API  │
└────────────┘      └─────────────┘      └──────┬──────┘
                                                 │
                                                 ▼
                                         ┌─────────────┐
                                         │  Database   │
                                         │   Service   │
                                         └──────┬──────┘
                                                │
                                                ▼
                                         ┌─────────────┐
                                         │   Service   │
                                         │ Components  │
                                         └─────────────┘
```

System configuration updates flow through the following path:

1. **Admin User → API Gateway**
   - Configuration changes
   - Administrative credentials

2. **API Gateway → Configuration API**
   - Validated admin identity
   - Configuration parameters

3. **Configuration API → Database Service**
   - Updated configuration values
   - Change history

4. **Database Service → Service Components**
   - Configuration notifications
   - Updated parameters

## Data Transformations

The system applies several transformations to data as it flows through components:

### Document Processing
1. **Content Extraction**: Plain text and metadata extracted from binary documents
2. **Classification Marking**: Security markings applied based on content and context
3. **Format Conversion**: Standardized formats for viewing or indexing
4. **Redaction**: Automatic redaction of sensitive information based on policies

### Search Indexing
1. **Tokenization**: Breaking document content into searchable tokens
2. **Normalization**: Standardizing text for improved search (stemming, case folding)
3. **Entity Extraction**: Identifying key entities (people, places, organizations)
4. **Security Filtering**: Adding security metadata for access control during search

### User Data
1. **Attribute Mapping**: Converting directory attributes to standardized formats
2. **Role Assignment**: Deriving roles from group memberships and attributes
3. **Token Generation**: Creating security tokens with appropriate claims

## Cross-Cutting Data Concerns

### Security Controls

The following security controls are applied to data throughout the system:

1. **Encryption**:
   - Data in transit: TLS 1.3 for all communications
   - Data at rest: AES-256 encryption for stored documents
   - Database encryption for sensitive metadata

2. **Access Control**:
   - Attribute-Based Access Control (ABAC) via Policy Service
   - JWT token validation at API Gateway
   - Fine-grained permissions enforced at service level

3. **Data Integrity**:
   - Digital signatures for document authenticity
   - Hash verification for document transfers
   - Audit trails for all data modifications

### Data Retention and Compliance

1. **Document Lifecycle**:
   - Retention policies applied based on document classification
   - Automated archival processes for aging documents
   - Compliance-driven deletion workflows

2. **Audit Data**:
   - Long-term storage of security audit events
   - Tamper-evident audit logs
   - Compliance reporting capabilities

## Error Handling

Error conditions in data flows are handled by:

1. **Validation Failures**:
   - Client-side input validation
   - Server-side schema validation
   - Standardized error responses

2. **Processing Errors**:
   - Transaction rollback for multi-step operations
   - Retry mechanisms for transient failures
   - Dead letter queues for failed asynchronous operations

3. **System Failures**:
   - Circuit breakers for dependent service failures
   - Graceful degradation of functionality
   - Automated recovery procedures

## Related Documentation

- For detailed component information, see [Component Diagram](components.md)
- For security implementation details, see [Security Architecture](security.md)
- For API specifications, see [API Documentation](../technical/api.md)
- For database schema information, see [Database Schema](../technical/database.md) 