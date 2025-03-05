# URL and Domain Management

## Our Balanced Approach: "Hardcoded Defaults with Environment Overrides"

The DIVE25 system uses a balanced approach to URL and domain management that combines clarity and flexibility:

### Core Principles

1. **Hardcoded Defaults**: Every configuration file includes sensible hardcoded defaults
2. **Environment Overrides**: Environment variables can override these defaults when needed
3. **Clear Documentation**: Default values are explicitly documented in the code
4. **No Computation**: We avoid complex calculated URLs in configuration files

### Benefits of This Approach

- **Reliability**: Code works out-of-the-box without requiring environment setup
- **Maintainability**: Default values are clearly visible in the code
- **Flexibility**: Environment variables allow customization when needed
- **Consistency**: URLs are configured in a predictable way across services
- **Debuggability**: Default values make it easy to understand the expected configuration

## Implementation Details

### Configuration Files

Each service has its own configuration with sensible defaults:

#### API Configuration (`api/src/config/index.js`)

```javascript
// Default values defined in a central defaults object
const defaults = {
    // URLs and domains
    frontendUrl: 'https://dive25.local',
    apiUrl: 'https://api.dive25.local',
    keycloakUrl: 'https://keycloak.dive25.local/auth',
    // ...
};

// Export with environment variable overrides
module.exports = {
    // Configuration with defaults as fallbacks
    frontendUrl: process.env.FRONTEND_URL || defaults.frontendUrl,
    // ...
};
```

#### Frontend Configuration (`frontend/src/lib/keycloak.ts`)

```typescript
// Hardcoded default values
const DEFAULT_KEYCLOAK_URL = 'https://keycloak.dive25.local/auth';
const DEFAULT_REALM = 'dive25';
const DEFAULT_CLIENT_ID = 'dive25-frontend';

// Initialize with environment overrides
const keycloakUrl = process.env.NEXT_PUBLIC_KEYCLOAK_URL || DEFAULT_KEYCLOAK_URL;
```

### Environment Files

We maintain a central `.env` file with explicit URL definitions:

```bash
# Explicitly defined URLs (no computations)
PUBLIC_FRONTEND_URL=https://dive25.local
PUBLIC_API_URL=https://api.dive25.local
PUBLIC_KEYCLOAK_URL=https://keycloak.dive25.local
```

### Helper Scripts

The `scripts/generate-env-files.sh` script distributes configuration to services:

1. Loads values from `.env` if available
2. Falls back to hardcoded defaults if not
3. Generates service-specific environment files

## Best Practices for Development

1. **Local Development**: Use the default URLs with appropriate `/etc/hosts` entries
2. **Custom Environments**: Override defaults by setting environment variables
3. **Production Deployment**: Always provide explicit environment variables
4. **Testing**: Tests should use the default values for predictability

## Key Concepts

### Internal vs. External URLs

The system distinguishes between two types of URLs:

1. **Internal URLs** - Used for container-to-container communication within the Docker network
   - Example: `http://keycloak:8080` - The containers can communicate using service names
   - Format: `http://<service-name>:<internal-port>`

2. **External URLs** - Used for browser-to-service communication
   - Example: `http://localhost:8080` - The browser needs to use addresses it can resolve
   - Format: `http(s)://<domain>:<external-port>`

### Environment-Specific Configuration

URLs and domains are environment-specific. The system supports:

- **Development**: Typically using `localhost` with different ports
- **Staging**: Using `dive25.local` domains
- **Production**: Using `dive25.com` domains

## Configuration Files

### Central Configuration

All URLs and domains are defined in the root `.env` file, which contains:

- Base domains for each environment
- Port configurations
- Protocol settings (HTTP/HTTPS)
- Internal and external URLs
- Other environment-specific settings

### Generated Configuration Files

The environment files for individual services (e.g., `frontend/.env.local`) are generated from the central `.env` file using the `scripts/generate-env-files.sh` script.

## URL Generation

The URL generation strategy follows these steps:

1. Define base variables for each environment in `.env`:
   ```
   DEV_BASE_DOMAIN=localhost
   DEV_USE_HTTPS=false
   DEV_FRONTEND_PORT=3001
   ```

2. Generate full URLs based on these variables:
   ```
   PUBLIC_FRONTEND_URL=${DEV_USE_HTTPS ? "https" : "http"}://${DEV_BASE_DOMAIN}:${DEV_FRONTEND_PORT}
   ```

3. Propagate these URLs to service-specific environment files.

## Handling Different Environments

To switch environments:

1. Update the `ENVIRONMENT` variable in `.env`
2. Run `./scripts/generate-env-files.sh` to regenerate all service environment files
3. Restart the services with `docker-compose down && docker-compose up -d`

## Guidelines for Developers

When adding new services or modifying existing ones:

1. **Never hardcode URLs** in configuration files or code
2. **Always use environment variables** for URLs and domains
3. **Update the central configuration** in `.env` when adding new services
4. **Update the generation script** to include new environment files
5. **Document any special URL requirements** in this file

## Common Patterns

### In Docker Compose

```yaml
services:
  my-service:
    environment:
      - INTERNAL_API_URL=${INTERNAL_API_URL}
      - PUBLIC_FRONTEND_URL=${PUBLIC_FRONTEND_URL}
```

### In Frontend Code

```javascript
const apiUrl = process.env.NEXT_PUBLIC_API_URL;
```

### In Backend Code

```javascript
const keycloakUrl = process.env.KEYCLOAK_AUTH_SERVER_URL;
```

## Troubleshooting

If you encounter URL-related issues:

1. Check that you're using the correct URL type (internal vs. external)
2. Verify that all environment files are up-to-date (`./scripts/generate-env-files.sh`)
3. Ensure that the service has the necessary environment variables
4. Check network connectivity between services
5. Verify that the URLs are correctly formatted for the current environment 