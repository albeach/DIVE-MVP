# DIVE25 Network Debugging Toolkit

This directory contains tools for debugging networking issues in the DIVE25 microservice architecture.

## Available Tools

### 1. Network Debugging Container

A dedicated container (`netdebug`) with comprehensive networking tools is included in the Docker Compose setup. This container:

- Is based on the `nicolaka/netshoot` image, which includes a wide range of networking utilities
- Is connected to all Docker networks in the DIVE25 environment
- Has persistent storage for debugging scripts
- Remains running as long as the Docker Compose environment is up

### 2. Debugging Scripts

#### `test-connectivity.sh`
Performs comprehensive connectivity tests between all services:
- DNS resolution tests
- HTTP connectivity tests to all services
- Network route tracing
- Container status information

Usage:
```bash
docker exec -it dive25-[env]-netdebug /scripts/test-connectivity.sh
```

#### `diagnose-kong.sh`
Specialized tool for diagnosing Kong API Gateway issues:
- Checks Kong's operational status
- Lists configured routes and services
- Tests DNS resolution of service hosts
- Verifies TCP connectivity to backend services
- Displays enabled plugins
- Provides troubleshooting suggestions

Usage:
```bash
docker exec -it dive25-[env]-netdebug /scripts/diagnose-kong.sh
```

## Adding Custom Scripts

You can add custom debugging scripts to this directory. They will be available inside the `netdebug` container at `/scripts`.

## Entering the Debug Container

To enter the debug container for interactive troubleshooting:

```bash
docker exec -it dive25-[env]-netdebug bash
```

Replace `[env]` with your environment name (dev, staging, prod).

## Common Troubleshooting Commands

### Check DNS Resolution
```bash
docker exec -it dive25-[env]-netdebug dig [service-name]
```

### Test HTTP Connectivity
```bash
docker exec -it dive25-[env]-netdebug curl -v http://[service-name]:[port]/
```

### Trace Network Routes
```bash
docker exec -it dive25-[env]-netdebug traceroute [service-name]
```

### Port Scanning
```bash
docker exec -it dive25-[env]-netdebug nmap -p [port-range] [service-name]
``` 