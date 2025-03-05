# Test/Staging Environment Configuration

This directory contains configuration files for the test/staging environment deployment of DIVE25.

## Files

- `secrets.env`: Environment variables for test/staging deployment. Contains settings needed for the test environment.

## Deployment

To deploy to the test/staging environment, use the universal deployment script:

```bash
# Set up the test environment
./scripts/env-setup.sh -e test -a setup

# Deploy to test environment
./scripts/env-setup.sh -e test -a deploy
```

## Purpose

The test/staging environment serves multiple purposes:

1. **Integration Testing**: Validate that all components work together correctly
2. **User Acceptance Testing**: Allow stakeholders to test new features before production
3. **Performance Testing**: Run load and stress tests in an environment similar to production
4. **Deployment Validation**: Test the deployment process before applying to production

## Configuration Guidelines

Configure the test environment to closely mirror production while considering these differences:

1. **Resources**: 
   - Use smaller resource allocations (CPU, memory)
   - Fewer replicas of each service
   - Smaller database instances

2. **Security**:
   - Still use encrypted secrets, but distinct from production credentials
   - Test-specific API keys and tokens
   - Separate SSL certificates (can be self-signed for testing)

3. **Data**:
   - Use anonymized copies of production data or generated test data
   - Never use actual production credentials or sensitive customer data

## Environment Variables

Test environment variables are stored in `secrets.env`. This file should be created from the template and populated with test values:

```bash
cp ../../.env.example ./secrets.env
```

Configure the following variables specifically for the test environment:

- Set `ENVIRONMENT=staging`
- Update `STAGING_BASE_DOMAIN` to the test domain (e.g., `dive25.local` or `test.dive25.com`)
- Set appropriate test passwords for all services
- Configure CORS settings for test domains
- Update external service endpoints to point to test instances

## Kubernetes Configuration

The Kubernetes configuration for the test environment is stored in `k8s/environments/development`. This includes:

- Appropriate resource limits and requests for test workloads
- Ingress configurations for test domains
- PersistentVolume claims for data persistence

## Testing and Validation

After deployment to the test environment, run comprehensive tests:

```bash
# Run post-deployment tests
./scripts/post-deployment-test.sh -e staging

# Run E2E tests
./scripts/run-e2e-tests.sh -e staging

# Run performance tests
./scripts/run-performance-tests.sh -e staging
```

## Promotion to Production

When testing is complete and the deployment is validated, promote the changes to production:

```bash
# Deploy to production using the same configuration
./scripts/env-setup.sh -e prod -a deploy
```

Always maintain a change log of features and fixes deployed to the test environment and their status before promoting to production. 