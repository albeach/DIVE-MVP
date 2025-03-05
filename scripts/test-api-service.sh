#!/bin/bash

echo "Testing API service connectivity..."

# Test direct connection to API service
echo "Testing direct connection to API container on port 3000:"
docker exec dive25-kong curl -v http://api:3000/api/health

echo -e "\nTesting API service from host:"
curl -v http://localhost:3000/api/health

echo -e "\nChecking API container logs:"
docker logs dive25-api --tail 20

echo -e "\nChecking Kong logs for API route:"
docker logs dive25-kong | grep -E 'api.dive25.local|api-route' | tail -20 