# Development Environment Configuration

This directory contains configuration files for the development environment of DIVE25.

## Files

- `secrets.env`: Optional environment variables for development deployment. The main development environment uses the root `.env` file, but this file can be used for specialized development configurations.

## Deployment

For the development environment, you primarily use the root `.env` file, but you can use the universal deployment script as well:

```bash
# Set up the development environment
./scripts/env-setup.sh -e dev -a setup

# Deploy to development environment
./scripts/env-setup.sh -e dev -a deploy
```

## Local Development

The development environment is designed for local development and runs using Docker Compose. Follow these steps for local development:

1. **Configure your environment**:
   ```bash
   # Copy the example environment file
   cp ../../.env.example ../../.env
   
   # Edit the .env file to set:
   # - ENVIRONMENT=development
   # - Update credentials as needed
   ```

2. **Generate service-specific environment files**:
   ```bash
   ./scripts/generate-env-files.sh
   ```

3. **Set up local SSL certificates** (optional):
   ```bash
   ./scripts/setup-local-dev-certs.sh
   ```

4. **Start the services**:
   ```bash
   docker-compose up -d
   ```

5. **Access services using the local endpoints**:
   - Frontend: http://localhost:3001 or https://dive25.local (if SSL configured)
   - API: http://localhost:3000 or https://api.dive25.local
   - Keycloak: http://localhost:8080 or https://keycloak.dive25.local
   - MongoDB Express: http://localhost:8081 or https://mongo-express.dive25.local

## Development Workflow

For an effective development workflow:

1. **Run specific services**:
   ```bash
   # Run only the services you need
   docker-compose up -d mongodb api frontend
   ```

2. **View logs in real-time**:
   ```bash
   # View logs for specific services
   docker-compose logs -f api frontend
   ```

3. **Restart services after changes**:
   ```bash
   # Restart specific services
   docker-compose restart api
   ```

4. **Update environment variables**:
   ```bash
   # After updating .env file
   ./scripts/generate-env-files.sh
   
   # Restart services to apply changes
   docker-compose restart
   ```

## Configuration Guidelines

The development environment should be optimized for developer productivity:

1. **Resources**: 
   - Configure services with minimal resources
   - Disable features not needed for development
   - Use smaller database instances

2. **Security**:
   - Use simplified security for faster development
   - Development-only credentials (never use production credentials)
   - Self-signed SSL certificates for HTTPS testing

3. **Data**:
   - Use small, representative test datasets
   - Seed scripts for quickly recreating test data
   - Mock services for external dependencies

## Debugging

For debugging in the development environment:

1. **API debugging**:
   ```bash
   # Start the API with Node inspector
   docker-compose -f docker-compose.debug.yml up api
   ```

2. **Frontend debugging**:
   - Use browser developer tools for frontend debugging
   - React DevTools for component inspection

3. **Database debugging**:
   - Use MongoDB Express at http://localhost:8081
   - Use pgAdmin or similar tools for PostgreSQL

## Testing

Run tests in the development environment:

```bash
# Run API tests
docker-compose exec api npm test

# Run frontend tests
docker-compose exec frontend npm test

# Run E2E tests
npm run e2e
```

## Moving to Staging/Production

When your development work is ready for testing or deployment:

1. Create a feature branch and submit a pull request
2. CI/CD will deploy to the test environment for verification
3. After testing, changes can be promoted to production 