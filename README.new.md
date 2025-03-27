# DIVE25 Authentication System

## Overview

DIVE25 is an authentication and authorization system for secure identity verification and access management. The system integrates Kong API Gateway, Keycloak for identity management, and various supporting services.

## Architecture

The refactored architecture follows these key principles:
1. **Modular Design**: Clear separation of concerns with specialized scripts
2. **DB-less Kong Configuration**: Simplified API gateway with declarative configuration
3. **Centralized Management**: Single entry point for deployment and management
4. **Clear Dependencies**: Eliminated circular references between modules
5. **Streamlined Deployment**: Improved reliability and error handling

### Key Components

- **API Gateway**: Kong (DB-less mode) for routing and access control
- **Identity Provider**: Keycloak for authentication and user management
- **Database**: MongoDB for application data, PostgreSQL for Keycloak
- **Directory Service**: OpenLDAP for user directory integration
- **Policy Engine**: OPA (Open Policy Agent) for authorization

## Directory Structure

```
dive25/
├── bin/                       # Executable scripts
│   ├── dive-setup.sh          # Main deployment script
│   ├── dive-cleanup.sh        # Cleanup script
│   ├── dive-test.sh           # Test script
│   └── setup-libs.sh          # Library setup script
├── lib/                       # Modular libraries
│   ├── common.sh              # Common utilities
│   ├── logging.sh             # Logging functions
│   ├── system.sh              # System operations
│   ├── cert.sh                # Certificate management
│   ├── docker.sh              # Docker operations
│   ├── kong.sh                # Kong configuration
│   └── keycloak.sh            # Keycloak configuration
├── config/                    # Configuration files
│   ├── env/                   # Environment configurations
│   ├── kong/                  # Kong configuration
│   └── keycloak/              # Keycloak configuration
├── certs/                     # SSL certificates
├── api/                       # API service
├── frontend/                  # Frontend application
├── keycloak/                  # Keycloak customization
├── kong/                      # Kong customization
├── docker-compose.yml         # Docker Compose definition
└── .env                       # Environment variables
```

## Installation

### Prerequisites

- Docker and Docker Compose
- Bash shell environment
- OpenSSL for certificate generation
- `curl` and `jq` for API interactions

### Quick Start

1. **Setup Libraries**:
   ```bash
   ./bin/setup-libs.sh
   ```

2. **Generate Certificates**:
   ```bash
   ./bin/dive-setup.sh --certs-only
   ```

3. **Deploy the Full Stack**:
   ```bash
   ./bin/dive-setup.sh
   ```

4. **Access Services**:
   - Frontend: https://frontend.dive25.local
   - API: https://api.dive25.local
   - Keycloak Admin: https://keycloak.dive25.local:8443
   - Kong Admin: https://kong.dive25.local:9444

### Deployment Options

The main deployment script supports various options:

```
OPTIONS:
  -h, --help               Show help message
  -e, --env ENV            Set environment (dev, staging, prod)
  -f, --fast               Fast setup with minimal checks
  -c, --clean              Clean existing deployment before setup
  -d, --debug              Enable debug output
  --certs-only             Only generate certificates
  --kong-only              Only configure Kong gateway
  --keycloak-only          Only configure Keycloak
  --verify-only            Only run verification checks
  --skip-checks            Skip health and prerequisite checks
```

## Kong Configuration

The system uses Kong in DB-less mode for simplified deployment and management. Key features:

- **Declarative Configuration**: Uses `kong.yml` for service and route definitions
- **OIDC Integration**: Configured for Keycloak authentication
- **Domain-Based Routing**: Each service accessible via its own subdomain
- **SSL Termination**: All services accessed via HTTPS

## Keycloak Configuration

Keycloak is configured with:

- **Realm Setup**: Default "dive25" realm with predefined clients
- **OIDC Provider**: OpenID Connect settings for API and frontend
- **User Federation**: LDAP integration capability
- **API Access**: Roles and permissions for secured endpoints

## Troubleshooting

Common issues and solutions:

1. **Certificate Issues**:
   ```bash
   ./bin/dive-setup.sh --certs-only --clean
   ```

2. **Kong Configuration Problems**:
   ```bash
   ./bin/dive-setup.sh --kong-only
   ```

3. **Keycloak Not Accessible**:
   ```bash
   ./bin/dive-setup.sh --keycloak-only
   ```

4. **Complete Reset**:
   ```bash
   ./bin/dive-cleanup.sh -a
   ./bin/dive-setup.sh -c
   ```

## Development

For development purposes, you can use the test script to validate your changes:

```bash
./bin/dive-test.sh -l basic       # Basic tests only
./bin/dive-test.sh -l integration # Basic + integration tests
./bin/dive-test.sh -l full        # Complete test suite
```

## License

[MIT License](LICENSE) 