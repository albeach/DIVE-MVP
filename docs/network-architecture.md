# DIVE25 Docker Network Architecture

## Overview

This document describes the Docker network architecture used in the DIVE25 platform. The architecture is designed to provide secure, efficient communication between services while maintaining clear separation of concerns.

## Network Design Principles

The network architecture follows these key principles:

1. **Explicit Subnet Definition**: All networks have explicitly defined subnets to prevent IP conflicts
2. **Logical Separation**: Services are grouped into networks based on their function
3. **Controlled Access**: Services only belong to networks they actually need to access
4. **Edge Routing**: External traffic enters through a single edge service (Kong)
5. **Clear Data Flow**: Data and traffic flows follow a clear, documented pattern

## Network Layout

The DIVE25 platform uses four distinct Docker networks:

### 1. Public Network (dive25-public)

- **Purpose**: Exposes services to the outside world
- **Subnet**: 172.20.0.0/24
- **Services**:
  - Kong API Gateway
  - Frontend (through Kong)

### 2. Service Network (dive25-service)

- **Purpose**: Contains application services that need to communicate with each other
- **Subnet**: 172.20.1.0/24
- **Services**:
  - Kong API Gateway
  - Frontend
  - API
  - Keycloak
  - OPA

### 3. Data Network (dive25-data)

- **Purpose**: Contains data storage services
- **Subnet**: 172.20.2.0/24
- **Services**:
  - MongoDB
  - PostgreSQL
  - OpenLDAP
  - Kong Database
  - Services that need to access data stores

### 4. Admin Network (dive25-admin)

- **Purpose**: Contains administrative and monitoring tools
- **Subnet**: 172.20.3.0/24
- **Services**:
  - Grafana
  - Prometheus
  - Konga
  - phpLDAPadmin
  - MongoDB Express
  - Monitoring exporters

## Traffic Flow Patterns

### External Access Pattern

External users access the platform through the following flow:

1. User → Kong Gateway (Public Network)
2. Kong Gateway → Appropriate Service (Service Network)
3. Service → Data Storage (Data Network, if needed)

### Internal Service-to-Service Communication

Services communicate with each other through the following flow:

1. Service A → Service B (via Service Network)
2. Service → Data Storage (via Data Network)

### Admin Access Pattern

Administrators access monitoring and management tools through:

1. Admin → Kong Gateway (Public Network)
2. Kong Gateway → Admin Tool (Admin Network)
3. Admin Tool → Target Service/Data (via appropriate network)

## Network Configuration

The network configuration is defined in the Docker Compose file generated from the template. Here's an example of the network definition:

```yaml
networks:
  # Public-facing network for edge services
  dive25-public:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/24
  
  # Service network for internal application services
  dive25-service:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.1.0/24
  
  # Data network for database services
  dive25-data:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.2.0/24
  
  # Admin network for management services
  dive25-admin:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.3.0/24
```

## Service Network Assignment Table

The following table shows which services are assigned to which networks:

| Service | Public | Service | Data | Admin |
|---------|:------:|:-------:|:----:|:-----:|
| Kong Gateway | ✓ | ✓ | | |
| Frontend | | ✓ | | |
| API | | ✓ | ✓ | |
| Keycloak | | ✓ | ✓ | |
| MongoDB | | | ✓ | |
| PostgreSQL | | | ✓ | |
| OpenLDAP | | | ✓ | |
| Kong DB | | | ✓ | |
| OPA | | ✓ | | |
| Grafana | | ✓ | | ✓ |
| Prometheus | | ✓ | | ✓ |
| Konga | | | ✓ | ✓ |
| MongoDB Express | | | ✓ | ✓ |
| phpLDAPadmin | | | ✓ | ✓ |

## Security Considerations

The network architecture is designed with the following security considerations:

1. **Limited Exposure**: Only Kong is exposed to the public network
2. **Database Isolation**: Database services are isolated in their own network
3. **Admin Isolation**: Admin tools are isolated in their own network
4. **Minimal Network Access**: Services only have access to networks they need

## Troubleshooting Network Issues

### Checking Network Configuration

```bash
# List all networks
docker network ls | grep dive25

# Inspect a specific network
docker network inspect dive25-service

# List containers attached to a network
docker network inspect dive25-service -f '{{range .Containers}}{{.Name}} {{end}}'
```

### Testing Connectivity Between Services

```bash
# Test connectivity from container A to container B
docker exec -it dive25-staging-api ping dive25-staging-mongodb

# Check if a port is accessible
docker exec -it dive25-staging-api curl -i dive25-staging-keycloak:8080
```

### Common Network Issues

1. **Container Can't Reach Another Service**
   - Check that both containers are on the same network
   - Verify the service name being used matches the container name
   - Check for firewall rules or security groups

2. **Subnet Conflicts**
   - Ensure subnets don't overlap with existing networks on the host
   - Check if multiple Docker Compose projects are using the same subnet ranges

3. **DNS Resolution Issues**
   - Docker DNS uses container names for resolution
   - Ensure you're using the container name, not the service name for resolution
   - Try using the container's IP address directly

## Extending the Network Architecture

When adding new services to the DIVE25 platform:

1. Determine which networks the service needs access to
2. Add the service to only the required networks
3. Update the Service Network Assignment Table
4. Test connectivity between the new service and existing services

## References

- [Docker Networking Documentation](https://docs.docker.com/network/)
- [Docker Compose Networking](https://docs.docker.com/compose/networking/)
- [Docker Network Security](https://docs.docker.com/network/security/) 