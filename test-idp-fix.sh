#!/bin/bash
# Script to test the fix for identity providers

# Set up colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}===== Testing Identity Provider Configuration Fix =====${NC}\n"
echo -e "${BLUE}Using environment variables where available or falling back to defaults${NC}\n"

# Function to check if a file contains the proper Keycloak IdP configuration
check_idp_config() {
  local idp_file=$1
  local idp_name=$(basename "$idp_file" | sed 's/-idp-config.json//')
  local base_domain=${BASE_DOMAIN:-dive25.local}
  local keycloak_subdomain=${KEYCLOAK_SUBDOMAIN:-keycloak}
  
  echo -e "${BLUE}Checking $idp_name configuration...${NC}"
  
  # Look for any Keycloak endpoint in the IdP config file
  if grep -q "$keycloak_subdomain.$base_domain" "$idp_file" || grep -q "keycloak.dive25.local" "$idp_file"; then
    echo -e "${GREEN}✓ $idp_name is correctly configured to use Keycloak as IdP${NC}"
    return 0
  else
    echo -e "${RED}✗ $idp_name is NOT correctly configured${NC}"
    return 1
  fi
}

# Main test routine
errors=0

# Check all IdP configuration files
for idp_file in keycloak/identity-providers/*-oidc-idp-config.json; do
  if ! check_idp_config "$idp_file"; then
    errors=$((errors + 1))
  fi
done

# Check if the fix-idps.sh script exists
if [ -f "keycloak/fix-idps.sh" ]; then
  echo -e "${GREEN}✓ keycloak/fix-idps.sh exists to apply the fix${NC}"
else
  echo -e "${YELLOW}! Warning: keycloak/fix-idps.sh is missing${NC}"
  errors=$((errors + 1))
fi

# Final verdict
echo -e "\n${BLUE}===== Test Results =====${NC}"
if [ $errors -eq 0 ]; then
  echo -e "${GREEN}All IdP configurations are properly set up!${NC}"
  echo -e "${GREEN}The fix for the white page issue should work correctly.${NC}"
else
  echo -e "${RED}$errors issues found in the IdP configurations.${NC}"
  echo -e "${YELLOW}Please correct these issues before testing the application.${NC}"
fi

exit $errors 