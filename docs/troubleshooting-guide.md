# DIVE25 Troubleshooting Guide

This guide provides solutions for common issues encountered when deploying and running the DIVE25 staging environment.

## Database Connection Issues

### MongoDB Connection Issues

**Symptoms:**
- API service shows "MongoDB connection error" in logs
- API service health check fails with 503 status
- MongoDB-dependent features don't work

**Solutions:**

1. **Check MongoDB container status:**
   ```bash
   docker ps | grep mongodb
   ```
   Ensure the container is running and healthy.

2. **Verify network configuration:**
   ```bash
   docker inspect dive25-staging-api | grep -A 10 Networks
   docker inspect dive25-staging-mongodb | grep -A 10 Networks
   ```
   Both containers should be on the `dive25-data` network.

3. **Check MongoDB connection string:**
   The connection string should use the correct container name, credentials, and authentication database:
   ```yaml
   MONGODB_URI: mongodb://dive25_app:app_password@dive25-staging-mongodb:27017/dive25?authSource=dive25
   ```

4. **Verify MongoDB users:**
   ```bash
   docker exec -it dive25-staging-mongodb mongosh -u admin -p admin_password --authenticationDatabase admin --eval "db.getSiblingDB('dive25').getUsers()"
   ```
   Ensure the `dive25_app` user exists with the correct roles.

5. **Test direct connection:**
   ```bash
   docker exec -it dive25-staging-mongodb mongosh -u dive25_app -p app_password --authenticationDatabase dive25 --eval "db.getSiblingDB('dive25').stats()"
   ```
   This should return database statistics without errors.

### PostgreSQL Connection Issues

**Symptoms:**
- Keycloak or Kong shows database connection errors
- Services restart repeatedly
- Database-dependent features don't work

**Solutions:**

1. **Check PostgreSQL container status:**
   ```bash
   docker ps | grep postgres
   ```
   Ensure the containers are running and healthy.

2. **Verify network configuration:**
   ```bash
   docker inspect dive25-staging-keycloak | grep -A 10 Networks
   docker inspect dive25-staging-postgres | grep -A 10 Networks
   ```
   Both containers should be on the `dive25-data` network.

3. **Check database connection settings:**
   For Keycloak:
   ```yaml
   DB_VENDOR: postgres
   DB_ADDR: postgres
   DB_DATABASE: keycloak
   DB_USER: keycloak
   DB_PASSWORD: keycloak
   ```

   For Kong:
   ```yaml
   KONG_PG_HOST: kong-database
   KONG_PG_USER: kong
   KONG_PG_PASSWORD: kong_password
   KONG_PG_DATABASE: kong
   ```

4. **Test direct connection:**
   ```bash
   docker exec -it dive25-staging-postgres psql -U keycloak -d keycloak -c "SELECT 1"
   docker exec -it dive25-staging-kong-database psql -U kong -d kong -c "SELECT 1"
   ```
   These should return "1" without errors.

## Service Startup Issues

### Keycloak Startup Issues

**Symptoms:**
- Keycloak container restarts repeatedly
- Logs show database connection errors
- Authentication doesn't work

**Solutions:**

1. **Check Keycloak logs:**
   ```bash
   docker logs dive25-staging-keycloak
   ```
   Look for specific error messages.

2. **Verify PostgreSQL is ready:**
   Ensure the PostgreSQL container is healthy before Keycloak tries to connect.

3. **Check network configuration:**
   Ensure Keycloak is on the `dive25-data` network to access PostgreSQL.

4. **Verify environment variables:**
   Check that all required environment variables are set correctly.

### Kong Startup Issues

**Symptoms:**
- Kong container restarts repeatedly
- API Gateway is not accessible
- Logs show configuration or database errors

**Solutions:**

1. **Check Kong logs:**
   ```bash
   docker logs dive25-staging-kong
   ```
   Look for specific error messages.

2. **Verify Kong migrations:**
   ```bash
   docker logs dive25-staging-kong-migrations
   ```
   Ensure migrations completed successfully.

3. **Check network configuration:**
   Ensure Kong is on the `dive25-data` network to access its database.

4. **Verify configuration files:**
   Check that the Kong configuration files are correctly generated and mounted.

## Network Issues

### Service Discovery Problems

**Symptoms:**
- Services can't communicate with each other
- Logs show connection refused or host not found errors
- Features dependent on inter-service communication don't work

**Solutions:**

1. **Check Docker networks:**
   ```bash
   docker network ls | grep dive
   ```
   Ensure all required networks exist.

2. **Verify service network configuration:**
   ```bash
   docker inspect dive25-staging-[service_name] | grep -A 10 Networks
   ```
   Ensure services are on the appropriate networks.

3. **Test inter-service connectivity:**
   ```bash
   docker exec -it dive25-staging-[service_name] ping [other_service_name]
   ```
   This should resolve and ping the other service.

4. **Check hostname resolution:**
   ```bash
   docker exec -it dive25-staging-[service_name] nslookup [other_service_name]
   ```
   This should resolve to the correct IP address.

### Port Conflicts

**Symptoms:**
- Services fail to start
- Logs show "address already in use" errors
- External access to services fails

**Solutions:**

1. **Check for port conflicts:**
   ```bash
   sudo lsof -i :[port_number]
   ```
   Identify any processes using the conflicting ports.

2. **Modify port mappings:**
   Edit `config/staging.yml` to use different ports, then regenerate the configuration.

3. **Verify port mappings:**
   ```bash
   docker ps --format "{{.Names}}: {{.Ports}}"
   ```
   Ensure ports are correctly mapped.

## SSL/TLS Issues

**Symptoms:**
- Browser shows certificate warnings
- Services fail to connect securely to each other
- Logs show SSL/TLS handshake errors

**Solutions:**

1. **Check certificate files:**
   ```bash
   ls -la config/generated/certs
   ```
   Ensure certificate files exist and are correctly mounted.

2. **Verify certificate configuration:**
   Check that services are configured to use the correct certificate files.

3. **For browser warnings:**
   These are expected with self-signed certificates. You can temporarily accept the risk or add the certificates to your trusted store.

4. **For service-to-service communication:**
   Ensure services are configured to trust the self-signed certificates or use non-SSL communication internally.

## Volume and Persistence Issues

**Symptoms:**
- Data is lost after container restarts
- Services fail to start due to missing or corrupt data
- Permission errors in logs

**Solutions:**

1. **Check Docker volumes:**
   ```bash
   docker volume ls | grep dive-mvp
   ```
   Ensure all required volumes exist.

2. **Verify volume mounts:**
   ```bash
   docker inspect dive25-staging-[service_name] | grep -A 20 Mounts
   ```
   Ensure volumes are correctly mounted.

3. **Check permissions:**
   ```bash
   docker exec -it dive25-staging-[service_name] ls -la /path/to/mounted/volume
   ```
   Ensure the service has appropriate permissions.

4. **Reset corrupted volumes:**
   As a last resort, you can remove and recreate volumes:
   ```bash
   docker-compose -f config/generated/docker-compose.staging.yml down -v
   docker-compose -f config/generated/docker-compose.staging.yml up -d
   ```
   Note: This will delete all data!

## Platform Compatibility Issues

**Symptoms:**
- Warnings about platform mismatches (linux/amd64 vs. linux/arm64)
- Services fail to start on certain architectures
- Performance issues

**Solutions:**

1. **Acknowledge warnings:**
   Platform mismatch warnings are generally not critical for development/staging environments.

2. **Use platform-specific images:**
   For critical services, look for multi-architecture images or build your own.

3. **Enable Docker BuildKit:**
   ```bash
   export DOCKER_BUILDKIT=1
   ```
   This can help with building multi-architecture images.

## Logging and Monitoring Issues

**Symptoms:**
- Missing or incomplete logs
- Prometheus or Grafana not showing metrics
- Health checks failing

**Solutions:**

1. **Check log configuration:**
   Ensure services are configured with appropriate log levels.

2. **Verify Prometheus targets:**
   Access Prometheus at http://localhost:4437 and check the "Targets" page.

3. **Check Grafana data sources:**
   Access Grafana at https://grafana.dive25.local:4434 and verify data source configuration.

4. **Restart monitoring services:**
   ```bash
   docker-compose -f config/generated/docker-compose.staging.yml restart prometheus grafana
   ```

## Complete Environment Reset

If you encounter persistent issues that can't be resolved through targeted troubleshooting, you can perform a complete reset of the environment:

1. **Stop all services:**
   ```bash
   docker-compose -f config/generated/docker-compose.staging.yml down -v
   ```

2. **Remove generated configuration:**
   ```bash
   rm -rf config/generated/*
   ```

3. **Regenerate configuration:**
   ```bash
   ./scripts/implement-new-config.sh staging
   ```

4. **Start services:**
   ```bash
   docker-compose -f config/generated/docker-compose.staging.yml up -d
   ```

This will give you a clean slate to work with.

## Getting Help

If you've tried the solutions in this guide and are still experiencing issues:

1. **Check the documentation:**
   Review the service-specific documentation for more detailed troubleshooting.

2. **Search for similar issues:**
   Check if others have encountered and resolved similar problems.

3. **Collect diagnostic information:**
   ```bash
   # Collect container status
   docker ps -a > container_status.txt
   
   # Collect logs for all services
   mkdir -p logs
   for container in $(docker ps -a --format "{{.Names}}" | grep dive25-staging); do
     docker logs $container > logs/$container.log 2>&1
   done
   
   # Collect network information
   docker network inspect dive-mvp_dive25-data > network_data.txt
   docker network inspect dive-mvp_dive25-service >> network_data.txt
   docker network inspect dive-mvp_dive25-public >> network_data.txt
   docker network inspect dive-mvp_dive25-admin >> network_data.txt
   
   # Collect volume information
   docker volume ls | grep dive-mvp > volumes.txt
   ```

4. **Report the issue:**
   Provide the collected diagnostic information when reporting the issue. 