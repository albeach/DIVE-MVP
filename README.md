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