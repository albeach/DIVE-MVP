# Migration Guide: Docker Configuration Refactoring

This guide walks you through the process of migrating from the old Docker configuration system to the new centralized configuration system.

## Overview of Changes

The new configuration system addresses several issues with the old approach:

1. **Old**: Inconsistent container naming and hostname conventions  
   **New**: Standardized naming pattern `{project}-{environment}-{service}`

2. **Old**: Undefined network subnets leading to potential IP conflicts  
   **New**: Explicit subnet definitions with logical network separation

3. **Old**: Inconsistent port mapping and direct exposure of services  
   **New**: Standardized port allocation and centralized access through Kong

4. **Old**: Complex Kong configuration with overlapping routes  
   **New**: Hostname-based routing with clear service boundaries

5. **Old**: Multiple .env files with redundant definitions  
   **New**: Centralized configuration with environment-specific overrides

## Migration Steps

### Step 1: Backup Your Existing Configuration

```bash
# Backup your .env file
cp .env .env.backup

# Backup your docker-compose.yml
cp docker-compose.yml docker-compose.yml.backup

# Backup your Kong configuration
cp kong/kong.yml kong/kong.yml.backup
```

### Step 2: Install the New Configuration System

```bash
# Ensure the configuration directories exist
mkdir -p config/{dev,staging,prod,generated,templates}

# Copy the configuration templates
cp config/templates/docker-compose.template.yml config/templates/
cp config/templates/kong.template.yml config/templates/

# Copy the base and environment-specific configurations
cp config/base.yml config/
cp config/dev.yml config/
cp config/staging.yml config/
cp config/prod.yml config/

# Make the configuration scripts executable
chmod +x scripts/generate-config.sh
chmod +x scripts/setup-hosts-updated.sh
```

### Step 3: Generate the New Configuration

```bash
# Choose your environment (dev, staging, or prod)
export ENVIRONMENT=staging

# Generate the configuration
./scripts/generate-config.sh $ENVIRONMENT

# Apply the configuration
cp config/generated/.env.$ENVIRONMENT .env
cp config/generated/docker-compose.$ENVIRONMENT.yml docker-compose.yml
cp config/generated/kong.$ENVIRONMENT.yml kong/kong.yml
```

### Step 4: Update Host Entries (for Local Development)

```bash
# Update your hosts file entries
sudo ./scripts/setup-hosts-updated.sh $ENVIRONMENT
```

### Step 5: Migrate Your Data (Optional)

If you need to migrate data from existing containers to the new ones:

```bash
# For MongoDB data (example)
docker run --rm -v dive25_mongo_data:/from -v dive25-staging-mongo_data:/to alpine ash -c "cd /from && cp -av . /to"

# For PostgreSQL data (example)
docker run --rm -v dive25_postgres_data:/from -v dive25-staging-postgres_data:/to alpine ash -c "cd /from && cp -av . /to"
```

### Step 6: Start Services with New Configuration

```bash
# Stop existing services
docker-compose down

# Start services with new configuration
docker-compose up -d
```

### Step 7: Verify the Migration

1. Check that all services are running:
   ```bash
   docker-compose ps
   ```

2. Verify connectivity to services:
   ```bash
   # Check Kong gateway
   curl -I https://kong.dive25.local:8443

   # Check Keycloak
   curl -I https://keycloak.dive25.local:8443
   ```

3. Test authentication flow through the new Kong configuration

4. Check container logs for any errors:
   ```bash
   docker-compose logs -f
   ```

## Common Issues and Solutions

### Issue: Services Cannot Communicate

**Symptoms**: Services cannot reach each other even though they're running.

**Solution**: 
1. Check network configuration in `docker-compose.yml`
2. Verify service names are correct in internal URLs
3. Ensure containers are on the same network when needed

```bash
# Inspect networks
docker network ls
docker network inspect dive25-staging-service

# Check container connectivity
docker exec -it dive25-staging-api ping dive25-staging-mongodb
```

### Issue: Hostname Resolution Fails

**Symptoms**: Browser cannot reach services by hostname.

**Solution**:
1. Verify hosts file entries: `cat /etc/hosts | grep dive25`
2. Check Kong configuration for correct hostnames
3. Restart local DNS cache if needed

### Issue: Authentication Flow Breaks

**Symptoms**: Login fails or redirects incorrectly.

**Solution**:
1. Check Keycloak configuration: `docker-compose logs keycloak`
2. Verify Kong OIDC plugin configuration
3. Check frontend environment variables for correct authentication URLs

## Reverting the Migration

If you need to revert to the old configuration:

```bash
# Restore your .env file
cp .env.backup .env

# Restore your docker-compose.yml
cp docker-compose.yml.backup docker-compose.yml

# Restore your Kong configuration
cp kong/kong.yml.backup kong/kong.yml

# Restart services
docker-compose down
docker-compose up -d
```

## Additional Resources

- [Configuration Management Documentation](./configuration-management.md)
- [Docker Networking Guide](https://docs.docker.com/network/)
- [Kong Configuration Reference](https://docs.konghq.com/gateway/latest/reference/configuration/)
- [Keycloak Documentation](https://www.keycloak.org/documentation) 