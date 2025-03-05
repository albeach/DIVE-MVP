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