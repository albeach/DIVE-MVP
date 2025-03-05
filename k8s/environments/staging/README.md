# DIVE25 Staging Environment

This directory contains the Kubernetes configuration for the DIVE25 staging environment.

## Overview

The staging environment is designed to mirror the production environment as closely as possible, but with the following differences:

- Fewer replicas for each service
- Lower resource limits and requests
- More verbose logging (debug level)
- Uses the staging domain (staging.dive25.com)

## Directory Structure

```
staging/
├── kustomization.yaml    # Main Kustomize configuration
├── patches/              # Patches to apply to base configurations
│   ├── replicas.yaml     # Replica count for deployments
│   ├── resources.yaml    # Resource limits and requests
│   └── security.yaml     # Security context settings
└── secrets/              # Secret files (not committed to version control)
    ├── mongodb-uri       # MongoDB connection string
    ├── keycloak-client-secret # Keycloak client secret
    └── jwt-secret        # JWT signing secret
```

## Setup

### Prerequisites

- Kubernetes cluster with kubectl configured
- Sealed Secrets controller installed (optional, for secret management)
- Access to the staging environment secrets

### Deployment

You can deploy the staging environment using the provided setup script:

```bash
./scripts/setup-staging.sh --kubernetes
```

Or manually with:

```bash
# Create namespace if it doesn't exist
kubectl create namespace dive25-staging

# Apply Kubernetes configurations
kubectl apply -k k8s/environments/staging
```

### Local Testing with Docker Compose

For local testing of the staging environment, you can use Docker Compose:

```bash
./scripts/setup-staging.sh --docker
```

Or manually with:

```bash
# Build and start the containers
docker-compose -f docker-compose.staging.yml up -d
```

## Accessing the Environment

- Frontend: https://staging.dive25.com (or http://localhost:8083 for local Docker setup)
- API: https://api.staging.dive25.com (or http://localhost:3003 for local Docker setup)

## Secrets Management

Secrets should be managed using Sealed Secrets or a similar solution. To update secrets:

1. Create the secret files in the `secrets/` directory
2. Use the seal-secrets.sh script to seal them:
   ```bash
   ./scripts/seal-secrets.sh dive25-secrets dive25-staging env/staging/secrets.env staging
   ```

## Troubleshooting

If you encounter issues with the staging environment:

1. Check pod status: `kubectl get pods -n dive25-staging`
2. View logs: `kubectl logs -n dive25-staging deployment/staging-api`
3. Check events: `kubectl get events -n dive25-staging` 