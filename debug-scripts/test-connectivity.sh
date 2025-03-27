#!/bin/bash

echo "=== DIVE25 Network Connectivity Test ==="
echo "Testing connectivity to key services..."

echo -e "\n=== DNS Resolution ==="
echo "Frontend:"
dig frontend +short
echo "API:"
dig api +short
echo "Kong:"
dig kong +short
echo "Keycloak:"
dig keycloak +short

echo -e "\n=== HTTP Connectivity ==="
echo "Frontend:"
curl -s -o /dev/null -w "%{http_code}" http://frontend:3000
echo " (Frontend:3000)"

echo "API:"
curl -s -o /dev/null -w "%{http_code}" http://api:3000
echo " (API:3000)"

echo "Kong HTTP:"
curl -s -o /dev/null -w "%{http_code}" http://kong:8000
echo " (Kong:8000)"

echo "Kong HTTPS:"
curl -k -s -o /dev/null -w "%{http_code}" https://kong:8443
echo " (Kong:8443)"

echo "Kong Admin:"
curl -s -o /dev/null -w "%{http_code}" http://kong:8001
echo " (Kong Admin:8001)"

echo "Keycloak:"
curl -s -o /dev/null -w "%{http_code}" http://keycloak:8080
echo " (Keycloak:8080)"

echo -e "\n=== Network Routes ==="
echo "Routes to Frontend:"
traceroute -n frontend -m 2
echo "Routes to Kong:"
traceroute -n kong -m 2

echo -e "\n=== Service Info ==="
echo "All running containers:"
docker ps --format "{{.Names}}: {{.Status}}"

echo -e "\nTest completed!" 