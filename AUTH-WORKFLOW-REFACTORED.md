# Authentication Workflow Refactoring

This document outlines the changes made to refactor the authentication workflow in the DIVE25 application to properly leverage Kong as a reverse proxy and Keycloak for authentication.

## Key Changes

### 1. Unified Authentication Through Kong

- All external traffic now routes through Kong HTTPS on port 8443
- API authentication now relies on Kong's OIDC plugin for token validation
- Consistent redirect URI paths for callback and logout endpoints

### 2. API Middleware Simplification

- Removed redundant token verification in the API middleware
- Now trusts Kong for token validation, eliminating duplicate verification
- Added handling for user info passed through Kong headers
- Maintains a fallback mechanism for direct API calls (not through Kong)

### 3. Frontend Keycloak Integration

- Updated redirect URI handling to consistently use `/callback` path
- Ensured all Keycloak traffic in production routes through Kong
- Direct Keycloak access preserved for local development
- Improved logout flow with proper redirect handling

### 4. Kong Configuration Updates

- Added OIDC plugin to the API service 
- Configured Kong to pass validated user info to the API
- Enabled token introspection for stronger validation
- Set proper priorities for authentication-related routes

## Architecture

```
[Browser] ----HTTPS:8443----> [Kong] ----HTTP----> [Frontend/API/Keycloak]
    |                           |
    |                           v
    |                      [Keycloak] <-- Token validation
    |                           |
    |                           v
    +----------------------> [API] <-- User info from token/headers
```

## Authentication Flow

1. User accesses the application through Kong HTTPS (port 8443)
2. Kong routes to the appropriate service (frontend, API, Keycloak)
3. Authentication requests are handled by Kong's OIDC plugin
4. After successful authentication, Kong validates subsequent requests
5. User info is passed to the API via headers
6. API middleware trusts Kong's token validation and processes request

## Best Practices Implemented

1. **Single Source of Truth**: Token validation happens only once in Kong
2. **Secure Communication**: All external traffic routes through HTTPS
3. **Clean Separation**: Authentication logic is now primarily handled by Kong and Keycloak
4. **Fallback Mechanisms**: Graceful degradation if Kong headers are absent
5. **Consistent Redirect URIs**: Unified callback paths through Kong

## Troubleshooting

If authentication issues occur:

1. Check that Kong is configured with the OIDC plugin for API routes
2. Verify Keycloak client configuration has the correct redirect URIs
3. Ensure all external access uses the Kong HTTPS endpoint on port 8443
4. Check network connectivity between services (Kong, API, Keycloak)
5. Verify SSL certificates are properly configured

## Environment Variables

Key environment variables:

- `NEXT_PUBLIC_KONG_URL`: The Kong external URL (e.g., `https://dive25.local:8443`)
- `NEXT_PUBLIC_KEYCLOAK_URL`: Direct Keycloak URL for local development
- `NEXT_PUBLIC_KEYCLOAK_REALM`: Keycloak realm (default: `dive25`)
- `NEXT_PUBLIC_KEYCLOAK_CLIENT_ID`: Client ID (default: `dive25-frontend`)
- `NEXT_PUBLIC_ENV`: Environment (`production`, `staging`, `development`) 