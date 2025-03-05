#!/bin/bash

# Exit on any error
set -e

# Display help information
function show_help {
    echo "DIVE25 Deployment Script"
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -e, --environment ENV   Specify the environment (dev, staging, prod). Default: dev"
    echo "  -b, --build             Build Docker images"
    echo "  -p, --push              Push Docker images to registry"
    echo "  -d, --deploy            Deploy to Kubernetes"
    echo "  -s, --secrets           Update sealed secrets"
    echo "  -a, --all               Perform all actions: build, push, deploy"
    echo "  -h, --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -e dev -a            Build, push, and deploy to dev environment"
    echo "  $0 -e prod -d           Deploy to production environment"
    echo "  $0 -e staging -b -p     Build and push for staging environment"
}

# Default values
ENVIRONMENT="dev"
BUILD=false
PUSH=false
DEPLOY=false
SECRETS=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -b|--build)
            BUILD=true
            shift
            ;;
        -p|--push)
            PUSH=true
            shift
            ;;
        -d|--deploy)
            DEPLOY=true
            shift
            ;;
        -s|--secrets)
            SECRETS=true
            shift
            ;;
        -a|--all)
            BUILD=true
            PUSH=true
            DEPLOY=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Set variables based on environment
case $ENVIRONMENT in
    dev|development)
        NAMESPACE="dive25-dev"
        PREFIX="dev-"
        ENV_CONFIG="k8s/environments/development"
        ;;
    staging)
        NAMESPACE="dive25-staging"
        PREFIX="staging-"
        ENV_CONFIG="k8s/environments/staging"
        ;;
    prod|production)
        NAMESPACE="dive25-prod"
        PREFIX="prod-"
        ENV_CONFIG="k8s/environments/production"
        ;;
    *)
        echo "Unknown environment: $ENVIRONMENT"
        exit 1
        ;;
esac

echo "Deploying to environment: $ENVIRONMENT (namespace: $NAMESPACE)"

# Build Docker images
if $BUILD; then
    echo "Building Docker images..."
    
    # Build API image
    echo "Building API image..."
    docker build -t dive25/api:latest ./api
    
    # Build Frontend image
    echo "Building Frontend image..."
    docker build -t dive25/frontend:latest ./frontend
    
    echo "Docker images built successfully."
fi

# Push Docker images
if $PUSH; then
    echo "Pushing Docker images..."
    
    # Tag images
    docker tag dive25/api:latest ghcr.io/dive25/api:latest
    docker tag dive25/frontend:latest ghcr.io/dive25/frontend:latest
    
    # Push images
    docker push ghcr.io/dive25/api:latest
    docker push ghcr.io/dive25/frontend:latest
    
    echo "Docker images pushed successfully."
fi

# Update sealed secrets
if $SECRETS; then
    echo "Updating sealed secrets..."
    
    # Ensure namespace exists
    kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    
    # Seal secrets
    ./scripts/seal-secrets.sh dive25-secrets $NAMESPACE env/$ENVIRONMENT/secrets.env $ENVIRONMENT
    
    echo "Sealed secrets updated successfully."
fi

# Deploy to Kubernetes
if $DEPLOY; then
    echo "Deploying to Kubernetes..."
    
    # Test if kubectl can connect to a cluster
    if ! kubectl cluster-info &>/dev/null; then
        echo "Warning: Cannot connect to Kubernetes cluster."
        echo "For local development, you can use Docker Compose instead:"
        echo "  docker-compose -f docker-compose.$ENVIRONMENT.yml up -d"
        exit 1
    fi
    
    # Ensure namespace exists
    kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    
    # Deploy using Kustomize
    kubectl apply -k $ENV_CONFIG
    
    # Wait for deployments to be ready
    echo "Waiting for deployments to be ready..."
    kubectl rollout status deployment/${PREFIX}dive25-api -n $NAMESPACE --timeout=300s
    kubectl rollout status deployment/${PREFIX}dive25-frontend -n $NAMESPACE --timeout=300s
    
    echo "Deployment completed successfully."
    
    # Display access information
    INGRESS_HOST=$(kubectl get ingress -n $NAMESPACE ${PREFIX}dive25-frontend-ingress -o jsonpath='{.spec.rules[0].host}')
    echo ""
    echo "Application is now available at:"
    echo "  Frontend: https://$INGRESS_HOST"
    echo "  API: https://api.$INGRESS_HOST"
    echo "  Keycloak: https://keycloak.$INGRESS_HOST"
fi

echo "Operation completed successfully."