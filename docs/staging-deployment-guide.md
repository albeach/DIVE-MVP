# DIVE25 Staging Environment Deployment Guide

This guide provides a comprehensive walkthrough of the deployment process for the DIVE25 staging environment. It covers all the necessary steps, from configuration to starting the services.

## Prerequisites

- Docker and Docker Compose installed
- Git repository cloned
- Sudo access for modifying hosts file (if needed)

## Deployment Process

### 1. Configuration Setup

The deployment process begins with setting up the configuration files:

```bash
# Navigate to the project root directory
cd /path/to/DIVE-MVP

# Generate the configuration for the staging environment
./scripts/implement-new-config.sh staging
```

This script performs the following actions:
- Reads the base configuration from `config/base.yml`
- Applies staging-specific overrides from `config/staging.yml`
- Generates configuration files in the `config/generated` directory

### 2. Network Configuration

The system uses several Docker networks to isolate and secure communication between services:

- `dive25-public`: For services exposed to the public
- `dive25-service`: For internal service-to-service communication
- `dive25-data`: For database connections
- `dive25-admin`: For administrative services

### 3. Host Configuration

Add the following entries to your `/etc/hosts` file to enable local domain resolution:

```
127.0.0.1 dive25.local
127.0.0.1 api.dive25.local
127.0.0.1 frontend.dive25.local
127.0.0.1 keycloak.dive25.local
127.0.0.1 kong.dive25.local
127.0.0.1 grafana.dive25.local
```

### 4. Starting the Services

Start all services using Docker Compose:

```bash
# From the project root directory
docker-compose -f config/generated/docker-compose.staging.yml up -d
```

This command starts all the containers defined in the Docker Compose file in detached mode.

### 5. Service Verification

Verify that all services are running correctly:

```bash
docker ps
```

Check for any containers that are not in a healthy state or are restarting.

### 6. Troubleshooting Common Issues

#### Database Connection Issues

If services can't connect to their databases, ensure:
1. The database containers are running and healthy
2. The service is on the same network as its database (`dive25-data`)
3. The connection string uses the correct container name, credentials, and authentication database

Example fix for API service:
```yaml
MONGODB_URI: mongodb://dive25_app:app_password@dive25-staging-mongodb:27017/dive25?authSource=dive25
```

#### Network Issues

If services can't communicate with each other:
1. Ensure they share the appropriate network
2. Check that hostnames in configuration match the container names
3. Verify that ports are correctly mapped and not conflicting

#### Port Conflicts

If you encounter port conflicts:
1. Check if any other services are using the same ports
2. Modify the port mappings in `config/staging.yml`
3. Regenerate the configuration and restart the services

### 7. Accessing the Services

Once deployed, the services are available at the following URLs:

- Frontend: https://frontend.dive25.local:3001
- API: https://api.dive25.local:3002
- Keycloak: https://keycloak.dive25.local:8443
- Kong API Gateway: https://kong.dive25.local:8443
- Grafana: https://grafana.dive25.local:4434
- MongoDB Express: http://localhost:4435
- phpLDAPadmin: http://localhost:4436
- Prometheus: http://localhost:4437
- Konga (Kong Admin): http://localhost:4439

Note: You may encounter SSL/TLS certificate warnings as the deployment uses self-signed certificates.

### 8. Service Dependencies

The services have the following dependencies:

- API Service: MongoDB, Keycloak, OPA, OpenLDAP
- Frontend: API Service, Keycloak
- Keycloak: PostgreSQL
- Kong: Kong Database (PostgreSQL)
- Konga: Kong Database (PostgreSQL)
- Grafana: Prometheus
- MongoDB Express: MongoDB
- phpLDAPadmin: OpenLDAP

### 9. Shutting Down

To stop all services:

```bash
docker-compose -f config/generated/docker-compose.staging.yml down
```

To stop and remove all volumes (will delete all data):

```bash
docker-compose -f config/generated/docker-compose.staging.yml down -v
```

## Configuration Files

### Base Configuration

The `config/base.yml` file contains the default configuration for all environments.

### Staging Configuration

The `config/staging.yml` file contains staging-specific overrides, including:

- Port mappings
- Database credentials
- Environment-specific settings
- Service configurations

### Generated Configuration

The deployment process generates several files in the `config/generated` directory:

- `docker-compose.staging.yml`: The Docker Compose file for the staging environment
- Service-specific configuration files for MongoDB, Keycloak, Kong, etc.

## Maintenance

### Updating Configuration

To update the configuration:

1. Modify the appropriate configuration file (`config/base.yml` or `config/staging.yml`)
2. Regenerate the configuration:
   ```bash
   ./scripts/implement-new-config.sh staging
   ```
3. Restart the affected services or all services:
   ```bash
   docker-compose -f config/generated/docker-compose.staging.yml restart [service_name]
   ```

### Viewing Logs

To view logs for a specific service:

```bash
docker logs dive25-staging-[service_name]
```

For continuous log monitoring:

```bash
docker logs -f dive25-staging-[service_name]
```

### Backing Up Data

The system uses Docker volumes for persistent data storage. To back up data:

1. Stop the services:
   ```bash
   docker-compose -f config/generated/docker-compose.staging.yml down
   ```

2. Back up the volumes:
   ```bash
   docker volume ls | grep dive-mvp
   # Use docker volume backup tools or copy the data directly
   ```

3. Restart the services:
   ```bash
   docker-compose -f config/generated/docker-compose.staging.yml up -d
   ```

## Platform Compatibility Notes

When deploying on ARM-based systems (like M1/M2 Macs), you may encounter platform compatibility warnings for some images that were built for `linux/amd64` but are running on `linux/arm64`. These warnings are generally not critical, but may affect performance.

Affected services include:
- OPA
- MongoDB Exporter
- Konga

## Security Considerations

The staging environment uses self-signed certificates for HTTPS. In a production environment, you should:

1. Use proper CA-signed certificates
2. Secure all admin interfaces with strong passwords
3. Restrict network access to administrative services
4. Regularly update all container images
5. Follow the principle of least privilege for service accounts

## Conclusion

This guide provides a comprehensive overview of the DIVE25 staging environment deployment process. By following these steps, you can successfully deploy and maintain the staging environment. 