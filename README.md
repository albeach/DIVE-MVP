# DIVE25 Document Access System

DIVE25 is a secure, federated document access system for NATO partners, designed to provide secure access to classified documents with proper authentication and authorization controls.

## Architecture

The system comprises several components:

- **Frontend**: Next.js + Tailwind CSS user interface
- **Backend API**: Node.js API for document access and management
- **Keycloak**: Identity and access management for federation
- **OpenLDAP**: Central directory for user attributes
- **MongoDB**: Document metadata storage
- **Open Policy Agent (OPA)**: Policy enforcement using Rego rules
- **Kong**: API gateway and reverse proxy
- **Prometheus & Grafana**: Monitoring and logging

For a detailed architecture overview, see [System Architecture Documentation](docs/architecture/overview.md).

## Documentation

Comprehensive documentation is available in the `docs` directory:

### Getting Started

- [System Overview](docs/architecture/overview.md) - Understanding the DIVE25 system architecture
- [Installation Guide](docs/deployment/installation.md) - Setting up the system from scratch
- [User Guide](docs/user/guide.md) - Using the DIVE25 system
- [URL Management](URL-MANAGEMENT.md) - How domains and URLs are centrally managed

### Technical Documentation

- [API Documentation](docs/technical/api.md) - RESTful API endpoints and usage

### Troubleshooting

- [Infinite Redirection Fix](docs/troubleshooting/infinite-redirection-fix.md) - Resolving Keycloak/Kong redirection loops
- [Common Issues](docs/troubleshooting/common-issues.md) - Solutions to frequently encountered problems

### For More Documentation

See the [Documentation Index](docs/index.md) for a complete list of available documentation.

## Prerequisites

- Docker and Docker Compose (for local development)
- Node.js 18+
- npm or yarn
- Kubernetes cluster (for TEST and PROD environments)
- kubectl and Kustomize (for Kubernetes deployments)
- Sealed Secrets (for managing secrets in Kubernetes)

## Deployment Guide

The DIVE25 system can be deployed in three environments:
- **DEV**: Local development environment with Docker Compose
- **TEST**: Testing/Staging environment on Kubernetes
- **PROD**: Production environment on Kubernetes

### Universal Deployment Script

For a simpler deployment experience, you can use the universal environment setup and deployment script:

```bash
# Make the script executable
chmod +x ./scripts/env-setup.sh

# Show help information
./scripts/env-setup.sh --help

# Set up the DEV environment
./scripts/env-setup.sh -e dev -a setup

# Deploy to the DEV environment
./scripts/env-setup.sh -e dev -a deploy

# Deploy to the TEST environment
./scripts/env-setup.sh -e test -a deploy

# Check status of the PROD environment
./scripts/env-setup.sh -e prod -a status

# View logs for a specific component in DEV
./scripts/env-setup.sh -e dev -a logs -c api
```

This script handles all environment configuration, deployment, and management across all three environments. You can use it for:
- Setting up environment configurations
- Deploying services
- Restarting services
- Checking environment status
- Viewing logs for specific components

For environment-specific deployment details, see the following sections.

### DEV Environment Deployment

The DEV environment is designed for local development and testing using Docker Compose.

1. **Clone the repository**:
   ```bash
   git clone https://github.com/yourusername/dive25.git
   cd dive25
   ```

2. **Configure environment variables**:
   ```bash
   # Copy the example environment file
   cp .env.example .env
   
   # Edit the .env file to set:
   # - ENVIRONMENT=development
   # - Update credentials as needed
   ```

3. **Generate service-specific environment files**:
   ```bash
   chmod +x ./scripts/generate-env-files.sh
   ./scripts/generate-env-files.sh
   ```

4. **Set up local SSL certificates** (optional for HTTPS):
   ```bash
   chmod +x ./scripts/setup-local-dev-certs.sh
   ./scripts/setup-local-dev-certs.sh
   ```

5. **Start the services**:
   ```bash
   docker-compose up -d
   ```

6. **Verify the deployment**:
   ```bash
   chmod +x ./scripts/test-deployment.sh
   ./scripts/test-deployment.sh
   ```

7. **Access services**:
   - Frontend: http://localhost:3001 or https://dive25.local (if SSL configured)
   - API: http://localhost:3000 or https://api.dive25.local
   - Keycloak: http://localhost:8080 or https://keycloak.dive25.local
   - MongoDB Express: http://localhost:8081 or https://mongo-express.dive25.local
   - Grafana: http://localhost:3100 or https://grafana.dive25.local
   - Prometheus: http://localhost:9090 or https://prometheus.dive25.local
   - phpLDAPadmin: http://localhost:8085 or https://phpldapadmin.dive25.local
   - Kong Admin: http://localhost:8001 or https://kong.dive25.local
   
   **Access services via port 8443**:
   - Frontend: https://dive25.local:8443 or https://frontend.dive25.local:8443
   - API: https://api.dive25.local:8443
   - Keycloak: https://keycloak.dive25.local:8443
   
   To configure port 8443 access:
   ```bash
   # Make the script executable
   chmod +x ./kong/kong-configure.sh
   
   # Run the configuration script
   ./kong/kong-configure.sh
   ```
   
   See [Kong README](kong/README.md) for more details on port 8443 configuration and troubleshooting.

### Staging Environment with Docker Compose

For a lightweight staging environment that can be run locally or on a single server using Docker Compose:

1. **Configure the staging environment**:
   ```bash
   # Make sure you're in the project root directory
   cd dive25
   ```

2. **Start the staging environment**:
   ```bash
   # Make the script executable
   chmod +x start-staging.sh
   
   # Start the staging environment
   ./start-staging.sh
   ```

3. **Access services**:
   - Frontend: http://localhost:8083
   - API: http://localhost:3003
   - Keycloak: http://localhost:8082/auth
   - Kong Admin: http://localhost:8001
   - Konga UI: http://localhost:1337
   - Prometheus: http://localhost:9090
   - Grafana: http://localhost:3100
   - Elasticsearch: http://localhost:9202
   - Minio Console: http://localhost:9005

4. **Stop the staging environment**:
   ```bash
   # Make the script executable
   chmod +x stop-staging.sh
   
   # Stop the staging environment
   ./stop-staging.sh
   ```

### TEST Environment Deployment

The TEST environment is deployed on Kubernetes and used for integration and system testing.

1. **Configure Kubernetes context**:
   ```bash
   # Ensure your kubectl is pointing to the correct cluster
   kubectl config use-context your-test-cluster
   ```

2. **Configure environment variables**:
   ```bash
   # Create or update the test environment secrets
   cp .env.example env/staging/secrets.env
   
   # Edit env/staging/secrets.env to set:
   # - ENVIRONMENT=staging
   # - Update credentials for the TEST environment
   ```

3. **Deploy using the deployment script**:
   ```bash
   chmod +x ./scripts/deploy.sh
   
   # Deploy to TEST environment
   ./scripts/deploy.sh -e staging -a
   ```

4. **Verify the deployment**:
   ```bash
   # Check pod status
   kubectl get pods -n dive25-staging
   
   # Run post-deployment tests
   chmod +x ./scripts/post-deployment-test.sh
   ./scripts/post-deployment-test.sh -e staging
   ```

5. **Access services**:
   - The script will output URLs for accessing the deployed services
   - Default base domain: dive25.local (configure in env/staging/secrets.env)

### PROD Environment Deployment

The PROD environment is the production deployment on Kubernetes with additional security measures.

1. **Configure Kubernetes context**:
   ```bash
   # Ensure your kubectl is pointing to the production cluster
   kubectl config use-context your-prod-cluster
   ```

2. **Configure environment variables**:
   ```bash
   # Create or update the production environment secrets
   cp .env.example env/production/secrets.env
   
   # Edit env/production/secrets.env to set:
   # - ENVIRONMENT=production
   # - Update credentials with strong, unique values
   # - Set production domain names
   ```

3. **Seal sensitive secrets**:
   ```bash
   # Install the Sealed Secrets controller if not already installed
   chmod +x ./scripts/install-sealed-secrets.sh
   ./scripts/install-sealed-secrets.sh
   
   # Seal the production secrets
   chmod +x ./scripts/seal-secrets.sh
   ./scripts/seal-secrets.sh dive25-secrets dive25-prod env/production/secrets.env production
   ```

4. **Deploy using the deployment script**:
   ```bash
   chmod +x ./scripts/deploy.sh
   
   # Deploy to PROD environment
   ./scripts/deploy.sh -e production -a
   ```

5. **Verify the deployment**:
   ```bash
   # Check pod status
   kubectl get pods -n dive25-prod
   
   # Run smoke tests
   chmod +x ./scripts/smoke-test.sh
   ./scripts/smoke-test.sh -e production
   ```

6. **Access services**:
   - The script will output URLs for accessing the deployed services
   - Default base domain: dive25.com (configure in env/production/secrets.env)

### Switching Between Environments

To switch between environments, update the `ENVIRONMENT` variable in your `.env` file:

```bash
# For DEV environment
sed -i 's/ENVIRONMENT=.*/ENVIRONMENT=development/g' .env

# For TEST environment
sed -i 's/ENVIRONMENT=.*/ENVIRONMENT=staging/g' .env

# For PROD environment
sed -i 's/ENVIRONMENT=.*/ENVIRONMENT=production/g' .env
```

Then regenerate the service-specific environment files:

```bash
./scripts/generate-env-files.sh
```

### Environment-Specific Configuration

Each environment has its own configuration stored in:

- **DEV**: `.env` file in the project root
- **TEST**: `env/staging/secrets.env` and `k8s/environments/development`
- **PROD**: `env/production/secrets.env` and `k8s/environments/production`

## Deployment Scripts

The system includes several scripts to help with deployment:

- `scripts/env-setup.sh`: Universal environment setup and deployment script
- `scripts/deploy.sh`: Main deployment script for Kubernetes
- `scripts/generate-env-files.sh`: Generates service-specific environment files
- `scripts/test-deployment.sh`: Tests the local deployment
- `scripts/post-deployment-test.sh`: Tests the Kubernetes deployment
- `scripts/smoke-test.sh`: Runs basic smoke tests
- `scripts/setup-local-dev-certs.sh`: Sets up SSL certificates for local development
- `scripts/seal-secrets.sh`: Seals secrets for Kubernetes deployment

## Authentication Configuration

The authentication flow is handled by Keycloak and secured by Kong's OIDC plugin. The authentication configuration is set up automatically during deployment with the following consolidated scripts:

- `kong/kong-configure-unified.sh`: Unified script for all Kong configuration (routes, DNS, SSL, OIDC)
- `keycloak/configure-keycloak-unified.sh`: Unified script for Keycloak realm, CSP, and issuer configuration
- `keycloak/Dockerfile`: Includes necessary fixes for redirects and port handling
- `keycloak/themes/dive25/login/resources/js/login-config.js`: Fixes all Keycloak redirect issues

### Consolidated Approach

We've adopted a consolidated approach to authentication fixes, integrating all necessary patches directly into the main configuration files rather than applying them as separate scripts. This approach:

1. **Simplifies Deployment**: All fixes are automatically applied during initial setup
2. **Improves Maintainability**: Changes are centralized in a few key files
3. **Ensures Consistency**: All environments get the same fixes

During deployment, the `setup-and-test.sh` script will offer to remove redundant patch scripts using the `scripts/cleanup-patches.sh` utility. This cleans up legacy fix scripts that are no longer needed.

### Built-in Fixes

The following fixes have been incorporated into the main configuration scripts:

#### Kong Configuration

The Kong unified configuration script (`kong-configure-unified.sh`) includes:

1. **Complete Gateway Configuration**:
   - Sets up all services (frontend, API, Keycloak)
   - Creates routes with proper port 8443 mappings
   - Configures SSL certificates for secure communication
   - Resets DNS resolution to ensure proper service discovery
   - Provides status reporting and health checks

2. **OIDC Authentication Configuration**:
   - Configures route-specific authentication to prevent infinite redirection loops
   - Uses consistent session secret across all OIDC plugin instances
   - Sets proper cookie attributes (`SameSite=None`, secure, HttpOnly)
   - Ensures cookies use the correct domain
   - Configures session storage and session lifetime

This unified script replaces multiple separate scripts:
   - `configure-oidc.sh` (OIDC plugin configuration)
   - `fix-kong-config.sh` (Kong configuration fixes)
   - `reset-kong-dns.sh` (DNS resolution fixes)
   - `kong-configure.sh` (port 8443 and route configuration)
   - Other fragmented Kong configuration scripts

#### Keycloak Configuration

The Keycloak configuration has been consolidated into two main components:

1. **Server-Side Configuration** (`configure-keycloak-unified.sh`):
   - Sets up the Keycloak realm with proper configuration
   - Configures Content Security Policy settings for proper iframe embedding
   - Updates issuer URLs to use port 8443 consistently
   - Configures client redirect URIs for frontend and API services
   - Ensures proper token validation across all components
   - Updates environment files (`.env` and `docker-compose.yml`) to use port 8443
   - Generates browser script fixes for frontend runtime configuration

   This unified script replaces multiple separate scripts:
   - `configure-keycloak.sh` (realm configuration)
   - `configure-issuer.sh` (issuer URL)
   - `configure-csp.sh` (content security policy)
   - `update-keycloak-port.sh` (port mapping)
   - `update-keycloak-url.sh` (URL configuration)

2. **Client-Side Fixes** (`login-config.js`):
   - Intercepts the OpenID Configuration responses
   - Rewrites URLs to use port 8443 instead of 4432 or 8080
   - Ensures external URLs use HTTPS protocol
   - Intercepts login form submissions
   - Rewrites any redirects to frontend ports (3000-3002) to use port 8443

### Troubleshooting

If you encounter authentication issues, try the following:

1. Clear your browser cookies and cache
2. Check the Kong logs: `docker logs dive25-kong`
3. Check the Keycloak logs: `docker logs dive25-keycloak`
4. Verify that your hosts file has the correct entries:
   ```
   127.0.0.1 dive25.local frontend.dive25.local api.dive25.local keycloak.dive25.local
   ```
5. Ensure that you're accepting any SSL certificate warnings in your browser

For more detailed information, see the [Authentication Troubleshooting Guide](./docs/troubleshooting/infinite-redirection-fix.md).

## Next Steps

After deployment, consider consulting:

- [User Guide](docs/user/guide.md) for usage instructions
- [API Documentation](docs/technical/api.md) for backend integration
- [Troubleshooting](docs/deployment/installation.md#troubleshooting) for common issues