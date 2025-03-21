#!/bin/bash
# This script validates that all required environment variables are set before deployment
# Usage: ./scripts/validate-env.sh [environment]

set -e

# Set color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Environment to validate (.env, .env.staging, .env.production, etc.)
ENV_FILE=".env"
if [ -n "$1" ]; then
  ENV_FILE=".env.$1"
fi

echo -e "${BLUE}Validating environment variables in ${ENV_FILE}...${NC}"

# Load environment file if exists
if [ ! -f "$ENV_FILE" ]; then
  echo -e "${RED}Error: Environment file $ENV_FILE does not exist!${NC}"
  exit 1
fi

# Source the environment file
source "$ENV_FILE"

# Arrays of required variables
NEXTJS_REQUIRED_VARS=(
  "NEXT_PUBLIC_API_URL"
  "NEXT_PUBLIC_FRONTEND_URL"
  "NEXT_PUBLIC_KEYCLOAK_URL"
  "NEXT_PUBLIC_KEYCLOAK_REALM"
  "NEXT_PUBLIC_KEYCLOAK_CLIENT_ID"
  "NEXT_PUBLIC_KONG_URL"
)

KEYCLOAK_REQUIRED_VARS=(
  "KEYCLOAK_ADMIN"
  "KEYCLOAK_ADMIN_PASSWORD"
  "KEYCLOAK_REALM"
  "KEYCLOAK_CLIENT_ID_FRONTEND"
  "KEYCLOAK_CLIENT_ID_API"
  "KEYCLOAK_CLIENT_SECRET"
)

NETWORK_REQUIRED_VARS=(
  "BASE_DOMAIN"
  "FRONTEND_PORT"
  "API_PORT"
  "KEYCLOAK_PORT"
)

# Check all required Next.js variables
echo -e "${BLUE}Checking Next.js client-side environment variables...${NC}"
NEXTJS_MISSING=0
for var in "${NEXTJS_REQUIRED_VARS[@]}"; do
  value="${!var}"
  if [ -z "$value" ]; then
    echo -e "${RED}✗ Missing: $var${NC}"
    NEXTJS_MISSING=$((NEXTJS_MISSING+1))
  else
    echo -e "${GREEN}✓ $var = $value${NC}"
  fi
done

# Check all required Keycloak variables
echo -e "\n${BLUE}Checking Keycloak environment variables...${NC}"
KEYCLOAK_MISSING=0
for var in "${KEYCLOAK_REQUIRED_VARS[@]}"; do
  value="${!var}"
  if [ -z "$value" ]; then
    echo -e "${RED}✗ Missing: $var${NC}"
    KEYCLOAK_MISSING=$((KEYCLOAK_MISSING+1))
  else
    echo -e "${GREEN}✓ $var = $value${NC}"
  fi
done

# Check all required network variables
echo -e "\n${BLUE}Checking network configuration variables...${NC}"
NETWORK_MISSING=0
for var in "${NETWORK_REQUIRED_VARS[@]}"; do
  value="${!var}"
  if [ -z "$value" ]; then
    echo -e "${RED}✗ Missing: $var${NC}"
    NETWORK_MISSING=$((NETWORK_MISSING+1))
  else
    echo -e "${GREEN}✓ $var = $value${NC}"
  fi
done

# Additional validation for URL formats
echo -e "\n${BLUE}Validating URL formats...${NC}"
URL_ERRORS=0

# Check if a string is a valid URL
validate_url() {
  if [[ "$1" =~ ^https?:// ]]; then
    return 0
  else
    return 1
  fi
}

# Validate NEXT_PUBLIC_API_URL if set
if [ -n "$NEXT_PUBLIC_API_URL" ]; then
  if validate_url "$NEXT_PUBLIC_API_URL"; then
    echo -e "${GREEN}✓ NEXT_PUBLIC_API_URL has valid format${NC}"
  else
    echo -e "${RED}✗ NEXT_PUBLIC_API_URL has invalid format: $NEXT_PUBLIC_API_URL${NC}"
    URL_ERRORS=$((URL_ERRORS+1))
  fi
fi

# Validate NEXT_PUBLIC_FRONTEND_URL if set
if [ -n "$NEXT_PUBLIC_FRONTEND_URL" ]; then
  if validate_url "$NEXT_PUBLIC_FRONTEND_URL"; then
    echo -e "${GREEN}✓ NEXT_PUBLIC_FRONTEND_URL has valid format${NC}"
  else
    echo -e "${RED}✗ NEXT_PUBLIC_FRONTEND_URL has invalid format: $NEXT_PUBLIC_FRONTEND_URL${NC}"
    URL_ERRORS=$((URL_ERRORS+1))
  fi
fi

# Validate NEXT_PUBLIC_KEYCLOAK_URL if set
if [ -n "$NEXT_PUBLIC_KEYCLOAK_URL" ]; then
  if validate_url "$NEXT_PUBLIC_KEYCLOAK_URL"; then
    echo -e "${GREEN}✓ NEXT_PUBLIC_KEYCLOAK_URL has valid format${NC}"
  else
    echo -e "${RED}✗ NEXT_PUBLIC_KEYCLOAK_URL has invalid format: $NEXT_PUBLIC_KEYCLOAK_URL${NC}"
    URL_ERRORS=$((URL_ERRORS+1))
  fi
fi

# Validate NEXT_PUBLIC_KONG_URL if set
if [ -n "$NEXT_PUBLIC_KONG_URL" ]; then
  if validate_url "$NEXT_PUBLIC_KONG_URL"; then
    echo -e "${GREEN}✓ NEXT_PUBLIC_KONG_URL has valid format${NC}"
  else
    echo -e "${RED}✗ NEXT_PUBLIC_KONG_URL has invalid format: $NEXT_PUBLIC_KONG_URL${NC}"
    URL_ERRORS=$((URL_ERRORS+1))
  fi
fi

# Print summary of validation
echo -e "\n${BLUE}Validation Summary:${NC}"
echo -e "Next.js variables: ${NEXTJS_MISSING} missing"
echo -e "Keycloak variables: ${KEYCLOAK_MISSING} missing"
echo -e "Network variables: ${NETWORK_MISSING} missing"
echo -e "URL format errors: ${URL_ERRORS}"

# Determine if validation passed
TOTAL_ERRORS=$((NEXTJS_MISSING + KEYCLOAK_MISSING + NETWORK_MISSING + URL_ERRORS))
if [ $TOTAL_ERRORS -eq 0 ]; then
  echo -e "\n${GREEN}✅ All required environment variables are properly set!${NC}"
  exit 0
else
  echo -e "\n${RED}❌ Validation failed with $TOTAL_ERRORS errors!${NC}"
  echo -e "${YELLOW}Please fix the missing or invalid environment variables before deploying.${NC}"
  exit 1
fi 