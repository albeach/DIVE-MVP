#!/bin/bash
# keycloak/test-theme.sh
# Test the dive25 theme in Keycloak

# Set variables
KEYCLOAK_URL=${KEYCLOAK_URL:-"http://localhost:8080"}
ADMIN_USER=${KEYCLOAK_ADMIN:-"admin"}
ADMIN_PASSWORD=${KEYCLOAK_ADMIN_PASSWORD:-"admin"}
REALM="dive25"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== DIVE25 Theme Test Utility ===${NC}"
echo "Testing Keycloak theme at $KEYCLOAK_URL"

# Get admin token
echo -e "${YELLOW}Getting admin token...${NC}"
ADMIN_TOKEN=$(curl -s -X POST "$KEYCLOAK_URL/realms/master/protocol/openid-connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "username=$ADMIN_USER" \
    -d "password=$ADMIN_PASSWORD" \
    -d "grant_type=password" \
    -d "client_id=admin-cli" | grep -o '"access_token":"[^"]*"' | cut -d':' -f2 | tr -d '"')

if [ -z "$ADMIN_TOKEN" ]; then
    echo -e "${RED}Failed to get admin token. Check your credentials and make sure Keycloak is running.${NC}"
    exit 1
fi

echo -e "${GREEN}Admin token acquired successfully.${NC}"

# Check if realm exists
echo -e "${YELLOW}Checking if $REALM realm exists...${NC}"
REALM_EXISTS=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $ADMIN_TOKEN" $KEYCLOAK_URL/admin/realms/$REALM)

if [ "$REALM_EXISTS" -eq 404 ]; then
    echo -e "${RED}The $REALM realm does not exist. Please create it first.${NC}"
    exit 1
fi

echo -e "${GREEN}Realm $REALM exists.${NC}"

# Get current theme settings
echo -e "${YELLOW}Getting current theme settings...${NC}"
REALM_INFO=$(curl -s -H "Authorization: Bearer $ADMIN_TOKEN" $KEYCLOAK_URL/admin/realms/$REALM)

LOGIN_THEME=$(echo $REALM_INFO | grep -o '"loginTheme":"[^"]*"' | cut -d':' -f2 | tr -d '"')
ACCOUNT_THEME=$(echo $REALM_INFO | grep -o '"accountTheme":"[^"]*"' | cut -d':' -f2 | tr -d '"')
ADMIN_THEME=$(echo $REALM_INFO | grep -o '"adminTheme":"[^"]*"' | cut -d':' -f2 | tr -d '"')
EMAIL_THEME=$(echo $REALM_INFO | grep -o '"emailTheme":"[^"]*"' | cut -d':' -f2 | tr -d '"')

echo "Current theme settings:"
echo "  Login theme: ${LOGIN_THEME:-none}"
echo "  Account theme: ${ACCOUNT_THEME:-none}"
echo "  Admin theme: ${ADMIN_THEME:-none}"
echo "  Email theme: ${EMAIL_THEME:-none}"

# Set the dive25 theme
echo -e "${YELLOW}Setting the dive25 theme for all components...${NC}"
curl -s -X PUT "$KEYCLOAK_URL/admin/realms/$REALM" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
        \"id\": \"$REALM\",
        \"realm\": \"$REALM\",
        \"loginTheme\": \"dive25\",
        \"accountTheme\": \"dive25\",
        \"adminTheme\": \"dive25\",
        \"emailTheme\": \"dive25\"
    }" > /dev/null

# Check if the theme was set
echo -e "${YELLOW}Verifying theme settings...${NC}"
REALM_INFO=$(curl -s -H "Authorization: Bearer $ADMIN_TOKEN" $KEYCLOAK_URL/admin/realms/$REALM)

NEW_LOGIN_THEME=$(echo $REALM_INFO | grep -o '"loginTheme":"[^"]*"' | cut -d':' -f2 | tr -d '"')
NEW_ACCOUNT_THEME=$(echo $REALM_INFO | grep -o '"accountTheme":"[^"]*"' | cut -d':' -f2 | tr -d '"')
NEW_ADMIN_THEME=$(echo $REALM_INFO | grep -o '"adminTheme":"[^"]*"' | cut -d':' -f2 | tr -d '"')
NEW_EMAIL_THEME=$(echo $REALM_INFO | grep -o '"emailTheme":"[^"]*"' | cut -d':' -f2 | tr -d '"')

echo "New theme settings:"
echo "  Login theme: ${NEW_LOGIN_THEME:-none} $([ "$NEW_LOGIN_THEME" = "dive25" ] && echo -e "${GREEN}[OK]${NC}" || echo -e "${RED}[FAILED]${NC}")"
echo "  Account theme: ${NEW_ACCOUNT_THEME:-none} $([ "$NEW_ACCOUNT_THEME" = "dive25" ] && echo -e "${GREEN}[OK]${NC}" || echo -e "${RED}[FAILED]${NC}")"
echo "  Admin theme: ${NEW_ADMIN_THEME:-none} $([ "$NEW_ADMIN_THEME" = "dive25" ] && echo -e "${GREEN}[OK]${NC}" || echo -e "${RED}[FAILED]${NC}")"
echo "  Email theme: ${NEW_EMAIL_THEME:-none} $([ "$NEW_EMAIL_THEME" = "dive25" ] && echo -e "${GREEN}[OK]${NC}" || echo -e "${RED}[FAILED]${NC}")"

echo -e "${BLUE}=== Theme Test URLs ===${NC}"
echo "Login page: $KEYCLOAK_URL/realms/$REALM/protocol/openid-connect/auth?client_id=account-console&redirect_uri=$KEYCLOAK_URL/realms/$REALM/account/&response_type=code"
echo "Welcome page: $KEYCLOAK_URL/realms/$REALM/account/"
echo "Admin console: $KEYCLOAK_URL/admin/$REALM/console/"

echo -e "${GREEN}Theme test completed.${NC}"
echo "Note: You may need to clear your browser cache to see the changes." 