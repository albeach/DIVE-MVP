# Testing Guide

This guide outlines the testing methodologies, frameworks, and best practices for testing the DIVE25 Document Access System. It covers unit testing, integration testing, end-to-end testing, and performance testing.

## Testing Overview

The DIVE25 system employs a comprehensive testing strategy consisting of the following test types:

1. **Unit Tests**: Test individual components in isolation
2. **Integration Tests**: Test interactions between components
3. **API Tests**: Test HTTP endpoints and API contracts
4. **End-to-End Tests**: Test complete user flows
5. **Security Tests**: Verify security controls and policies
6. **Performance Tests**: Measure system performance under load

## Test Environments

The DIVE25 system uses the following test environments:

| Environment | Purpose | Configuration | Data |
|-------------|---------|---------------|------|
| Local Development | Developer testing | Local services with Docker | Development fixtures |
| CI Environment | Automated tests during CI | Ephemeral containers | Test fixtures |
| Test Environment | QA testing | Kubernetes deployment | Anonymized production-like data |
| Staging Environment | Pre-production validation | Production-like setup | Copy of production data |

## Unit Testing

### JavaScript/TypeScript Unit Testing

The JavaScript/TypeScript services use Jest for unit testing.

#### Setting Up Jest

Jest is already configured in each repository. The configuration is in `jest.config.js`.

```javascript
// jest.config.js example
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  roots: ['<rootDir>/src'],
  collectCoverageFrom: [
    'src/**/*.{js,ts}',
    '!src/**/*.d.ts',
    '!src/types/**/*',
  ],
  coverageThreshold: {
    global: {
      branches: 80,
      functions: 80,
      lines: 80,
      statements: 80,
    },
  },
  testMatch: ['**/__tests__/**/*.test.ts'],
};
```

#### Running Unit Tests

```bash
# Run all unit tests
npm run test

# Run tests with coverage
npm run test:coverage

# Run specific test file
npm test -- src/__tests__/document-service.test.ts

# Run tests in watch mode during development
npm test -- --watch
```

#### Writing Unit Tests

Unit tests should be placed in the `__tests__` directory next to the code being tested. Each test file should be named `*.test.ts`.

Example unit test for a Document Service:

```typescript
// src/__tests__/document-service.test.ts
import { DocumentService } from '../services/document-service';
import { DocumentRepository } from '../repositories/document-repository';

// Mock dependencies
jest.mock('../repositories/document-repository');

describe('DocumentService', () => {
  let documentService: DocumentService;
  let mockDocumentRepository: jest.Mocked<DocumentRepository>;
  
  beforeEach(() => {
    mockDocumentRepository = new DocumentRepository() as jest.Mocked<DocumentRepository>;
    documentService = new DocumentService(mockDocumentRepository);
  });
  
  afterEach(() => {
    jest.resetAllMocks();
  });
  
  describe('getDocumentById', () => {
    it('should return document when found', async () => {
      // Arrange
      const mockDocument = { 
        id: '123', 
        title: 'Test Document', 
        classification: 'UNCLASSIFIED'
      };
      mockDocumentRepository.findById.mockResolvedValue(mockDocument);
      
      // Act
      const result = await documentService.getDocumentById('123', { clearance: 'SECRET' });
      
      // Assert
      expect(mockDocumentRepository.findById).toHaveBeenCalledWith('123');
      expect(result).toEqual(mockDocument);
    });
    
    it('should throw NotFoundError when document not found', async () => {
      // Arrange
      mockDocumentRepository.findById.mockResolvedValue(null);
      
      // Act & Assert
      await expect(
        documentService.getDocumentById('999', { clearance: 'SECRET' })
      ).rejects.toThrow('Document not found');
    });
    
    it('should throw ForbiddenError when user lacks clearance', async () => {
      // Arrange
      const mockDocument = { 
        id: '123', 
        title: 'Secret Document', 
        classification: 'SECRET'
      };
      mockDocumentRepository.findById.mockResolvedValue(mockDocument);
      
      // Act & Assert
      await expect(
        documentService.getDocumentById('123', { clearance: 'UNCLASSIFIED' })
      ).rejects.toThrow('Insufficient clearance');
    });
  });
});
```

#### Test Coverage

Aim for at least 80% code coverage for unit tests. Coverage reports are generated when running `npm run test:coverage`. The reports are saved in the `coverage` directory.

### Java Unit Testing

Java services use JUnit 5 for unit testing.

#### Running Java Unit Tests

```bash
# Using Gradle
./gradlew test

# Generate coverage report
./gradlew jacocoTestReport
```

#### Writing Java Unit Tests

Example JUnit test for a Java service:

```java
// src/test/java/org/dive25/auth/service/AuthenticationServiceTest.java
package org.dive25.auth.service;

import org.dive25.auth.exception.AuthenticationException;
import org.dive25.auth.model.User;
import org.dive25.auth.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.Mock;
import org.mockito.MockitoAnnotations;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class AuthenticationServiceTest {
    @Mock
    private UserRepository userRepository;
    
    private AuthenticationService authService;
    
    @BeforeEach
    void setUp() {
        MockitoAnnotations.openMocks(this);
        authService = new AuthenticationService(userRepository);
    }
    
    @Test
    void authenticateSuccess() {
        // Arrange
        User user = new User();
        user.setUsername("testuser");
        user.setPassword("$2a$10$hKDVYxLefVHV/vV76kXH5.7IUh/kev5pySg6KWbAhZhPirQIGVZCy"); // "password"
        
        when(userRepository.findByUsername("testuser")).thenReturn(user);
        
        // Act
        User result = authService.authenticate("testuser", "password");
        
        // Assert
        assertNotNull(result);
        assertEquals("testuser", result.getUsername());
        verify(userRepository).findByUsername("testuser");
    }
    
    @Test
    void authenticateFailInvalidUsername() {
        // Arrange
        when(userRepository.findByUsername("wronguser")).thenReturn(null);
        
        // Act & Assert
        assertThrows(AuthenticationException.class, () -> {
            authService.authenticate("wronguser", "password");
        });
    }
    
    @Test
    void authenticateFailInvalidPassword() {
        // Arrange
        User user = new User();
        user.setUsername("testuser");
        user.setPassword("$2a$10$hKDVYxLefVHV/vV76kXH5.7IUh/kev5pySg6KWbAhZhPirQIGVZCy"); // "password"
        
        when(userRepository.findByUsername("testuser")).thenReturn(user);
        
        // Act & Assert
        assertThrows(AuthenticationException.class, () -> {
            authService.authenticate("testuser", "wrongpassword");
        });
    }
}
```

## Integration Testing

Integration tests verify that different components work together correctly.

### Setting Up Integration Tests

Integration tests are kept separate from unit tests and typically require running external dependencies like databases or other services.

For Node.js services, integration tests are in the `integration` directory:

```
src/
  integration/
    document-api.integration.test.ts
    search-api.integration.test.ts
```

### Running Integration Tests

```bash
# Run integration tests
npm run test:integration

# You may need to start dependencies first
docker-compose -f docker-compose.test.yml up -d
```

### Writing Integration Tests

Example integration test for a document API:

```typescript
// src/integration/document-api.integration.test.ts
import request from 'supertest';
import { MongoMemoryServer } from 'mongodb-memory-server';
import mongoose from 'mongoose';
import { app } from '../app';
import { Document } from '../models/document';
import { createTestToken } from './test-utils';

describe('Document API Integration Tests', () => {
  let mongoServer: MongoMemoryServer;
  
  beforeAll(async () => {
    // Start in-memory MongoDB server
    mongoServer = await MongoMemoryServer.create();
    const uri = mongoServer.getUri();
    await mongoose.connect(uri);
    
    // Seed test data
    await Document.create({
      title: 'Test Document',
      content: 'This is a test document',
      classification: 'UNCLASSIFIED',
      createdBy: 'test-user',
      createdAt: new Date()
    });
  });
  
  afterAll(async () => {
    await mongoose.disconnect();
    await mongoServer.stop();
  });
  
  describe('GET /api/v1/documents', () => {
    it('should return a list of documents for authorized user', async () => {
      // Arrange
      const token = createTestToken({ 
        sub: 'test-user',
        clearance: 'SECRET'
      });
      
      // Act
      const response = await request(app)
        .get('/api/v1/documents')
        .set('Authorization', `Bearer ${token}`);
      
      // Assert
      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty('documents');
      expect(response.body.documents).toHaveLength(1);
      expect(response.body.documents[0].title).toBe('Test Document');
    });
    
    it('should return 401 for unauthorized request', async () => {
      // Act
      const response = await request(app)
        .get('/api/v1/documents');
      
      // Assert
      expect(response.status).toBe(401);
    });
  });
});
```

## API Testing

API tests verify that the API behaves as expected and follows the API contract.

### API Testing with Postman

1. **Import the API Collection**:
   - Open Postman
   - Import the collection from `devops/postman/dive25-api-collection.json`

2. **Configure Environment**:
   - Set up environment variables for different environments
   - Include `baseUrl`, `authToken`, etc.

3. **Run API Tests**:
   - Run individual requests
   - Run the entire collection with `Collection Runner`

### Automated API Testing

API tests can be automated as part of the CI/CD pipeline:

```bash
# Run Newman (Postman CLI)
newman run devops/postman/dive25-api-collection.json -e devops/postman/dev-environment.json
```

## End-to-End Testing

End-to-end tests verify complete user flows from frontend to backend.

### End-to-End Testing with Cypress

#### Setting Up Cypress

Cypress is configured in the `web-client` repository:

```bash
cd ~/dive25/web-client
npm install cypress --save-dev
```

#### Running Cypress Tests

```bash
# Open Cypress Test Runner
npm run cypress:open

# Run Cypress tests headlessly
npm run cypress:run
```

#### Writing Cypress Tests

Example Cypress test for document upload flow:

```javascript
// cypress/integration/document-upload.spec.js
describe('Document Upload', () => {
  beforeEach(() => {
    // Log in before each test
    cy.login('test-user', 'password');
    cy.visit('/documents');
  });
  
  it('should upload a document successfully', () => {
    // Click upload button
    cy.get('[data-testid=upload-btn]').click();
    
    // Select file and add metadata
    cy.get('input[type=file]').attachFile('test-document.pdf');
    cy.get('[data-testid=title-input]').type('Cypress Test Document');
    cy.get('[data-testid=classification-select]').select('UNCLASSIFIED');
    
    // Submit form
    cy.get('[data-testid=upload-submit-btn]').click();
    
    // Verify success message
    cy.get('[data-testid=success-message]')
      .should('be.visible')
      .and('contain', 'Document uploaded successfully');
    
    // Verify document appears in list
    cy.get('[data-testid=document-list]')
      .should('contain', 'Cypress Test Document');
  });
  
  it('should show validation errors for missing fields', () => {
    // Click upload button
    cy.get('[data-testid=upload-btn]').click();
    
    // Select file but omit title
    cy.get('input[type=file]').attachFile('test-document.pdf');
    cy.get('[data-testid=classification-select]').select('UNCLASSIFIED');
    
    // Submit form
    cy.get('[data-testid=upload-submit-btn]').click();
    
    // Verify validation error
    cy.get('[data-testid=title-error]')
      .should('be.visible')
      .and('contain', 'Title is required');
  });
});
```

## Security Testing

Security testing focuses on verifying security controls and policies.

### OWASP ZAP Integration

OWASP ZAP can be integrated into the pipeline for automated security scanning:

```bash
# Run ZAP scan in the CI pipeline
docker run -t owasp/zap2docker-stable zap-baseline.py \
  -t https://test.dive25.example.org \
  -c gen.conf \
  -r zap-report.html
```

### API Security Testing

Test authentication and authorization controls:

```typescript
// src/integration/security.integration.test.ts
describe('Security Controls', () => {
  describe('Authorization', () => {
    it('should prevent access to classified documents with insufficient clearance', async () => {
      // Create a token with low clearance
      const token = createTestToken({ 
        sub: 'test-user',
        clearance: 'UNCLASSIFIED'
      });
      
      // Try to access a classified document
      const response = await request(app)
        .get('/api/v1/documents/secret-doc-123')
        .set('Authorization', `Bearer ${token}`);
      
      // Assert
      expect(response.status).toBe(403);
    });
    
    it('should enforce role-based access control', async () => {
      // Create a token without admin role
      const token = createTestToken({ 
        sub: 'test-user',
        roles: ['document_viewer']
      });
      
      // Try to access admin endpoint
      const response = await request(app)
        .get('/api/v1/admin/users')
        .set('Authorization', `Bearer ${token}`);
      
      // Assert
      expect(response.status).toBe(403);
    });
  });
});
```

## Performance Testing

Performance testing measures system performance under load.

### Performance Testing with k6

k6 is used for performance testing.

#### Installing k6

```bash
# Linux
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C5AD17C747E3415A3642D57D77C6C491D6AC1D69
echo "deb https://dl.k6.io/deb stable main" | sudo tee /etc/apt/sources.list.d/k6.list
sudo apt update
sudo apt install k6

# macOS
brew install k6
```

#### Running Performance Tests

```bash
# Run a performance test
k6 run performance/document-api-load-test.js
```

#### Writing Performance Tests

Example k6 test script:

```javascript
// performance/document-api-load-test.js
import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  stages: [
    { duration: '30s', target: 20 },  // Ramp up to 20 users
    { duration: '1m', target: 20 },   // Stay at 20 users for 1 minute
    { duration: '30s', target: 0 },   // Ramp down to 0 users
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'],  // 95% of requests should be below 500ms
  },
};

// Simulate user behavior
export default function() {
  const BASE_URL = 'https://test.dive25.example.org';
  
  // Get auth token (simplified for example)
  const authRes = http.post(`${BASE_URL}/api/v1/auth/login`, {
    username: 'performance-test-user',
    password: 'test-password'
  });
  
  check(authRes, {
    'logged in successfully': (r) => r.status === 200,
  });
  
  const token = authRes.json('token');
  
  // Search for documents
  const searchRes = http.get(`${BASE_URL}/api/v1/documents?query=test`, {
    headers: { 'Authorization': `Bearer ${token}` },
  });
  
  check(searchRes, {
    'search returned successfully': (r) => r.status === 200,
    'search has results': (r) => r.json('documents').length > 0,
  });
  
  sleep(1);
  
  // Get document details
  const docId = searchRes.json('documents')[0].id;
  const docRes = http.get(`${BASE_URL}/api/v1/documents/${docId}`, {
    headers: { 'Authorization': `Bearer ${token}` },
  });
  
  check(docRes, {
    'document retrieved successfully': (r) => r.status === 200,
    'document has title': (r) => r.json('title') !== null,
  });
  
  sleep(2);
}
```

## Continuous Integration Testing

Tests are automatically run in the CI/CD pipeline.

### CI Test Pipeline

The CI pipeline includes the following test stages:

1. **Linting**: Check code style and formatting
2. **Unit Tests**: Run unit tests
3. **Integration Tests**: Run integration tests
4. **API Tests**: Run automated API tests
5. **Security Scanning**: Run security scans
6. **E2E Tests**: Run end-to-end tests
7. **Performance Tests**: Run basic performance tests

Example GitHub Actions workflow:

```yaml
# .github/workflows/test.yml
name: Test

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main, develop ]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Set up Node.js
        uses: actions/setup-node@v2
        with:
          node-version: '16'
      - name: Install dependencies
        run: npm ci
      - name: Run linting
        run: npm run lint

  unit-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Set up Node.js
        uses: actions/setup-node@v2
        with:
          node-version: '16'
      - name: Install dependencies
        run: npm ci
      - name: Run unit tests
        run: npm run test:coverage
      - name: Upload coverage
        uses: codecov/codecov-action@v2
        with:
          file: ./coverage/lcov.info

  integration-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Set up Node.js
        uses: actions/setup-node@v2
        with:
          node-version: '16'
      - name: Start dependencies
        run: docker-compose -f docker-compose.test.yml up -d
      - name: Install dependencies
        run: npm ci
      - name: Run integration tests
        run: npm run test:integration

  e2e-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Set up Node.js
        uses: actions/setup-node@v2
        with:
          node-version: '16'
      - name: Install dependencies
        run: |
          cd web-client
          npm ci
      - name: Start test environment
        run: docker-compose -f docker-compose.test.yml up -d
      - name: Run e2e tests
        run: |
          cd web-client
          npm run cypress:run
```

## Test Data Management

### Test Fixtures

Test fixtures provide consistent test data. Store fixtures in a dedicated directory:

```
src/
  __fixtures__/
    documents.ts
    users.ts
```

Example fixture file:

```typescript
// src/__fixtures__/documents.ts
export const documentFixtures = {
  unclassified: {
    id: 'doc-1',
    title: 'Unclassified Test Document',
    content: 'This is an unclassified test document.',
    classification: 'UNCLASSIFIED',
    createdBy: 'test-user',
    createdAt: new Date('2023-01-01')
  },
  confidential: {
    id: 'doc-2',
    title: 'Confidential Test Document',
    content: 'This is a confidential test document.',
    classification: 'NATO_CONFIDENTIAL',
    createdBy: 'test-user',
    createdAt: new Date('2023-01-02')
  },
  secret: {
    id: 'doc-3',
    title: 'Secret Test Document',
    content: 'This is a secret test document.',
    classification: 'NATO_SECRET',
    createdBy: 'admin-user',
    createdAt: new Date('2023-01-03')
  }
};
```

### Database Seeding

Seed test databases for integration and E2E tests:

```typescript
// src/integration/setup/seed-db.ts
import mongoose from 'mongoose';
import { Document } from '../../models/document';
import { User } from '../../models/user';
import { documentFixtures } from '../../__fixtures__/documents';
import { userFixtures } from '../../__fixtures__/users';

export async function seedDatabase() {
  // Clear collections
  await Document.deleteMany({});
  await User.deleteMany({});
  
  // Insert fixtures
  await Document.insertMany(Object.values(documentFixtures));
  await User.insertMany(Object.values(userFixtures));
  
  console.log('Database seeded');
}
```

## Test Mocking

### Mocking Dependencies

Use Jest's mocking capabilities to mock dependencies:

```typescript
// Mock a module
jest.mock('../services/auth-service');

// Mock a specific function
const mockVerify = jest.fn();
jest.mock('jsonwebtoken', () => ({
  verify: mockVerify,
  sign: jest.fn()
}));

// Mock implementation
mockVerify.mockImplementation((token, secret, options) => {
  if (token === 'valid-token') {
    return { sub: 'test-user', clearance: 'SECRET' };
  }
  throw new Error('Invalid token');
});
```

### Mocking APIs

Use MSW (Mock Service Worker) to mock API calls in frontend tests:

```typescript
// src/mocks/handlers.ts
import { rest } from 'msw';

export const handlers = [
  rest.get('https://api.dive25.local/api/v1/documents', (req, res, ctx) => {
    return res(
      ctx.status(200),
      ctx.json({
        documents: [
          {
            id: 'doc-1',
            title: 'Mocked Document',
            classification: 'UNCLASSIFIED'
          }
        ]
      })
    );
  }),
  
  rest.post('https://api.dive25.local/api/v1/auth/login', (req, res, ctx) => {
    const { username, password } = req.body;
    
    if (username === 'test-user' && password === 'password') {
      return res(
        ctx.status(200),
        ctx.json({
          token: 'mocked-jwt-token',
          user: { id: 'user-1', username: 'test-user' }
        })
      );
    }
    
    return res(
      ctx.status(401),
      ctx.json({
        error: 'Invalid credentials'
      })
    );
  })
];
```

## Test Best Practices

### General Testing Guidelines

1. **Test Isolation**: Each test should be independent of others
2. **Arrange-Act-Assert**: Structure tests with clear setup, action, and verification
3. **Descriptive Test Names**: Use clear names that describe the behavior being tested
4. **Minimize Test Duplication**: Use test helpers and fixtures to reduce duplication
5. **Test Behavior, Not Implementation**: Focus on what the code does, not how it does it
6. **Clean Up After Tests**: Ensure each test cleans up any resources it creates

### Code Coverage Guidelines

- **Unit Tests**: Aim for 80%+ code coverage
- **Critical Components**: Aim for 90%+ code coverage
- **Security Code**: Aim for 100% code coverage

### Continuous Improvement

1. **Test Reviews**: Review tests during code reviews
2. **Quality Metrics**: Track test quality metrics (coverage, pass rate, flakiness)
3. **Test Refactoring**: Regularly refactor tests to improve maintainability
4. **Test Performance**: Optimize slow tests to keep the feedback loop fast

## Troubleshooting Tests

### Common Test Issues

1. **Flaky Tests**: Tests that sometimes pass and sometimes fail
   - **Solution**: Ensure test isolation, avoid race conditions, add retries

2. **Slow Tests**: Tests that take too long to run
   - **Solution**: Use in-memory databases, mock external services, parallelize tests

3. **Test Dependency Issues**: Tests that depend on other tests
   - **Solution**: Ensure proper setup and teardown, avoid global state

### Debugging Tests

```bash
# Debug Jest tests
npm test -- --runInBand --testTimeout=99999

# Debug tests in VS Code
# Add a launch configuration in .vscode/launch.json:
{
  "version": "0.2.0",
  "configurations": [
    {
      "type": "node",
      "request": "launch",
      "name": "Debug Jest Tests",
      "program": "${workspaceFolder}/node_modules/.bin/jest",
      "args": ["--runInBand", "--testTimeout=99999"],
      "console": "integratedTerminal",
      "internalConsoleOptions": "neverOpen"
    }
  ]
}
```

## Related Documentation

- [Contribution Guide](contribution.md)
- [Development Environment Setup](environment.md)
- [API Documentation](../technical/api.md)
- [Security Architecture](../architecture/security.md) 