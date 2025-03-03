#!/bin/bash
# keycloak/update-theme.sh
# Updates the dive25 theme in Keycloak

set -e

# Set variables
KEYCLOAK_CONTAINER=${KEYCLOAK_CONTAINER:-"dive25-keycloak"}
THEME_PATH="/opt/keycloak/themes/dive25"
CONFIG_FILE="update-theme.json"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== DIVE25 Theme Update Utility ===${NC}"

# Check if the container is running
if ! docker ps | grep -q $KEYCLOAK_CONTAINER; then
    echo -e "${RED}Error: Keycloak container '$KEYCLOAK_CONTAINER' is not running.${NC}"
    echo "Please start the container first with 'docker-compose up -d keycloak'"
    exit 1
fi

# Read the configuration file
if [ -f "$CONFIG_FILE" ]; then
    echo -e "${GREEN}Reading configuration from $CONFIG_FILE${NC}"
    CONFIG_CONTENT=$(cat "$CONFIG_FILE")
    # Extract values from JSON
    INCLUDE_LOGIN=$(echo "$CONFIG_CONTENT" | grep -o '"login": *[^,}]*' | cut -d: -f2 | tr -d ' "')
    INCLUDE_WELCOME=$(echo "$CONFIG_CONTENT" | grep -o '"welcome": *[^,}]*' | cut -d: -f2 | tr -d ' "')
    INCLUDE_ADMIN=$(echo "$CONFIG_CONTENT" | grep -o '"admin": *[^,}]*' | cut -d: -f2 | tr -d ' "')
else
    echo -e "${YELLOW}Warning: Configuration file $CONFIG_FILE not found. Using defaults.${NC}"
    INCLUDE_LOGIN=true
    INCLUDE_WELCOME=true
    INCLUDE_ADMIN=true
fi

echo "Theme components to update:"
echo "  Login theme: $([ "$INCLUDE_LOGIN" = "true" ] && echo -e "${GREEN}Yes${NC}" || echo -e "${RED}No${NC}")"
echo "  Welcome theme: $([ "$INCLUDE_WELCOME" = "true" ] && echo -e "${GREEN}Yes${NC}" || echo -e "${RED}No${NC}")"
echo "  Admin theme: $([ "$INCLUDE_ADMIN" = "true" ] && echo -e "${GREEN}Yes${NC}" || echo -e "${RED}No${NC}")"

# Create a temporary directory
echo -e "${YELLOW}Creating temporary directory...${NC}"
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

# Copy theme files to temporary directory
echo -e "${YELLOW}Copying theme files...${NC}"
mkdir -p "$TEMP_DIR/dive25"

# Copy login theme
if [ "$INCLUDE_LOGIN" = "true" ]; then
    echo "Copying login theme..."
    cp -r themes/dive25/login "$TEMP_DIR/dive25/"
fi

# Copy welcome theme
if [ "$INCLUDE_WELCOME" = "true" ]; then
    echo "Copying welcome theme..."
    cp -r themes/dive25/welcome "$TEMP_DIR/dive25/"
fi

# Copy admin theme
if [ "$INCLUDE_ADMIN" = "true" ]; then
    echo "Copying admin theme..."
    cp -r themes/dive25/admin "$TEMP_DIR/dive25/"
fi

# Copy theme files to container
echo -e "${YELLOW}Copying theme files to container...${NC}"
docker cp "$TEMP_DIR/dive25" $KEYCLOAK_CONTAINER:"$THEME_PATH/.."

# Verify the copy
echo -e "${YELLOW}Verifying theme installation...${NC}"
VERIFICATION=$(docker exec $KEYCLOAK_CONTAINER ls -la "$THEME_PATH")

if echo "$VERIFICATION" | grep -q "login" && [ "$INCLUDE_LOGIN" = "true" ]; then
    echo -e "  Login theme: ${GREEN}Installed${NC}"
else
    [ "$INCLUDE_LOGIN" = "true" ] && echo -e "  Login theme: ${RED}Not installed${NC}"
fi

if echo "$VERIFICATION" | grep -q "welcome" && [ "$INCLUDE_WELCOME" = "true" ]; then
    echo -e "  Welcome theme: ${GREEN}Installed${NC}"
else
    [ "$INCLUDE_WELCOME" = "true" ] && echo -e "  Welcome theme: ${RED}Not installed${NC}"
fi

if echo "$VERIFICATION" | grep -q "admin" && [ "$INCLUDE_ADMIN" = "true" ]; then
    echo -e "  Admin theme: ${GREEN}Installed${NC}"
else
    [ "$INCLUDE_ADMIN" = "true" ] && echo -e "  Admin theme: ${RED}Not installed${NC}"
fi

echo -e "${GREEN}Theme update completed.${NC}"
echo "You may need to restart the Keycloak container for the changes to take effect."
echo "Run 'docker restart $KEYCLOAK_CONTAINER' to restart Keycloak." 