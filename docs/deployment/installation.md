# DIVE25 Installation Guide

This guide walks through the complete installation process for the DIVE25 Document Access System, from setting up prerequisites to accessing the system components.

## Prerequisites

Before proceeding with the installation, ensure your system meets the following requirements:

### System Requirements

- **Operating System:** Linux, macOS, or Windows with WSL2
- **Memory:** Minimum 8GB RAM (16GB recommended)
- **Disk Space:** At least 20GB free space
- **CPU:** 4 cores or more recommended

### Required Software

1. **Docker and Docker Compose**
   - [Docker Desktop](https://www.docker.com/products/docker-desktop/) for macOS/Windows
   - [Docker Engine](https://docs.docker.com/engine/install/) + [Docker Compose](https://docs.docker.com/compose/install/) for Linux

2. **Node.js (v18 or higher) and npm/yarn**
   - [Node.js Download](https://nodejs.org/en/download/)
   - Verify installation with: `node -v` and `npm -v`

3. **Git**
   - [Git Download](https://git-scm.com/downloads)
   - Verify installation with: `git --version`

4. **mkcert** (for local SSL certificates)
   - macOS: `brew install mkcert nss`
   - Linux: Use your package manager (e.g., `apt install mkcert`)
   - Windows: Use chocolatey `choco install mkcert`

## Installation Steps

### Step 1: Clone the Repository

```bash
git clone https://github.com/yourusername/dive25.git
cd dive25
```

### Step 2: Configure Environment Variables

```bash
# Copy the example environment file
cp .env.example .env
```

Edit the `.env` file to configure your environment variables. At minimum, review and modify the following:

- `MONGO_ROOT_PASSWORD`: Password for MongoDB root user
- `KEYCLOAK_ADMIN_PASSWORD`: Password for Keycloak admin user
- `LDAP_ADMIN_PASSWORD`: Password for LDAP admin user
- `KONG_DATABASE_PASSWORD`: Password for Kong database

### Step 3: Set Up Local SSL and Custom Domain

This step configures your local environment to use `dive25.local` as the domain with valid SSL certificates:

```bash
# Make the setup script executable
chmod +x ./scripts/setup-local-dev-certs.sh

# Run the script (it will ask for sudo password to modify /etc/hosts)
./scripts/setup-local-dev-certs.sh
```

The script performs the following:
1. Installs mkcert if not already installed
2. Creates a local Certificate Authority (CA)
3. Generates SSL certificates for all DIVE25 domains
4. Adds entries to your `/etc/hosts` file for the local domains
5. Configures Kong to use the generated certificates

### Step 4: Start the System

Launch all system components using Docker Compose:

```bash
docker-compose up -d
```

This will:
1. Build all necessary container images
2. Create required Docker volumes
3. Start all services in the correct order
4. Configure the system components

Initial startup may take several minutes as it:
- Downloads container images
- Builds custom containers
- Sets up databases
- Initializes Keycloak with the DIVE25 realm

### Step 5: Verify the Installation

After the system starts, verify that all components are running:

```bash
docker-compose ps
```

All services should show a status of "Up". If any service shows "Exit" or "Restarting", check the logs:

```bash
docker-compose logs <service-name>
```

### Step 6: Access the System

After successful installation, you can access the system components through your web browser:

- **Main Application:** https://dive25.local
- **API:** https://api.dive25.local
- **Keycloak Admin Console:** https://keycloak.dive25.local
- **MongoDB Express:** https://mongo-express.dive25.local
- **Grafana Dashboard:** https://grafana.dive25.local
- **Kong Admin (Konga):** https://konga.dive25.local
- **phpLDAPadmin:** https://phpldapadmin.dive25.local

### Default Credentials

Use these default credentials to access the various components (unless you changed them in the `.env` file):

- **Keycloak Admin**
  - Username: `admin`
  - Password: Value of `KEYCLOAK_ADMIN_PASSWORD` in .env (default: `admin`)

- **MongoDB Admin**
  - Username: `admin`
  - Password: Value of `MONGO_ROOT_PASSWORD` in .env (default: `admin_password`)

- **LDAP Admin**
  - Username: `cn=admin,dc=dive25,dc=local`
  - Password: Value of `LDAP_ADMIN_PASSWORD` in .env (default: `admin_password`)

- **Grafana Admin**
  - Username: `admin`
  - Password: Value of `GRAFANA_ADMIN_PASSWORD` in .env (default: `admin`)

## Post-Installation Steps

### Create Test Users

The system comes with pre-configured test users if you used the default setup. You can access the application with:

- **Regular User**
  - Username: `user`
  - Password: `password`

- **Admin User**
  - Username: `admin`
  - Password: `password`

For security in production environments, change these default passwords or remove the test users.

### Configure Keycloak for Production

For production environments, additional Keycloak configuration is recommended:

1. Change the admin password
2. Configure proper SMTP settings for email verification
3. Set up additional identity providers if needed
4. Review and update security settings
5. Configure appropriate password policies

### Configure LDAP for Production

For production environments:

1. Create proper organizational units (OUs)
2. Configure proper user and group structure
3. Set up proper access controls and replication if needed

## Troubleshooting

### Common Issues

#### Container Fails to Start

If a container fails to start:

```bash
# Check container logs
docker-compose logs <service-name>

# Restart the container
docker-compose restart <service-name>
```

#### SSL Certificate Issues

If you encounter certificate warnings:

```bash
# Regenerate certificates
./scripts/setup-local-dev-certs.sh --force

# Restart Kong to apply new certificates
docker-compose restart kong
```

#### Database Connection Issues

If services can't connect to databases:

```bash
# Check database container status
docker-compose ps mongodb postgres kong-database

# Restart the affected service
docker-compose restart <service-name>
```

#### Network Issues

If services can't communicate:

```bash
# Recreate the network
docker-compose down
docker-compose up -d
```

## Next Steps

After successful installation, you may want to:

1. [Configure production settings](production.md)
2. [Set up monitoring and alerts](../operations/monitoring.md)
3. [Learn about security configuration](../architecture/security.md)
4. [Understand the API](../technical/api.md)

## Maintenance

### Stopping the System

To stop all services while preserving data:

```bash
docker-compose stop
```

To stop all services and remove containers (data in volumes will be preserved):

```bash
docker-compose down
```

### Resetting the System

To completely reset the system including all data:

```bash
docker-compose down -v
```

Warning: This will remove all volumes and delete all data!

### Updating the System

To update the system to the latest version:

```bash
git pull
docker-compose build --pull
docker-compose down
docker-compose up -d
``` 