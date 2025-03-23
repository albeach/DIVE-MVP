# DIVE25 Modular Deployment Scripts

This directory contains the modularized deployment scripts for the DIVE25 authentication system. The scripts have been designed to provide a flexible, maintainable, and robust deployment process.

## Directory Structure

- **`/core`**: Core deployment logic and orchestration
- **`/utils`**: Shared utility functions for logging, system operations, and configuration management
- **`/certificates`**: Certificate generation and CA trust distribution
- **`/network`**: Network configuration and validation
- **`/docker`**: Docker environment management
- **`/kong`**: Kong API gateway configuration
- **`/keycloak`**: Keycloak identity server setup
- **`/verification`**: Health checks and validation
- **`/services`**: Service-specific configurations

## Main Entry Point

The main entry point is `setup.sh` in the root directory. This script orchestrates the deployment process and provides a flexible interface for controlling the deployment options.

## Module Descriptions

### Core Module

The core module contains the main deployment orchestration logic:

- **`core/main.sh`**: Main deployment script that brings together all modules

### Utils Module

The utils module provides shared utility functions:

- **`utils/logging.sh`**: Enhanced logging and output formatting
- **`utils/system.sh`**: System utilities and Docker operations
- **`utils/config.sh`**: Configuration management
- **`utils/distribute-ca-trust.sh`**: CA trust distribution to containers

### Certificates Module

The certificates module handles certificate generation and management:

- **`certificates/cert-manager.sh`**: Certificate generation and verification

### Network Module

The network module handles network configuration and validation:

- **`network/network-utils.sh`**: Network configuration and DNS resolution

### Docker Module

The docker module manages Docker environment:

- **`docker/cleanup.sh`**: Docker environment cleanup

### Kong Module

The Kong module configures the API gateway:

- **`kong/kong-setup.sh`**: Kong gateway configuration including OIDC plugin

### Keycloak Module

The Keycloak module sets up the identity server:

- **`keycloak/keycloak-setup.sh`**: Keycloak server configuration and identity providers

### Verification Module

The verification module performs health checks and validation:

- **`verification/health-checks.sh`**: Comprehensive health checks and validation

## Deployment Flow

1. The `setup.sh` script parses command-line options and sets environment variables
2. Directories are checked and created if needed
3. Based on the selected mode, specific modules are executed:
   - `full`: Runs the entire deployment process
   - `certs`: Only generates certificates
   - `network`: Only configures networking
   - `kong`: Only configures Kong gateway
   - `keycloak`: Only configures Keycloak
   - `verify`: Only runs verification checks
4. The `core/main.sh` script orchestrates the deployment when in `full` mode:
   - Selects environment (dev, staging, prod)
   - Checks and cleans up existing deployment if needed
   - Sets up certificates
   - Starts Docker services
   - Distributes CA trust to containers
   - Configures Kong gateway
   - Configures Keycloak
   - Verifies deployment

## Command-Line Options

The `setup.sh` script supports the following options:

- `-h, --help`: Show help message
- `-e, --env ENV`: Set environment (dev, staging, prod)
- `-f, --fast`: Fast setup with minimal health checks
- `-c, --clean`: Clean up existing deployment before setup
- `-t, --test`: Test mode (skips certain operations)
- `-s, --skip-url-checks`: Skip URL health checks
- `-k, --skip-keycloak`: Skip Keycloak health checks
- `-p, --skip-protocol`: Skip protocol detection
- `-d, --debug`: Enable debug output
- `--certs-only`: Only generate certificates
- `--network-only`: Only configure networking
- `--kong-only`: Only configure Kong gateway
- `--keycloak-only`: Only configure Keycloak
- `--verify-only`: Only run verification checks
- `--quick-test`: Run a full quick test (equivalent to -f -t)

## Module Interactions

The modules interact through the following dependencies:

1. **Certificate Generation** (certificates/cert-manager.sh) must succeed before distributing CA trust and configuring services
2. **Network Configuration** (network/network-utils.sh) must be properly set up before Kong and Keycloak can communicate
3. **Kong Configuration** (kong/kong-setup.sh) must be set up before the OIDC plugin can be configured
4. **Keycloak Configuration** (keycloak/keycloak-setup.sh) must be completed before identity providers and client configurations

## Key Features

- **Path Resolution**: Standardized approach to path resolution across modules
- **Error Handling**: Robust error handling with standardized error codes
- **Logging**: Comprehensive and consistent logging across modules
- **Container Name Resolution**: Smart container name resolution that works across different environments
- **CA Trust Distribution**: Enhanced CA trust distribution that handles different container types
- **Timeout Protection**: Timeout protection for long-running operations
- **Environmental Awareness**: Adaptability to different environments (dev, staging, prod)
- **Verification**: Comprehensive health checks and validation

## SSL and Certificate Infrastructure

The certificate infrastructure is managed by `certificates/cert-manager.sh`, which:

1. Generates a root CA certificate and key
2. Creates wildcard certificates for domains
3. Distributes certificates to containers
4. Verifies certificate trust

CA trust is distributed to containers using `utils/distribute-ca-trust.sh`, which:

1. Detects container OS type
2. Installs certificates using the appropriate method for each OS
3. Verifies certificate installation

## Docker Environment Management

Docker environment is managed by `docker/cleanup.sh`, which:

1. Stops and removes containers
2. Removes networks
3. Optionally removes volumes
4. Cleans up temporary files

## Network Configuration

Network configuration is handled by `network/network-utils.sh`, which:

1. Updates hosts file
2. Checks Docker network connectivity
3. Verifies DNS resolution between containers

## OIDC and Authentication

The OIDC configuration is managed by `kong/kong-setup.sh`, which:

1. Configures Kong routes
2. Sets up the OIDC plugin
3. Configures certificate-bound access tokens
4. Ensures proper communication between Kong and Keycloak

## Best Practices

When working with these scripts:

1. Use the main `setup.sh` entry point to control the deployment
2. Enable debug mode with `-d` for verbose output during troubleshooting
3. Use `--verify-only` to check the deployment without making changes
4. Always run with `-c` (clean) when testing major changes
5. Back up your configuration before making significant changes

## Troubleshooting

Common issues and solutions:

1. **Certificate Trust Issues**: Run `setup.sh --certs-only` followed by verification
2. **Network Issues**: Check DNS resolution with `setup.sh --verify-only`
3. **Kong OIDC Issues**: Verify Kong configuration with `setup.sh --kong-only`
4. **Keycloak Issues**: Check Keycloak configuration with `setup.sh --keycloak-only`
5. **Container Startup Issues**: Use the cleanup script with `setup.sh -c` to start fresh 