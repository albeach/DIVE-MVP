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

### For More Documentation

See the [Documentation Index](docs/index.md) for a complete list of available documentation.

## Prerequisites

- Docker and Docker Compose
- Node.js 18+
- npm or yarn

## Getting Started

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/dive25.git
   cd dive25
   ```

2. Copy the example environment file and adjust as needed:
   ```bash
   cp .env.example .env
   # Edit the .env file with your preferred settings
   ```

3. Generate service-specific environment files:
   ```bash
   ./scripts/generate-env-files.sh
   ```

## Local Development with SSL and Custom Domain

To set up a local development environment with the hostname `dive25.local` and secure HTTPS connections:

1. Install mkcert and set up local certificates:

```bash
# Make the setup script executable
chmod +x ./scripts/setup-local-dev-certs.sh

# Run the script (it will ask for sudo password to modify /etc/hosts)
./scripts/setup-local-dev-certs.sh
```

2. Update the Kong configuration to use SSL certificates:

```bash
# Run the update script
chmod +x ./scripts/update-kong-config.sh
./scripts/update-kong-config.sh
```

3. Start the application:

```bash
docker-compose up -d
```

4. Access the application at:

- Main application: https://dive25.local
- API: https://api.dive25.local
- Keycloak: https://keycloak.dive25.local
- MongoDB Express: https://mongo-express.dive25.local
- Grafana: https://grafana.dive25.local
- Konga (Kong Admin): https://konga.dive25.local
- Kong Admin API: https://kong.dive25.local
- Prometheus: https://prometheus.dive25.local
- phpLDAPadmin: https://phpldapadmin.dive25.local

All connections will use HTTPS with valid certificates created by mkcert, so you won't see any browser warnings. 
The SSL termination is handled by Kong, which serves as both the API gateway and the reverse proxy for all services.

## Environment Configuration

DIVE25 uses a centralized approach to environment configuration, with all settings defined in the root `.env` file. This includes:

- URLs and domains for all environments (development, staging, production)
- Authentication credentials and secrets
- Service-specific settings

When updating the `.env` file, you should regenerate the service-specific environment files:

```bash
./scripts/generate-env-files.sh
```

To switch between environments (e.g., from development to staging), update the `ENVIRONMENT` variable in the `.env` file and regenerate the service-specific files.

For more details on URL and domain management, see [URL Management](URL-MANAGEMENT.md).

## Next Steps

After installation, consider consulting:

- [User Guide](docs/user/guide.md) for usage instructions
- [API Documentation](docs/technical/api.md) for backend integration
- [Troubleshooting](docs/deployment/installation.md#troubleshooting) for common issues