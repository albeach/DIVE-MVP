#!/bin/bash
set -e

# Setup script for the staging environment

# Display help information
function show_help {
  echo "Usage: $0 [options]"
  echo "Options:"
  echo "  -h, --help       Show this help message"
  echo "  -d, --docker     Use Docker Compose for local staging environment"
  echo "  -k, --kubernetes Use Kubernetes for staging environment"
  echo "  -a, --all        Setup everything (Docker and Kubernetes)"
}

# Default options
USE_DOCKER=false
USE_KUBERNETES=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      show_help
      exit 0
      ;;
    -d|--docker)
      USE_DOCKER=true
      shift
      ;;
    -k|--kubernetes)
      USE_KUBERNETES=true
      shift
      ;;
    -a|--all)
      USE_DOCKER=true
      USE_KUBERNETES=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      show_help
      exit 1
      ;;
  esac
done

# If no options specified, show help
if [[ "$USE_DOCKER" == "false" && "$USE_KUBERNETES" == "false" ]]; then
  show_help
  exit 1
fi

echo "Setting up staging environment..."

# Setup Docker Compose environment
if [[ "$USE_DOCKER" == "true" ]]; then
  echo "Setting up Docker Compose staging environment..."
  
  # Ensure locales directory exists for frontend
  mkdir -p frontend/public/locales/en
  if [ ! -f frontend/public/locales/en/common.json ]; then
    echo '{
  "app": {
    "name": "DIVE25",
    "description": "Document Intelligence and Verification Engine"
  },
  "navigation": {
    "home": "Home",
    "dashboard": "Dashboard",
    "documents": "Documents",
    "settings": "Settings",
    "logout": "Logout"
  },
  "actions": {
    "save": "Save",
    "cancel": "Cancel",
    "delete": "Delete",
    "edit": "Edit",
    "create": "Create",
    "upload": "Upload",
    "download": "Download",
    "search": "Search"
  },
  "messages": {
    "welcome": "Welcome to DIVE25",
    "loading": "Loading...",
    "error": "An error occurred",
    "success": "Operation successful"
  }
}' > frontend/public/locales/en/common.json
  fi
  
  # Build and start the Docker Compose environment
  docker-compose -f docker-compose.staging.yml up -d --build
  
  echo "Docker Compose staging environment is now running."
  echo "Access the frontend at: http://localhost:8083"
  echo "Access the API at: http://localhost:3003"
fi

# Setup Kubernetes environment
if [[ "$USE_KUBERNETES" == "true" ]]; then
  echo "Setting up Kubernetes staging environment..."
  
  # Check if kubectl is available
  if ! command -v kubectl &> /dev/null; then
    echo "Error: kubectl is not installed or not in PATH"
    exit 1
  fi
  
  # Check if we can connect to a Kubernetes cluster
  if ! kubectl cluster-info &> /dev/null; then
    echo "Error: Cannot connect to Kubernetes cluster"
    echo "Make sure your cluster is running and kubectl is properly configured"
    exit 1
  fi
  
  # Create namespace if it doesn't exist
  if ! kubectl get namespace dive25-staging &> /dev/null; then
    echo "Creating namespace: dive25-staging"
    kubectl create namespace dive25-staging
  fi
  
  # Apply Kubernetes configurations using kustomize
  echo "Applying Kubernetes configurations..."
  kubectl apply -k k8s/environments/staging
  
  echo "Kubernetes staging environment setup complete."
fi

echo "Staging environment setup completed successfully!"