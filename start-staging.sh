#!/bin/bash

# Stop any running containers and clean up
echo "Stopping any running containers and cleaning up..."
docker-compose -f docker-compose.staging.yml down -v

# Start the staging environment
echo "Starting the staging environment with all components..."
docker-compose -f docker-compose.staging.yml up -d

# Wait for services to be ready
echo "Waiting for services to be ready..."
sleep 30

# Check if services are running
echo "Checking if services are running..."
docker-compose -f docker-compose.staging.yml ps

echo "Staging environment is now running with all components."
echo "You can access the following services:"
echo "- Frontend: http://localhost:8083"
echo "- API: http://localhost:3003"
echo "- Keycloak: http://localhost:8082/auth"
echo "- Kong Admin: http://localhost:8001"
echo "- Konga UI: http://localhost:1337"
echo "- Prometheus: http://localhost:9090"
echo "- Grafana: http://localhost:3100"
echo "- Elasticsearch: http://localhost:9202"
echo "- Minio Console: http://localhost:9005"

echo "To stop the environment, run: docker-compose -f docker-compose.staging.yml down" 