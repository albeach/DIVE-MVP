#!/bin/bash

# Set the script to exit on error
set -e

echo "Checking API container network connectivity..."

# Check if API container exists
if docker ps -q -f name=dive25-staging-api > /dev/null; then
    echo "API container is running."
    
    # Check if API container is connected to data network
    if ! docker network inspect dive-mvp_dive25-data | grep -q "dive25-staging-api"; then
        echo "API container is not connected to data network. Connecting now..."
        docker network connect dive-mvp_dive25-data dive25-staging-api
        echo "Restarting API container to re-establish connections..."
        docker restart dive25-staging-api
        echo "Waiting for API to reconnect to MongoDB..."
        sleep 10
        
        # Check API health to verify MongoDB connection
        if curl -k -s https://api.dive25.local:3002/health | grep -q '"mongodb":{"status":"up"}'; then
            echo "Success: API is now connected to MongoDB."
        else
            echo "Warning: API may not be fully connected to MongoDB yet."
            echo "Check API logs for more information."
        fi
    else
        echo "API container is already connected to the data network."
    fi
else
    echo "API container is not running."
fi

echo "Network check complete." 