#!/bin/bash
# keycloak/update-theme-docker.sh
# Updates the dive25 theme in Keycloak Docker container

set -e

# Set variables
KEYCLOAK_CONTAINER=${KEYCLOAK_CONTAINER:-"dive25-staging-keycloak"}
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
    echo -e "${GREEN}Keycloak restarted. The theme will be applied on next login.${NC}"
else
    echo -e "${YELLOW}Remember to restart Keycloak manually for changes to take effect.${NC}"
fi 