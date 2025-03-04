# DIVE25 Document Access System Documentation

## Overview

The DIVE25 Document Access System is a secure, federated document access system designed for NATO partner nations. It provides secure access to classified documents with proper authentication and authorization controls based on NATO security standards.

The system implements a modern microservices architecture with:

- Authentication via Keycloak (supporting federation with external Identity Providers)
- Directory services through OpenLDAP for user attribute management
- MongoDB for document metadata storage
- Open Policy Agent (OPA) for attribute-based access control (ABAC)
- Kong API Gateway for API management and security
- Full monitoring stack with Prometheus and Grafana
- Modern React-based frontend (Next.js) with responsive design
- RESTful Node.js backend API

## Getting Started

### For New Users

1. [System Overview](architecture/overview.md) - Understand the system components
2. [Installation Guide](deployment/installation.md) - Set up your local environment
3. [User Guide](user/guide.md) - Learn how to use the system

### For Developers

1. [Development Setup](deployment/development.md) - Set up your development environment
2. [API Documentation](technical/api.md) - Understand the API interfaces
3. [Coding Standards](development/standards.md) - Follow our coding conventions

### For System Administrators

1. [Deployment Guide](deployment/guide.md) - Deploy to production
2. [Operations Guide](operations/guide.md) - Day-to-day operations
3. [Security Practices](operations/security.md) - Keep the system secure

## System Setup Guide

### Prerequisites

- Docker and Docker Compose
- Node.js 18+ and npm/yarn
- Git
- (Optional) Kubernetes for production deployment

### Quick Start with Docker Compose

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/dive25.git
   cd dive25
   ```

2. Configure environment variables:
   ```bash
   cp .env.example .env
   # Edit the .env file with your preferred settings
   ```

3. Set up local SSL certificates and hostnames:
   ```bash
   chmod +x ./scripts/setup-local-dev-certs.sh
   ./scripts/setup-local-dev-certs.sh
   ```

4. Start the system:
   ```bash
   docker-compose up -d
   ```

5. Access the system at:
   - Main application: https://dive25.local
   - Backend API: https://api.dive25.local
   - Keycloak Admin: https://keycloak.dive25.local
   - MongoDB Admin: https://mongo-express.dive25.local
   - Grafana Dashboard: https://grafana.dive25.local
   - Kong Admin (Konga): https://konga.dive25.local

### Configuration Options

The system can be configured through the `.env` file with the following sections:

- MongoDB configuration
- Keycloak settings
- API parameters
- Frontend URLs
- LDAP directory settings
- Kong API gateway options
- Monitoring parameters
- Storage paths

## Documentation Sections

### Technical Documentation

- [API Documentation](technical/api.md) - RESTful API endpoints and usage
- [Frontend Documentation](technical/frontend.md) - UI components and state management
- [Authentication Flow](technical/auth-flow.md) - OAuth2/OIDC implementation details
- [Database Schema](technical/database-schema.md) - MongoDB collections and relationships

### Architecture

- [System Architecture Overview](architecture/overview.md) - Component interactions
- [Security Architecture](architecture/security.md) - Security controls and mechanisms
- [Data Flow](architecture/data-flow.md) - Information flow between components
- [Integration Points](architecture/integration.md) - External system connections

### Deployment

- [Installation Guide](deployment/installation.md) - Initial system setup
- [Development Environment](deployment/development.md) - Local development setup
- [Production Deployment](deployment/production.md) - Production environment configuration
- [Kubernetes Deployment](deployment/kubernetes.md) - Deployment to Kubernetes
- [Environment Configuration](deployment/environment-config.md) - Environment variables
- [Scaling Considerations](deployment/scaling.md) - Horizontal and vertical scaling

### Operations

- [Operations Guide](operations/guide.md) - Day-to-day administrative tasks
- [Backup and Recovery](operations/backup-recovery.md) - Data protection procedures
- [Monitoring and Alerting](operations/monitoring.md) - System health monitoring
- [Security Operations](operations/security.md) - Security maintenance
- [Troubleshooting](operations/troubleshooting.md) - Common issues and solutions
- [Upgrades and Patching](operations/upgrades.md) - Keeping the system updated

### User Guides

- [User Guide](user/guide.md) - End-user documentation
- [Administrator Guide](user/admin-guide.md) - System administration
- [Document Management](user/document-management.md) - Working with documents
- [User Management](user/user-management.md) - Managing users and permissions

## Testing

- [Unit Testing](development/unit-testing.md) - Component-level tests
- [Integration Testing](development/integration-testing.md) - System integration tests
- [End-to-End Testing](development/e2e-testing.md) - User workflow tests
- [Security Testing](development/security-testing.md) - Vulnerability assessment

## Contributing

- [Contributing Guidelines](development/contributing.md) - How to contribute
- [Issue Tracking](development/issue-tracking.md) - Reporting bugs and features
- [Pull Request Process](development/pull-requests.md) - Code review workflow