# DIVE25 Configuration Management System

## Overview

This document explains the new centralized configuration management system for the DIVE25 platform. The system provides a structured, consistent approach to managing configuration across different environments, with a particular focus on Docker containers, networks, hostnames, and port assignments.

## Core Principles

The configuration system follows these principles:

1. **Centralized Configuration**: All configuration is defined in a single location
2. **Environment Separation**: Clear separation between base configuration and environment-specific settings
3. **Explicit Network Configuration**: Network configurations have explicit subnet definitions
4. **Standardized Naming**: Consistent naming conventions across all components
5. **Automated Generation**: Configuration files are generated from templates

## Directory Structure

The configuration system uses the following directory structure:

```
/config
  ├── base.yml           # Base configuration for all environments
  ├── dev.yml            # Development-specific overrides
  ├── staging.yml        # Staging-specific overrides
  ├── prod.yml           # Production-specific overrides
  ├── templates/         # Templates for generating configuration files
  │   ├── docker-compose.template.yml  # Docker Compose template
  │   └── kong.template.yml            # Kong configuration template
  └── generated/         # Generated environment-specific configurations
      ├── .env.dev       # Generated development .env file
      ├── .env.staging   # Generated staging .env file
      ├── .env.prod      # Generated production .env file
      └── ...            # Other generated files
```

## Configuration Files

### Base Configuration (base.yml)

The base configuration defines settings that are common across all environments:

- Project settings and naming conventions
- Database credentials
- Authentication settings
- Internal port assignments
- Service names for internal communication
- Network configurations with explicit subnets

### Environment-Specific Configuration (dev.yml, staging.yml, prod.yml)

Environment-specific configurations define settings that vary between environments:

- Base domain and protocol (HTTP/HTTPS)
- Subdomain names for each service
- External port assignments
- CORS allowed origins
- SSL/TLS certificate paths
- Logging levels
- Rate limiting settings

## Docker Network Architecture

The system defines four distinct networks with explicit subnet ranges:

1. **Public Network (dive25-public)**:
   - Purpose: Exposes services to the outside world
   - Contains: Kong gateway
   - Subnet: 172.20.0.0/24

2. **Service Network (dive25-service)**:
   - Purpose: Contains application services
   - Contains: Frontend, API, Keycloak, etc.
   - Subnet: 172.20.1.0/24

3. **Data Network (dive25-data)**:
   - Purpose: Contains data stores
   - Contains: MongoDB, PostgreSQL, OpenLDAP, etc.
   - Subnet: 172.20.2.0/24

4. **Admin Network (dive25-admin)**:
   - Purpose: Contains administrative tools
   - Contains: Grafana, Prometheus, phpLDAPadmin, etc.
   - Subnet: 172.20.3.0/24

## Configuration Generation

The `scripts/generate-config.sh` script generates environment-specific configuration files:

1. Merges the base configuration with environment-specific overrides
2. Generates a comprehensive `.env` file with:
   - Internal URLs for service-to-service communication
   - External URLs for browser-to-service communication
   - Authentication connection strings
3. Generates a Docker Compose file using the template
4. Generates a Kong configuration file using the template

### URL Generation

The system generates two types of URLs:

1. **Internal URLs (service-to-service)**:
   - Format: `http://{service-name}:{internal-port}`
   - Example: `http://keycloak:8080`
   - Used for container-to-container communication

2. **External URLs (browser-to-service)**:
   - Format: `https://{subdomain}.{base-domain}:{external-port}`
   - Example: `https://api.dive25.local:3002`
   - Used for browser-to-service communication
   - Omits port number for standard HTTP (80) and HTTPS (443) ports in production

## Kong Configuration

The Kong gateway is configured to route traffic based on hostnames, with each service getting its own subdomain:

- Frontend: `frontend.{base-domain}`
- API: `api.{base-domain}`
- Keycloak: `keycloak.{base-domain}`
- Grafana: `grafana.{base-domain}`
- Etc.

The Kong configuration includes:

- Domain-based routing for all services
- Consistent CORS configuration
- Authentication for admin services
- Rate limiting for API endpoints
- Standard security headers

## Implementation Guide

### Setting Up a New Environment

1. Generate the configuration:
   ```bash
   ./scripts/generate-config.sh [environment]
   ```

2. Apply the configuration:
   ```bash
   cp config/generated/.env.[environment] .env
   cp config/generated/docker-compose.[environment].yml docker-compose.yml
   cp config/generated/kong.[environment].yml kong/kong.yml
   ```

3. Set up hosts file entries (for local development):
   ```bash
   sudo ./scripts/setup-hosts-updated.sh [environment]
   ```

4. Start the services:
   ```bash
   docker-compose down
   docker-compose up -d
   ```

### Adding a New Service

1. Add service configuration to `base.yml`
2. Add domain/port configuration to environment-specific files
3. Update templates as needed
4. Regenerate configuration files
5. Update documentation

## Troubleshooting

If you encounter configuration issues:

1. Check that configuration generation completed successfully
2. Verify network connectivity between containers
3. Check that all required environment variables are present
4. Inspect container logs for configuration-related errors
5. Check that hostnames resolve correctly (for local development)

## Best Practices

1. Always regenerate configuration files after changes
2. Keep templates synchronized with actual service configurations
3. Document any custom settings or requirements
4. Use the standard naming conventions
5. Add new environment-specific settings to all environment files 