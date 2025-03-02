# DIVE25 Document Access System

DIVE25 is a secure, federated document access system for NATO partners, designed to provide secure access to classified documents with proper authentication and authorization controls.

## Architecture

The system comprises several components:

- **Frontend**: Next.js + Tailwind CSS user interface
- **Backend API**: Node.js API for document access and management
- **Keycloak**: Identity and access management for federation
- **OpenLDAP**: Central directory for user attributes
- **MongoDB**: Document metadata storage
- **Open Policy Agent (OPA)**: Policy enforcement using Rego rules
- **Kong**: API gateway and reverse proxy
- **Prometheus & Grafana**: Monitoring and logging

## Prerequisites

- Docker and Docker Compose
- Node.js 18+
- npm or yarn

## Getting Started

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/dive25.git
   cd dive25

Copy the example environment file and adjust as needed:
bash

## Local Development with SSL and Custom Domain

To set up a local development environment with the hostname `dive25.local` and secure HTTPS connections:

1. Install mkcert and set up local certificates:

```bash
# Make the setup script executable
chmod +x ./scripts/setup-local-dev-certs.sh

# Run the script (it will ask for sudo password to modify /etc/hosts)
./scripts/setup-local-dev-certs.sh
```

2. Update the Kong configuration to use SSL certificates:

```bash
# Run the update script
chmod +x ./scripts/update-kong-config.sh
./scripts/update-kong-config.sh
```

3. Start the application:

```bash
docker-compose up -d
```

4. Access the application at:

- Main application: https://dive25.local
- API: https://api.dive25.local
- Keycloak: https://keycloak.dive25.local
- MongoDB Express: https://mongo-express.dive25.local
- Grafana: https://grafana.dive25.local
- Konga (Kong Admin): https://konga.dive25.local
- Kong Admin API: https://kong.dive25.local
- Prometheus: https://prometheus.dive25.local
- phpLDAPadmin: https://phpldapadmin.dive25.local

All connections will use HTTPS with valid certificates created by mkcert, so you won't see any browser warnings. 
The SSL termination is handled by Kong, which serves as both the API gateway and the reverse proxy for all services.