# DIVE25 CI/CD Pipeline Documentation

This document describes the Continuous Integration (CI) and Continuous Deployment (CD) pipeline for the DIVE25 Document Access System.

## Overview

The DIVE25 CI/CD pipeline is implemented using GitHub Actions and automates the following processes:
- Code quality checks (linting and formatting)
- Documentation validation
- Security scanning
- Unit testing
- Integration testing
- End-to-end testing
- Accessibility testing
- Performance testing
- Building Docker images
- Deploying to development, staging, and production environments

## CI/CD Workflow Files

The repository contains two main workflow files:
- `.github/workflows/ci-cd.yaml`: The original CI/CD workflow
- `.github/workflows/enhanced-ci-cd.yaml`: An enhanced workflow with comprehensive testing capabilities

## Pipeline Stages

### 1. Code Quality Checks

#### Linting
- Runs ESLint to ensure code quality across frontend and API components
- Validates code against project style guide
- Checks code formatting with Prettier

#### Documentation Checks
- Validates Markdown links in documentation
- Performs spell-checking on documentation files

### 2. Security Scanning

- Performs dependency scanning using Snyk to identify vulnerabilities
- Runs container scanning with Trivy to find vulnerabilities in container images
- Executes SAST (Static Application Security Testing) with CodeQL to identify code-level security issues

### 3. Testing

#### Unit Tests
- Runs unit tests for each component (frontend and API)
- Collects code coverage information
- Uploads test results as artifacts

#### Integration Tests
- Sets up dependent services like MongoDB, LDAP, etc.
- Tests API endpoints with integrated dependencies
- Verifies system integration points

#### End-to-End Tests
- Runs Playwright tests on multiple browsers (Chrome, Firefox, Safari, Edge)
- Tests the complete user flows
- Includes mobile-responsive testing

#### Accessibility Tests
- Verifies compliance with accessibility standards
- Ensures the application is usable by people with disabilities

#### Performance Tests
- Executes load tests using k6
- Includes constant load and stress testing scenarios
- Verifies API performance under different conditions

### 4. Building Docker Images

- Builds Docker images for each component
- Tags images with appropriate version information
- Pushes images to GitHub Container Registry (ghcr.io)

### 5. Deployment

#### Development Deployment
- Triggered on pushes to the `develop` branch
- Deploys to the development environment
- Runs post-deployment tests to verify functionality

#### Staging Deployment
- Triggered on pushes to `release/*` branches
- Deploys to the staging environment
- Includes user acceptance tests

#### Production Deployment
- Triggered on pushes to the `main` branch
- Implements a canary deployment strategy:
  1. Deploys a canary instance with new code
  2. Runs smoke tests against the canary
  3. Promotes to full deployment if tests pass
  4. Removes canary deployment after successful full deployment

## Notification

- Sends Slack notifications on pipeline completion
- Includes status information (success/failure)

## Pipeline Diagram

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│    Lint     │────▶│  Security   │────▶│  Unit Test  │
└─────────────┘     │    Scan     │     └─────────┬───┘
                    └─────────────┘               │
┌─────────────┐                                   │
│  Docs Lint  │                                   ▼
└─────────────┘                         ┌─────────────────┐
                                        │ Integration Test│
                                        └────────┬────────┘
                                                 │
                    ┌─────────────┐             │
                    │Performance  │◀────┐       │
                    │   Test      │     │       │
                    └─────────────┘     │       │
                                        │       │
┌─────────────┐     ┌─────────────┐     │       │
│     E2E     │────▶│     A11y    │─────┘       │
│    Test     │     │    Test     │             │
└─────────────┘     └─────────────┘             │
                                                 ▼
                                        ┌─────────────────┐
                                        │      Build      │
                                        └────────┬────────┘
                                                 │
                    ┌─────────────┐             │
         ┌─────────▶│Deploy to Dev│             │
         │          └─────────────┘             │
         │                                      │
         │          ┌─────────────┐             │
Branch:   │     ┌──▶│Deploy to    │◀────────────┘
develop   │     │   │   Staging   │
          │     │   └─────────────┘
main ─────┘     │
               ┌┴────────────┐
release/* ─────▶ Deploy to   │
               │ Production  │
               └─────────────┘
```

## Setting Up the Pipeline

To use the enhanced CI/CD pipeline:

1. Ensure your repository has the following secrets configured in GitHub:
   - `KUBE_CONFIG`: Base64-encoded Kubernetes configuration
   - `SNYK_TOKEN`: API token for Snyk security scanning
   - `SLACK_WEBHOOK_URL`: Webhook URL for Slack notifications

2. Make sure your codebase has the required test commands configured in package.json files:
   - `npm run lint`: For linting checks
   - `npm run format:check`: For format verification
   - `npm run test:coverage`: For unit tests with coverage
   - `npm run test:integration`: For integration tests
   - `npm run test:a11y`: For accessibility tests

3. Verify that you have the following Kubernetes resources defined:
   - Namespace configuration
   - Deployment manifests
   - Service definitions
   - Ingress configuration
   - Environment-specific configurations in `k8s/environments/`

## Best Practices

1. **Branch Protection Rules**:
   - Enable branch protection for `main` and `develop`
   - Require pull request reviews and status checks to pass before merging

2. **Feature Branches**:
   - Use feature branches for development work
   - Create pull requests to merge feature branches into `develop`

3. **Release Process**:
   - Create a `release/*` branch from `develop` for release preparation
   - After testing in staging, merge to `main` for production deployment

4. **Handling Failures**:
   - Investigate pipeline failures promptly
   - Fix issues in the appropriate branch based on the failure point

## Extending the Pipeline

The CI/CD pipeline can be extended by:

1. Adding more test types (e.g., contract testing, visual regression testing)
2. Integrating additional security scanning tools
3. Adding compliance checks for specific regulatory requirements
4. Implementing automated rollback mechanisms
5. Adding database migration automation

## Troubleshooting

Common issues and their solutions:

1. **Pipeline timing out**:
   - Optimize test suites to run faster
   - Consider splitting large test jobs into parallel jobs

2. **Docker build failures**:
   - Verify Dockerfile configurations
   - Check dependencies and base images

3. **Deployment failures**:
   - Verify Kubernetes configurations
   - Check service dependencies and environment variables

4. **Test failures**:
   - Inspect test logs for specific error messages
   - Verify test environment configuration

For more assistance, contact the DevOps team or create an issue in the repository. 