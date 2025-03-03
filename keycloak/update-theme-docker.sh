#!/bin/bash
# keycloak/update-theme-docker.sh
# Updates the dive25 theme in Keycloak Docker container

set -e

# Set variables
KEYCLOAK_CONTAINER=${KEYCLOAK_CONTAINER:-"dive25-keycloak"}
THEME_PATH="/opt/keycloak/themes/dive25"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== DIVE25 Theme Docker Update Utility ===${NC}"

# Check if the container is running
if ! docker ps | grep -q $KEYCLOAK_CONTAINER; then
    echo -e "${RED}Error: Keycloak container '$KEYCLOAK_CONTAINER' is not running.${NC}"
    echo "Please start the container first with 'docker-compose up -d keycloak'"
    exit 1
fi

# Create the target directory in the container if it doesn't exist
echo -e "${YELLOW}Creating theme directory in container...${NC}"
docker exec $KEYCLOAK_CONTAINER mkdir -p "$THEME_PATH"

# Copy all theme files to container
echo -e "${YELLOW}Copying theme files to container...${NC}"
docker cp themes/dive25/. $KEYCLOAK_CONTAINER:"$THEME_PATH"

# Show the result of the copy
echo -e "${YELLOW}Verifying theme installation...${NC}"
docker exec $KEYCLOAK_CONTAINER ls -la "$THEME_PATH"

echo -e "${GREEN}Theme files updated successfully.${NC}"
echo "You need to restart the Keycloak container for the changes to take effect."
echo "Run: docker restart $KEYCLOAK_CONTAINER"

# Ask if the user wants to restart Keycloak
read -p "Do you want to restart Keycloak now? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Restarting Keycloak...${NC}"
    docker restart $KEYCLOAK_CONTAINER
    
    echo -e "${YELLOW}Waiting for Keycloak to start...${NC}"
    sleep 5
    
    # Wait for Keycloak to be ready (max 60 seconds)
    MAX_RETRIES=12
    COUNTER=0
    while ! docker exec $KEYCLOAK_CONTAINER curl -s http://localhost:8080/health/ready > /dev/null; do
        COUNTER=$((COUNTER+1))
        if [ $COUNTER -eq $MAX_RETRIES ]; then
            echo -e "${RED}Keycloak did not start within the expected time.${NC}"
            echo "Please check the logs with: docker logs $KEYCLOAK_CONTAINER"
            exit 1
        fi
        echo -e "${YELLOW}Keycloak not ready yet... waiting 5 seconds (attempt $COUNTER/$MAX_RETRIES)${NC}"
        sleep 5
    done
    
    echo -e "${GREEN}Keycloak has been restarted and is ready.${NC}"
    
    # Apply theme settings through API
    echo -e "${YELLOW}Setting the theme for the dive25 realm...${NC}"
    docker exec $KEYCLOAK_CONTAINER /bin/bash -c 'cd /opt/keycloak && ./bin/kcadm.sh config credentials --server http://localhost:8080/ --realm master --user "$KEYCLOAK_ADMIN" --password "$KEYCLOAK_ADMIN_PASSWORD" && ./bin/kcadm.sh update realms/dive25 -s "loginTheme=dive25" -s "accountTheme=dive25" -s "adminTheme=dive25" -s "emailTheme=dive25"'
    
    echo -e "${GREEN}Theme settings have been applied.${NC}"
    echo "The dive25 theme is now active. Access it at:"
    echo "  http://localhost:8080/realms/dive25/protocol/openid-connect/auth?client_id=account-console&redirect_uri=http://localhost:8080/realms/dive25/account/&response_type=code"
else
    echo -e "${YELLOW}Keycloak was not restarted. Please restart it manually to apply the changes.${NC}"
fi 