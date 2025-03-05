#!/bin/bash
# scripts/env-setup.sh
# Environment setup and management script for DIVE25
# This script helps set up and deploy to DEV, TEST, and PROD environments

set -e

# Display help information
function show_help {
    echo "DIVE25 Environment Setup and Deployment Script"
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -e, --environment ENV   Specify the environment (dev, test, prod). Default: dev"
    echo "  -a, --action ACTION     Specify the action to perform (setup, deploy, restart, status, logs)"
    echo "  -c, --component COMP    Specify the component to act on (all, frontend, api, etc.)"
    echo "  -h, --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -e dev -a setup      Set up the DEV environment"
    echo "  $0 -e test -a deploy    Deploy to the TEST environment"
    echo "  $0 -e prod -a status    Check the status of the PROD environment"
    echo "  $0 -e dev -a logs -c api View logs for the API component in DEV"
}

# Default values
ENVIRONMENT="dev"
ACTION="setup"
COMPONENT="all"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -a|--action)
            ACTION="$2"
            shift 2
            ;;
        -c|--component)
            COMPONENT="$2"
            shift 2
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

# Normalize environment name
case $ENVIRONMENT in
    dev|development)
        ENV_NAME="development"
        ENV_SHORT="dev"
        KUBE_NAMESPACE="dive25-dev"
        ;;
    test|testing|staging)
        ENV_NAME="staging"
        ENV_SHORT="test"
        KUBE_NAMESPACE="dive25-staging"
        ;;
    prod|production)
        ENV_NAME="production"
        ENV_SHORT="prod"
        KUBE_NAMESPACE="dive25-prod"
        ;;
    *)
        echo "Unknown environment: $ENVIRONMENT"
        exit 1
        ;;
esac

echo "Environment: $ENV_NAME"
echo "Action: $ACTION"
echo "Component: $COMPONENT"
echo ""

# Function to set up the environment
function setup_environment {
    echo "Setting up $ENV_NAME environment..."
    
    # Create directories if they don't exist
    mkdir -p env/$ENV_NAME
    
    # Set up the environment file
    if [ ! -f "env/$ENV_NAME/secrets.env" ]; then
        echo "Creating env/$ENV_NAME/secrets.env from .env.example..."
        cp .env.example env/$ENV_NAME/secrets.env
        
        # Update the environment in the file
        sed -i '' "s/ENVIRONMENT=.*/ENVIRONMENT=$ENV_NAME/g" env/$ENV_NAME/secrets.env
    fi
    
    # If DEV environment, update the main .env file
    if [ "$ENV_NAME" == "development" ]; then
        echo "Updating .env for DEV environment..."
        if [ ! -f ".env" ]; then
            cp .env.example .env
        fi
        sed -i '' "s/ENVIRONMENT=.*/ENVIRONMENT=$ENV_NAME/g" .env
        
        # Generate service-specific env files
        ./scripts/generate-env-files.sh
        
        # Set up local dev certs (if not already set up)
        if [ ! -d "certs" ]; then
            echo "Setting up local dev certificates..."
            ./scripts/setup-local-dev-certs.sh
        fi
    fi
    
    echo "Environment setup complete for $ENV_NAME"
}

# Function to deploy the environment
function deploy_environment {
    echo "Deploying to $ENV_NAME environment..."
    
    if [ "$ENV_NAME" == "development" ]; then
        # DEV deployment uses docker-compose
        echo "Starting Docker Compose services..."
        docker-compose up -d $COMPONENT
        
        # Wait for services to be ready
        echo "Waiting for services to be ready..."
        sleep 10
        
        # Run deployment test if component is 'all'
        if [ "$COMPONENT" == "all" ]; then
            echo "Running deployment test..."
            ./scripts/test-deployment.sh
        fi
        
        echo "DEV environment deployment complete"
        
    else
        # TEST and PROD environments use Kubernetes
        echo "Deploying to Kubernetes namespace: $KUBE_NAMESPACE..."
        
        # Seal secrets for Kubernetes
        if [ "$COMPONENT" == "all" ] || [ "$COMPONENT" == "secrets" ]; then
            echo "Sealing secrets..."
            ./scripts/seal-secrets.sh dive25-secrets $KUBE_NAMESPACE env/$ENV_NAME/secrets.env $ENV_SHORT
        fi
        
        # Deploy using the deploy.sh script
        if [ "$ENV_SHORT" == "test" ]; then
            echo "Mapping test environment to staging for deploy.sh..."
            ./scripts/deploy.sh -e staging -d
        else
            ./scripts/deploy.sh -e $ENV_SHORT -d
        fi
        
        # If component is 'all', run post-deployment tests
        if [ "$COMPONENT" == "all" ]; then
            echo "Running post-deployment tests..."
            ./scripts/post-deployment-test.sh -e $ENV_SHORT
        fi
        
        echo "$ENV_NAME environment deployment complete"
    fi
}

# Function to restart services
function restart_services {
    echo "Restarting services in $ENV_NAME environment..."
    
    if [ "$ENV_NAME" == "development" ]; then
        # DEV restart uses docker-compose
        echo "Restarting Docker Compose services..."
        docker-compose restart $COMPONENT
        
    else
        # TEST and PROD restart uses kubectl
        echo "Restarting services in Kubernetes namespace: $KUBE_NAMESPACE..."
        
        if [ "$COMPONENT" == "all" ]; then
            echo "Restarting all deployments..."
            kubectl rollout restart deployment -n $KUBE_NAMESPACE
        else
            echo "Restarting $COMPONENT deployment..."
            kubectl rollout restart deployment $ENV_SHORT-dive25-$COMPONENT -n $KUBE_NAMESPACE
        fi
    fi
    
    echo "Services restarted successfully"
}

# Function to check service status
function check_status {
    echo "Checking status of $ENV_NAME environment..."
    
    if [ "$ENV_NAME" == "development" ]; then
        # DEV status uses docker-compose
        echo "Docker Compose service status:"
        docker-compose ps $COMPONENT
        
    else
        # TEST and PROD status uses kubectl
        echo "Kubernetes service status in namespace: $KUBE_NAMESPACE"
        
        if [ "$COMPONENT" == "all" ]; then
            echo "All resources:"
            kubectl get all -n $KUBE_NAMESPACE
        else
            echo "$COMPONENT resources:"
            kubectl get deployment,pod,svc -l app=$COMPONENT -n $KUBE_NAMESPACE
        fi
    fi
}

# Function to view logs
function view_logs {
    echo "Viewing logs for $COMPONENT in $ENV_NAME environment..."
    
    if [ "$ENV_NAME" == "development" ]; then
        # DEV logs uses docker-compose
        if [ "$COMPONENT" == "all" ]; then
            echo "Cannot view logs for all components at once in DEV"
            echo "Please specify a component with -c"
            exit 1
        else
            echo "Docker Compose logs for $COMPONENT:"
            docker-compose logs --tail=100 -f $COMPONENT
        fi
        
    else
        # TEST and PROD logs uses kubectl
        echo "Kubernetes logs in namespace: $KUBE_NAMESPACE"
        
        if [ "$COMPONENT" == "all" ]; then
            echo "Cannot view logs for all components at once"
            echo "Please specify a component with -c"
            exit 1
        else
            # Get the pod name for the component
            POD_NAME=$(kubectl get pod -l app=$COMPONENT -n $KUBE_NAMESPACE -o jsonpath="{.items[0].metadata.name}")
            echo "Logs for pod $POD_NAME:"
            kubectl logs -f $POD_NAME -n $KUBE_NAMESPACE
        fi
    fi
}

# Execute the requested action
case $ACTION in
    setup)
        setup_environment
        ;;
    deploy)
        deploy_environment
        ;;
    restart)
        restart_services
        ;;
    status)
        check_status
        ;;
    logs)
        view_logs
        ;;
    *)
        echo "Unknown action: $ACTION"
        show_help
        exit 1
        ;;
esac

echo "Operation completed successfully." 