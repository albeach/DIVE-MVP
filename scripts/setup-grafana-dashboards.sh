#!/bin/bash
set -e

# Script to ensure Grafana dashboards are properly set up

echo "Setting up Grafana dashboards..."

# Wait for Grafana to be ready
echo "Waiting for Grafana to be ready..."
timeout 60 sh -c 'until curl -s http://localhost:4434 > /dev/null; do sleep 1; done' || { echo "Grafana is not available at http://localhost:4434"; exit 1; }

# Create curl tools container if it doesn't exist
if ! docker ps | grep -q dive25-curl-tools; then
  echo "Creating curl tools container..."
  docker run -d --name dive25-curl-tools --network dive-mvp_default alpine/curl:latest sh -c "while true; do sleep 30; done"
fi

# Create API datasource
echo "Setting up Loki data source..."
docker exec -it dive25-curl-tools curl -s -X POST -H "Content-Type: application/json" -d '{
  "name": "Loki",
  "type": "loki",
  "url": "http://loki:3100",
  "access": "proxy",
  "basicAuth": false
}' http://admin:admin@grafana:3000/api/datasources

# Verify Loki datasource
echo "Verifying Loki data source..."
docker exec -it dive25-curl-tools curl -s http://admin:admin@grafana:3000/api/datasources/name/Loki

# Reload Grafana dashboard provisioning
echo "Reloading Grafana dashboard provisioning..."
docker exec -it dive25-curl-tools curl -s -X POST http://admin:admin@grafana:3000/api/admin/provisioning/dashboards/reload

echo "Grafana dashboards setup completed successfully!" 