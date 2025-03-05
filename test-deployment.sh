#!/bin/bash
set -e

# Define colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color
BLUE='\033[0;34m'

# Function to print section headers
print_header() {
  echo -e "\n${BLUE}=== $1 ===${NC}\n"
}

# Function to print success/failure messages
print_result() {
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ $1${NC}"
  else
    echo -e "${RED}✗ $1${NC}"
    if [ "$2" != "nonfatal" ]; then
      exit 1
    fi
  fi
}

# Check if .env file exists
if [ ! -f .env ]; then
  echo -e "${YELLOW}Warning: .env file not found. Creating a sample one for testing.${NC}"
  cat > .env << EOF
# Basic configuration
ENVIRONMENT=development
BASE_DOMAIN=dive25.local
DEV_BASE_DOMAIN=localhost

# MongoDB credentials
MONGO_ROOT_USERNAME=mongoroot
MONGO_ROOT_PASSWORD=mongopassword
MONGO_APP_USERNAME=mongouser
MONGO_APP_PASSWORD=mongopassword

# PostgreSQL credentials
POSTGRES_PASSWORD=postgrespassword

# Keycloak settings
KEYCLOAK_ADMIN=admin
KEYCLOAK_ADMIN_PASSWORD=adminpassword
KEYCLOAK_REALM=dive25
KEYCLOAK_CLIENT_ID_API=dive25-api
KEYCLOAK_CLIENT_ID_FRONTEND=dive25-frontend
KEYCLOAK_CLIENT_SECRET=clientsecret

# LDAP settings
LDAP_ADMIN_PASSWORD=ldapadmin
LDAP_CONFIG_PASSWORD=ldapconfig
LDAP_READONLY_PASSWORD=ldapreadonly
LDAP_BIND_DN=cn=admin,dc=dive25,dc=local
LDAP_SEARCH_BASE=dc=dive25,dc=local

# URLs
INTERNAL_KEYCLOAK_URL=http://keycloak:8080
PUBLIC_KEYCLOAK_URL=http://localhost:8080
PUBLIC_API_URL=http://localhost:3000
PUBLIC_FRONTEND_URL=http://localhost:3001

# Development ports
DEV_KEYCLOAK_PORT=8080
DEV_API_PORT=3000
DEV_FRONTEND_PORT=3001

# Misc settings
JWT_SECRET=jwtsecret
CORS_ALLOWED_ORIGINS=*
LOG_LEVEL=info
KONGA_TOKEN_SECRET=kongasecret

# Grafana credentials
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=admin
EOF
fi

# Step 1: Make sure Docker is running
print_header "CHECKING DOCKER"
docker info > /dev/null
print_result "Docker is running"

# Step 2: Build and start the containers
print_header "STARTING CONTAINERS"
echo "Bringing up the stack with docker-compose..."
docker-compose down --remove-orphans
print_result "Cleaned up any existing containers"

docker-compose up -d
print_result "Started all containers"

# Step 3: Wait for containers to initialize
print_header "WAITING FOR CONTAINERS TO INITIALIZE"
echo "Giving containers time to start up (60 seconds)..."
sleep 60

# Step 4: Check container statuses
print_header "CHECKING CONTAINER HEALTH"
CONTAINERS=$(docker-compose ps --services)

for container in $CONTAINERS; do
  HEALTH=$(docker inspect --format='{{.State.Health.Status}}' dive25-$container 2>/dev/null || echo "health-check-not-configured")
  STATUS=$(docker inspect --format='{{.State.Status}}' dive25-$container)
  
  if [ "$HEALTH" == "healthy" ] || [ "$HEALTH" == "health-check-not-configured" -a "$STATUS" == "running" ]; then
    echo -e "${GREEN}✓ Container $container is healthy${NC}"
  else
    echo -e "${RED}✗ Container $container is not healthy (status: $STATUS, health: $HEALTH)${NC}"
    echo "Logs for $container:"
    docker logs dive25-$container --tail 20
  fi
done

# Step 5: Test service accessibility
print_header "TESTING SERVICE ACCESSIBILITY"

# Test MongoDB connection
echo "Testing MongoDB connection..."
docker exec dive25-mongodb mongosh --quiet --eval "db.adminCommand('ping')" &> /dev/null
print_result "MongoDB is accessible" "nonfatal"

# Test MongoDB Express
echo "Testing MongoDB Express accessibility..."
curl -s -o /dev/null -w "%{http_code}" http://localhost:8081/ | grep -q "200\|302"
print_result "MongoDB Express is accessible" "nonfatal"

# Test Keycloak
echo "Testing Keycloak accessibility..."
curl -s -o /dev/null -w "%{http_code}" http://localhost:${DEV_KEYCLOAK_PORT:-8080}/health | grep -q "200"
print_result "Keycloak is accessible" "nonfatal"

# Test OpenLDAP
echo "Testing OpenLDAP accessibility..."
docker exec dive25-openldap ldapsearch -x -H ldap://localhost:389 -D "cn=admin,dc=dive25,dc=local" -w "${LDAP_ADMIN_PASSWORD:-admin_password}" -b "dc=dive25,dc=local" &> /dev/null
print_result "OpenLDAP is accessible" "nonfatal"

# Test phpLDAPadmin
echo "Testing phpLDAPadmin accessibility..."
curl -s -o /dev/null -w "%{http_code}" http://localhost:8085/ | grep -q "200\|302"
print_result "phpLDAPadmin is accessible" "nonfatal"

# Test OPA
echo "Testing OPA accessibility..."
curl -s -o /dev/null http://localhost:8181/health
print_result "OPA is accessible" "nonfatal"

# Test Kong Admin API
echo "Testing Kong Admin API accessibility..."
curl -s -o /dev/null -w "%{http_code}" http://localhost:8001/ | grep -q "200"
print_result "Kong Admin API is accessible" "nonfatal"

# Test Kong Proxy
echo "Testing Kong Proxy accessibility..."
curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/ | grep -q "404"
print_result "Kong Proxy is accessible (404 is expected when no routes configured)" "nonfatal"

# Test Konga
echo "Testing Konga accessibility..."
curl -s -o /dev/null -w "%{http_code}" http://localhost:1337/ | grep -q "200"
print_result "Konga is accessible" "nonfatal"

# Test API
echo "Testing API accessibility..."
curl -s -o /dev/null -w "%{http_code}" http://localhost:${DEV_API_PORT:-3000}/metrics | grep -q "200"
print_result "API is accessible" "nonfatal"

# Test Frontend
echo "Testing Frontend accessibility..."
curl -s -o /dev/null -w "%{http_code}" http://localhost:${DEV_FRONTEND_PORT:-3001}/ | grep -q "200"
print_result "Frontend is accessible" "nonfatal"

# Step 6: Test service communication
print_header "TESTING SERVICE COMMUNICATION"

# Test API to MongoDB connection
echo "Testing API to MongoDB connection..."
docker exec dive25-api curl -s http://localhost:3000/health | grep -q "UP"
print_result "API can connect to MongoDB" "nonfatal"

# Test API to Keycloak connection
echo "Testing API to Keycloak connection..."
docker exec dive25-api curl -s ${INTERNAL_KEYCLOAK_URL:-http://keycloak:8080}/health | grep -q "UP"
print_result "API can connect to Keycloak" "nonfatal"

# Step 7: Check logs for errors
print_header "CHECKING LOGS FOR ERRORS"
for container in $CONTAINERS; do
  ERROR_COUNT=$(docker logs dive25-$container 2>&1 | grep -i error | wc -l)
  if [ $ERROR_COUNT -gt 0 ]; then
    echo -e "${YELLOW}! Container $container has $ERROR_COUNT errors in logs${NC}"
    docker logs dive25-$container 2>&1 | grep -i error | head -5
  else
    echo -e "${GREEN}✓ No errors found in $container logs${NC}"
  fi
done

# Final assessment
print_header "DEPLOYMENT TEST SUMMARY"
TOTAL_CONTAINERS=$(docker-compose ps --services | wc -l)
HEALTHY_CONTAINERS=$(docker-compose ps | grep "Up" | wc -l)

echo -e "Total containers: $TOTAL_CONTAINERS"
echo -e "Healthy containers: $HEALTHY_CONTAINERS"

if [ $TOTAL_CONTAINERS -eq $HEALTHY_CONTAINERS ]; then
  echo -e "\n${GREEN}✓ DEPLOYMENT TEST SUCCESSFUL: All containers are running${NC}"
else
  echo -e "\n${YELLOW}! DEPLOYMENT TEST PARTIAL: $HEALTHY_CONTAINERS out of $TOTAL_CONTAINERS containers are running${NC}"
  
  # List unhealthy containers
  echo -e "\nUnhealthy containers:"
  docker-compose ps | grep -v "Up"
fi

echo -e "\n${BLUE}To access services:${NC}"
echo -e "- MongoDB Express: http://localhost:8081"
echo -e "- Keycloak: http://localhost:${DEV_KEYCLOAK_PORT:-8080}"
echo -e "- phpLDAPadmin: http://localhost:8085"
echo -e "- Kong Admin API: http://localhost:8001"
echo -e "- Konga: http://localhost:1337"
echo -e "- API: http://localhost:${DEV_API_PORT:-3000}"
echo -e "- Frontend: http://localhost:${DEV_FRONTEND_PORT:-3001}"
echo -e "- Prometheus: http://localhost:9090"
echo -e "- Grafana: http://localhost:3100" 