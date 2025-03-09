# Kong API Gateway Setup

This directory contains the configuration files and scripts for setting up Kong API Gateway with OIDC authentication via Keycloak.

## Directory Structure

- `Dockerfile` - Custom Kong image with OIDC plugin
- `Dockerfile.config` - Container for configuring Kong
- `kong.yml` - Kong declarative configuration
- `process-config.sh` - Script to process configuration templates
- `configure-oidc.sh` - Script to configure OIDC in Kong
- `configure-ldap.sh` - Script to configure LDAP authentication
- `wait-for-it.sh` - Script to wait for services to be available
- `setup-kong-ssl.sh` - Script to set up SSL certificates for Kong

## SSL Certificates Setup

Kong needs SSL certificates to enable HTTPS. The project includes multiple scripts to generate and configure these certificates:

1. **Option 1:** Run the project-wide setup script:
   ```
   ./scripts/setup-local-dev-certs.sh
   ```

2. **Option 2:** Run the simplified SSL setup script:
   ```
   ./scripts/setup-local-ssl.sh
   ```

3. **Option 3:** Use the Kong-specific SSL setup:
   ```
   ./kong/setup-kong-ssl.sh
   ```

The Kong-specific script will check for existing certificates and generate them if needed.

## Kong Configuration

Kong is configured using a declarative configuration file (`kong.yml`) that includes routes, services, and plugin settings. The configuration process includes:

1. **Template Processing** - Environment variables are substituted in the configuration template
2. **SSL Configuration** - SSL certificates are mounted and configured for HTTPS
3. **OIDC Setup** - The OIDC plugin is configured to work with Keycloak
4. **LDAP Integration** - LDAP authentication is configured for specific routes
5. **Port 8443 Setup** - Special configuration for port 8443 access using the unified script

### Unified Configuration Approach

The `kong-configure-unified.sh` script provides a single, unified approach to Kong configuration, eliminating the need for multiple disparate scripts. Key features:

- **DNS Resolution** - Helps ensure Kong can resolve internal service names
- **Port 8443 Configuration** - Sets up routes for the SSL port
- **OIDC Authentication** - Configures Keycloak authentication with proper cookie settings
- **SSL Configuration** - Sets up proper SSL certificates for secure communication
- **Health Checks** - Validates that Kong and its routes are properly configured

To use the unified configuration script:

```bash
# Run all configuration steps
./kong/kong-configure-unified.sh all

# Reset DNS cache only
./kong/kong-configure-unified.sh dns-reset

# Configure port 8443 only
./kong/kong-configure-unified.sh port-8443

# Configure OIDC authentication
./kong/kong-configure-unified.sh oidc

# Set up SSL certificates
./kong/kong-configure-unified.sh ssl

# Check Kong and service status
./kong/kong-configure-unified.sh status
```

### OIDC Authentication Configuration

Kong uses the OIDC plugin to authenticate users via Keycloak. This configuration involves:

1. Setting up the OIDC plugin on routes and services
2. Configuring the correct redirect URIs between Kong and Keycloak 
3. Managing session cookies and tokens

#### Common OIDC Issues and Solutions

**Redirection Loops**

If you experience redirect loops where the browser keeps redirecting between Kong and Keycloak without completing authentication, it may be due to:

1. Incorrect redirect URI configuration - The OIDC plugin may have malformed redirect_uri values
2. DNS resolution issues - Kong may not be able to resolve Keycloak's hostname
3. Mismatched client configuration in Keycloak

To fix redirection loops:

```bash
# Run the OIDC fix command
./kong/kong-configure-unified.sh fix-oidc
```

This will ensure the redirect URIs are correctly set using the BASE_DOMAIN environment variable without hard-coded values.

## OIDC Configuration

The OIDC plugin configuration is handled by the `configure-oidc.sh` script, which uses a phased approach:

1. **Phase 1:** Apply minimal global OIDC configuration
2. **Phase 2:** Configure service-specific OIDC settings for frontend and API
3. **Verification:** Check all configurations and connectivity

## Troubleshooting

If Kong container keeps restarting, check the following:

1. **SSL Certificate Issues**
   - Ensure certificates are correctly generated and mounted
   - Run `./kong/setup-kong-ssl.sh` to fix SSL certificate issues

2. **OIDC Plugin Issues**
   - Check if the plugin is correctly installed in the Kong container
   - Verify Keycloak connectivity
   - Review Kong logs: `docker logs dive25-kong`

3. **Configuration Issues**
   - Ensure the template processing works correctly
   - Check network connectivity between services
   - Verify environment variables are correctly set

## Restart Kong

After making configuration changes, restart Kong:

```
docker-compose restart kong
```

## Debug Container

A debug container is included for troubleshooting:

```
docker exec -it dive25-kong-debug sh
```

This allows you to inspect logs and configurations without affecting the running Kong instance.

## Port 8443 Configuration

Kong does not directly support port-specific routing through its declarative configuration. To enable access to services through port 8443, use the unified Kong configuration script.

### Using the Unified Configuration Script

The `kong-configure-unified.sh` script provides a single command to manage all Kong configuration tasks:

```bash
# Display help information
./kong-configure-unified.sh help

# Run all configuration steps (DNS reset, port 8443 setup, status check)
./kong-configure-unified.sh all

# Only configure port 8443
./kong-configure-unified.sh port-8443

# Only reset DNS resolution
./kong-configure-unified.sh dns-reset

# Check Kong status and service connectivity
./kong-configure-unified.sh status
```

This script handles:
- DNS resolution for services
- Port 8443 configuration
- Route creation and management
- Health checks and status reports

The script can be customized via environment variables:
```bash
# Use custom values
KONG_ADMIN_URL="http://localhost:8001" BASE_DOMAIN="custom.domain" ./kong-configure-unified.sh all
```

### Manual Configuration

If you prefer to manually configure Kong routes for port 8443, you can use the Kong Admin API directly:

```bash
# For the root domain (Frontend service)
curl -X POST "http://localhost:9444/services/frontend-service/routes" \
  --data "name=frontend-root-domain-8443" \
  --data "hosts[]=dive25.local" \
  --data "preserve_host=true" \
  --data "protocols[]=https"

# For the Frontend subdomain
curl -X POST "http://localhost:9444/services/frontend-service/routes" \
  --data "name=frontend-subdomain-8443" \
  --data "hosts[]=frontend.dive25.local" \
  --data "preserve_host=true" \
  --data "protocols[]=https"

# For the API subdomain
curl -X POST "http://localhost:9444/services/api-service/routes" \
  --data "name=api-subdomain-8443" \
  --data "hosts[]=api.dive25.local" \
  --data "preserve_host=true" \
  --data "protocols[]=https"

# For the Keycloak subdomain
curl -X POST "http://localhost:9444/services/keycloak-service/routes" \
  --data "name=keycloak-subdomain-8443" \
  --data "hosts[]=keycloak.dive25.local" \
  --data "preserve_host=true" \
  --data "protocols[]=https"
```

### Troubleshooting Port 8443 Access

If you're having issues accessing services on port 8443, run the status check:

```bash
./kong-configure-unified.sh status
```

Common troubleshooting steps:
1. Clear your browser cache or try in an incognito window
2. Verify all services are running: `docker ps | grep dive25`
3. Check Kong logs: `docker logs dive25-kong`

## Troubleshooting Port 8443 Configuration

### Common Issues and Solutions

1. **Port Conflicts**: If Kong cannot bind to port 8443, ensure no other services are binding to this port. 

   Check the `.env` file to verify that:
   - `FRONTEND_PORT=3001` (not 8443)
   - `API_PORT=3002` (not 8443)
   - `KEYCLOAK_PORT=3003` (not 8443)
   - `KONG_HTTPS_PORT=8443`
   
   Only Kong should bind to port 8443 as it serves as the reverse proxy for all services.

2. **Port Already in Use**: If you see an error like `Bind for 0.0.0.0:8443 failed: port is already allocated`:
   ```bash
   # Check what's using port 8443
   lsof -i :8443
   
   # Bring down all containers and start again
   docker-compose down
   docker-compose up -d
   ```

3. **DNS Resolution Issues**: If Kong cannot connect to services by hostname:
   ```bash
   # Reset Kong's DNS cache
   ./reset-kong-dns.sh
   ```

Always remember that in the container architecture, services should communicate using their Docker service names (e.g., `frontend`, `api`) rather than IP addresses, which can change between container restarts.

## Configuration Files

The following configuration files are relevant to Kong:

- `kong.yml`: Declarative configuration for Kong
- `kong.conf`: Kong server configuration
- `kong-configure-unified.sh`: Unified script for Kong configuration 