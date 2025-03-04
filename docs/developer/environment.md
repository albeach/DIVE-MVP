# Development Environment Setup

This guide provides detailed instructions for setting up a development environment for the DIVE25 Document Access System. It covers installation of prerequisites, configuration of development tools, and running the application locally.

## System Requirements

Ensure your development machine meets these minimum requirements:

- **CPU**: 4+ cores (8+ recommended for running all services)
- **RAM**: 16GB minimum (32GB recommended)
- **Storage**: 50GB free space (SSD recommended)
- **Operating System**: 
  - Linux (Ubuntu 20.04+, Debian 11+)
  - macOS (12.0+)
  - Windows 10/11 with WSL2

## Installing Prerequisites

### 1. Git

Git is used for version control and collaborating with other developers.

**Linux (Ubuntu/Debian):**
```bash
sudo apt update
sudo apt install git
```

**macOS:**
```bash
# Using Homebrew
brew install git

# Alternative: Download installer from https://git-scm.com/download/mac
```

**Windows:**
```bash
# Using Chocolatey
choco install git

# Alternative: Download installer from https://git-scm.com/download/win
```

Verify installation:
```bash
git --version
# Should output: git version 2.35.0 or similar
```

### 2. Docker and Docker Compose

Docker is used to containerize services and dependencies.

**Linux:**
```bash
# Install Docker
sudo apt update
sudo apt install apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt update
sudo apt install docker-ce

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.10.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Add your user to the docker group
sudo usermod -aG docker ${USER}
# Log out and log back in for changes to take effect
```

**macOS:**
```bash
# Using Homebrew
brew install --cask docker

# Alternative: Download Docker Desktop from https://www.docker.com/products/docker-desktop
```

**Windows:**
```bash
# Using Chocolatey
choco install docker-desktop

# Alternative: Download Docker Desktop from https://www.docker.com/products/docker-desktop
```

Verify installation:
```bash
docker --version
# Should output: Docker version 20.10.21 or similar

docker-compose --version
# Should output: Docker Compose version v2.10.2 or similar
```

### 3. Node.js and npm

Node.js is used for running the frontend and some backend services.

**All Platforms:**

We recommend using NVM (Node Version Manager) to manage Node.js versions:

```bash
# Install NVM
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash
# Or with wget
wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash

# Restart your terminal or source profile
source ~/.bashrc  # or ~/.zshrc if using zsh

# Install and use Node.js 16
nvm install 16
nvm use 16
```

Alternatively, you can install Node.js directly:

**Linux:**
```bash
sudo apt update
sudo apt install nodejs npm
```

**macOS:**
```bash
brew install node@16
```

**Windows:**
```bash
choco install nodejs-lts
```

Verify installation:
```bash
node --version
# Should output: v16.x.x

npm --version
# Should output: 8.x.x
```

### 4. Java Development Kit (JDK)

JDK is required for running Java-based services like Keycloak.

**Linux:**
```bash
sudo apt update
sudo apt install openjdk-17-jdk
```

**macOS:**
```bash
brew install openjdk@17
```

**Windows:**
```bash
choco install openjdk17
```

Verify installation:
```bash
java --version
# Should output: openjdk 17.x.x or similar
```

### 5. Code Editor

We recommend Visual Studio Code with extensions for TypeScript, Java, Docker, and ESLint.

**All Platforms:**
Download from: https://code.visualstudio.com/download

**Recommended Extensions:**
- ESLint
- Prettier
- Docker
- TypeScript and JavaScript Language Features
- Java Extension Pack
- MongoDB for VS Code
- Kubernetes
- REST Client

## Setting Up the Project

### 1. Clone the Repositories

Create a directory for your DIVE25 projects:

```bash
mkdir ~/dive25
cd ~/dive25
```

Clone the required repositories:

```bash
# Main API and services
git clone https://github.com/dive25/document-service.git
git clone https://github.com/dive25/search-service.git
git clone https://github.com/dive25/policy-service.git
git clone https://github.com/dive25/auth-service.git
git clone https://github.com/dive25/storage-service.git

# Frontend application
git clone https://github.com/dive25/web-client.git

# Optional: DevOps repository with deployment scripts
git clone https://github.com/dive25/devops.git
```

### 2. Set Up Development Environment Variables

Each repository needs environment variables configured. Create a `.env.local` file in each repository:

**Example for document-service:**
```bash
cd ~/dive25/document-service
cp .env.example .env.local
```

Edit `.env.local` with your preferred editor:
```
# API Configuration
PORT=3001
NODE_ENV=development
LOG_LEVEL=debug

# Database Configuration
MONGODB_URI=mongodb://localhost:27017/dive25_documents
MONGODB_USER=dive_dev
MONGODB_PASSWORD=dev_password

# Auth Configuration
AUTH_SERVICE_URL=http://localhost:3005
JWT_SECRET=local_development_secret_key

# Search Configuration
SEARCH_SERVICE_URL=http://localhost:3002

# Storage Configuration
STORAGE_SERVICE_URL=http://localhost:3004
MINIO_ENDPOINT=localhost
MINIO_PORT=9000
MINIO_ACCESS_KEY=minioadmin
MINIO_SECRET_KEY=minioadmin
MINIO_USE_SSL=false
```

Repeat this process for each service, adjusting the configuration as needed.

### 3. Start Development Dependencies

We'll use Docker Compose to start the required dependencies:

```bash
cd ~/dive25/devops/local
docker-compose up -d
```

This will start:
- MongoDB (document database)
- Elasticsearch (search engine)
- MinIO (object storage)
- Keycloak (authentication)
- Redis (caching)

### 4. Configure Each Service

#### Document Service Setup:

```bash
cd ~/dive25/document-service

# Install dependencies
npm install

# Run database migrations
npm run migrate

# Start the service in development mode
npm run dev
```

#### Search Service Setup:

```bash
cd ~/dive25/search-service

# Install dependencies
npm install

# Initialize Elasticsearch indices
npm run init-indices

# Start the service in development mode
npm run dev
```

Repeat similar steps for each service, following the README instructions in each repository.

### 5. Set Up the Frontend Application

```bash
cd ~/dive25/web-client

# Install dependencies
npm install

# Start the development server
npm run dev
```

The frontend application should now be running at http://localhost:3000.

## Local Development Configuration

### Setting Up Local DNS

To simplify development, you can configure local DNS entries:

**All Platforms:**

Edit your hosts file:

```bash
# Linux/macOS
sudo nano /etc/hosts

# Windows (run as Administrator)
notepad C:\Windows\System32\drivers\etc\hosts
```

Add the following entries:
```
127.0.0.1 api.dive25.local
127.0.0.1 auth.dive25.local
127.0.0.1 app.dive25.local
```

### Configuring HTTPS for Local Development

For a more production-like environment, you can set up HTTPS locally:

1. **Generate self-signed certificates:**

```bash
cd ~/dive25/devops/local/certs

# Generate certificates
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout server.key -out server.crt -subj "/CN=*.dive25.local" -addext "subjectAltName = DNS:*.dive25.local,DNS:localhost"
```

2. **Configure services to use HTTPS:**

Update the `.env.local` files for each service to use the certificates.

3. **Trust the self-signed certificate:**

   - **macOS**: Double-click the `server.crt` file and add it to the System keychain as trusted.
   - **Windows**: Double-click the `server.crt` file and install it in the Trusted Root Certification Authorities store.
   - **Linux**: Import the certificate using the system's certificate manager.

## Development Workflow

### Running Tests

Each repository contains tests that should be run before submitting pull requests:

```bash
# Run unit tests
npm run test

# Run integration tests
npm run test:integration

# Check code style
npm run lint

# Fix code style issues
npm run lint:fix
```

### Using the Development Tools

#### API Testing with REST Client

Create a file with `.http` extension in VS Code:

```http
### Get Authentication Token
POST http://auth.dive25.local:3005/api/v1/auth/login
Content-Type: application/json

{
  "username": "admin",
  "password": "admin"
}

### Get Documents
GET http://api.dive25.local:3001/api/v1/documents
Authorization: Bearer {{auth_token}}
```

#### Database Management

You can connect to the MongoDB instance using MongoDB Compass or the VS Code MongoDB extension:

- **Connection String**: `mongodb://dive_dev:dev_password@localhost:27017/dive25_documents`

#### Elasticsearch Management

Use Kibana to manage Elasticsearch:

- **URL**: http://localhost:5601

#### MinIO Management

Access the MinIO console:

- **URL**: http://localhost:9001
- **Access Key**: minioadmin
- **Secret Key**: minioadmin

## Troubleshooting Common Issues

### Service Won't Start

If a service fails to start, check:

1. **Port conflicts**: Ensure no other application is using the service's port
   ```bash
   # Check what's using port 3001
   lsof -i :3001
   ```

2. **Missing environment variables**: Verify your `.env.local` file
   ```bash
   # Compare with example file
   diff .env.example .env.local
   ```

3. **Dependency services**: Confirm that required services are running
   ```bash
   # Check Docker containers
   docker ps
   ```

### Database Connection Issues

If you're having trouble connecting to MongoDB:

1. **Check MongoDB container**:
   ```bash
   docker logs mongodb
   ```

2. **Verify connection string**:
   ```bash
   # Try connecting with MongoDB CLI
   mongosh mongodb://dive_dev:dev_password@localhost:27017/dive25_documents
   ```

### Authentication Problems

If authentication isn't working:

1. **Check Keycloak container**:
   ```bash
   docker logs keycloak
   ```

2. **Verify Keycloak configuration**:
   - Access Keycloak admin console at http://localhost:8080
   - Username: admin
   - Password: admin

### Network Issues

If services can't communicate:

1. **Check Docker network**:
   ```bash
   docker network inspect devops_local_network
   ```

2. **Test inter-service communication**:
   ```bash
   # From inside a container
   docker exec -it document-service curl -v http://search-service:3002/health
   ```

## Advanced Configuration

### Using Kubernetes for Local Development

For a more production-like environment, you can use Kubernetes with minikube:

1. **Install minikube**:
   ```bash
   # Install minikube
   curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
   sudo install minikube-linux-amd64 /usr/local/bin/minikube
   ```

2. **Start minikube**:
   ```bash
   minikube start --driver=docker --cpus 4 --memory 8g
   ```

3. **Apply Kubernetes configurations**:
   ```bash
   cd ~/dive25/devops/kubernetes
   kubectl apply -f development/
   ```

### Remote Development

If you're working with a remote development environment:

1. **SSH Configuration**:
   ```bash
   # Add to ~/.ssh/config
   Host dive25-dev
     HostName dev.dive25.example.org
     User yourname
     IdentityFile ~/.ssh/id_rsa
     ForwardAgent yes
   ```

2. **VS Code Remote Development**:
   - Install the "Remote - SSH" extension
   - Connect to the remote host
   - Open the project folder

## Related Documentation

- [Contribution Guide](contribution.md)
- [Architecture Overview](../architecture/overview.md)
- [Testing Guide](testing.md)
- [API Documentation](../technical/api.md) 