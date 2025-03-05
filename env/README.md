# DIVE25 Environment Configurations

This directory contains environment-specific configurations for the DIVE25 system.

## Directory Structure

```
env/
├── env.template                 # Template for environment configuration files
├── development/                 # Development environment configuration
│   ├── README.md               # Development environment documentation
│   └── secrets.env             # Development environment variables (optional)
├── staging/                     # Test/Staging environment configuration
│   ├── README.md               # Test environment documentation
│   └── secrets.env             # Test environment variables
├── production/                  # Production environment configuration
│   ├── README.md               # Production environment documentation
│   └── secrets.env             # Production environment variables
└── README.md                    # This file
```

## Environment Management

DIVE25 supports three environments:

1. **Development (DEV)**: Local development environment using Docker Compose
2. **Testing/Staging (TEST)**: Testing environment on Kubernetes
3. **Production (PROD)**: Production environment on Kubernetes

## Configuration Files

Each environment has its own configuration file:

- **DEV**: The main `.env` file in the project root with `ENVIRONMENT=development`
- **TEST**: `env/staging/secrets.env` with `ENVIRONMENT=staging`
- **PROD**: `env/production/secrets.env` with `ENVIRONMENT=production`

## Using the Environment Template

To create a new environment configuration file:

```bash
# Copy the template
cp env/env.template env/[environment]/secrets.env

# Edit the file with environment-specific values
# Set ENVIRONMENT=[environment] in the file
```

## Managing Environments

Use the universal environment setup and deployment script:

```bash
# Setup an environment
./scripts/env-setup.sh -e [environment] -a setup

# Deploy to an environment
./scripts/env-setup.sh -e [environment] -a deploy

# Check status of an environment
./scripts/env-setup.sh -e [environment] -a status

# View logs for a component in an environment
./scripts/env-setup.sh -e [environment] -a logs -c [component]
```

Where `[environment]` is one of: `dev`, `test`, `prod`

## Security Considerations

- Never commit unencrypted sensitive data to version control
- For Kubernetes deployments, use Sealed Secrets
- Use strong, unique passwords for each environment
- Rotate credentials regularly

## Additional Resources

- See each environment's README.md for environment-specific details
- See [URL Management](../URL-MANAGEMENT.md) for domain configuration
- See [Deployment Guide](../README.md#deployment-guide) for deployment instructions 