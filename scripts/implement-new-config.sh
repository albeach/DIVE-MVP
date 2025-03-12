#!/bin/bash
#
# DIVE25 New Configuration Implementation Script
# ==============================================
#
# This script helps implement the new configuration system.
#
# Usage:
#   ./scripts/implement-new-config.sh [environment]
#
# Arguments:
#   environment - The environment to implement (dev, staging, prod)
#                 Defaults to the value in ENVIRONMENT or staging if not set

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Set environment
ENV=${1:-${ENVIRONMENT:-staging}}
if [[ ! "$ENV" =~ ^(dev|staging|prod)$ ]]; then
  echo -e "${RED}Error: Invalid environment '$ENV'. Must be one of: dev, staging, prod${NC}"
  exit 1
fi

echo -e "${BLUE}Implementing new configuration system for ${GREEN}$ENV${BLUE} environment...${NC}"

# Step 1: Create backups
echo -e "${BLUE}Step 1: Creating backups of existing configuration...${NC}"

if [[ -f ".env" ]]; then
  cp .env .env.backup.$(date +%Y%m%d%H%M%S)
  echo -e "${GREEN}✓ Backed up .env file${NC}"
fi

if [[ -f "docker-compose.yml" ]]; then
  cp docker-compose.yml docker-compose.yml.backup.$(date +%Y%m%d%H%M%S)
  echo -e "${GREEN}✓ Backed up docker-compose.yml file${NC}"
fi

if [[ -f "kong/kong.yml" ]]; then
  cp kong/kong.yml kong/kong.yml.backup.$(date +%Y%m%d%H%M%S)
  echo -e "${GREEN}✓ Backed up kong/kong.yml file${NC}"
fi

# Step 2: Check prerequisites
echo -e "${BLUE}Step 2: Checking prerequisites...${NC}"

command -v yq >/dev/null 2>&1 || { 
  echo -e "${RED}Error: yq is required but not installed. Please install it first:${NC}" 
  echo -e "Mac: brew install yq"
  echo -e "Linux: snap install yq"
  echo -e "Or download from https://github.com/mikefarah/yq/releases"
  exit 1
}

command -v envsubst >/dev/null 2>&1 || { 
  echo -e "${RED}Error: envsubst is required but not installed.${NC}" 
  echo -e "Mac: brew install gettext && brew link --force gettext"
  echo -e "Linux: apt-get install gettext-base"
  exit 1
}

# Step 3: Check for configuration files
echo -e "${BLUE}Step 3: Checking for configuration files...${NC}"

CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/config"

if [[ ! -f "$CONFIG_DIR/base.yml" ]]; then
  echo -e "${RED}Error: Base configuration file $CONFIG_DIR/base.yml not found${NC}"
  exit 1
fi

if [[ ! -f "$CONFIG_DIR/$ENV.yml" ]]; then
  echo -e "${RED}Error: Environment configuration file $CONFIG_DIR/$ENV.yml not found${NC}"
  exit 1
fi

if [[ ! -f "$CONFIG_DIR/templates/docker-compose.template.yml" ]]; then
  echo -e "${YELLOW}Warning: Docker Compose template file $CONFIG_DIR/templates/docker-compose.template.yml not found${NC}"
fi

if [[ ! -f "$CONFIG_DIR/templates/kong.template.yml" ]]; then
  echo -e "${YELLOW}Warning: Kong template file $CONFIG_DIR/templates/kong.template.yml not found${NC}"
fi

# Step 4: Generate configuration
echo -e "${BLUE}Step 4: Generating configuration...${NC}"

./scripts/generate-config.sh $ENV

if [[ $? -ne 0 ]]; then
  echo -e "${RED}Error: Configuration generation failed${NC}"
  exit 1
fi

echo -e "${GREEN}✓ Configuration generated successfully${NC}"

# Step 5: Apply configuration
echo -e "${BLUE}Step 5: Applying configuration...${NC}"

cp "$CONFIG_DIR/generated/.env.$ENV" .env
echo -e "${GREEN}✓ Applied .env file${NC}"

if [[ -f "$CONFIG_DIR/generated/docker-compose.$ENV.yml" ]]; then
  cp "$CONFIG_DIR/generated/docker-compose.$ENV.yml" docker-compose.yml
  echo -e "${GREEN}✓ Applied docker-compose.yml file${NC}"
else
  echo -e "${YELLOW}Warning: Generated docker-compose.$ENV.yml not found, skipping${NC}"
fi

if [[ -f "$CONFIG_DIR/generated/kong.$ENV.yml" ]]; then
  cp "$CONFIG_DIR/generated/kong.$ENV.yml" kong/kong.yml
  echo -e "${GREEN}✓ Applied kong/kong.yml file${NC}"
else
  echo -e "${YELLOW}Warning: Generated kong.$ENV.yml not found, skipping${NC}"
fi

# Step 6: Set up hosts entries (local development only)
if [[ "$ENV" != "prod" ]]; then
  echo -e "${BLUE}Step 6: Setting up hosts entries (requires sudo)...${NC}"
  
  read -p "Do you want to update your hosts file? (y/n) " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    sudo ./scripts/setup-hosts-updated.sh $ENV
    if [[ $? -ne 0 ]]; then
      echo -e "${RED}Error: Failed to update hosts file${NC}"
    else
      echo -e "${GREEN}✓ Hosts file updated successfully${NC}"
    fi
  else
    echo -e "${YELLOW}Skipping hosts file update${NC}"
  fi
fi

# Step 7: Complete
echo -e "${GREEN}✅ New configuration system implemented successfully!${NC}"
echo -e "${BLUE}To start services with the new configuration:${NC}"
echo -e "  docker-compose down"
echo -e "  docker-compose up -d"
echo ""
echo -e "${BLUE}For more information, see:${NC}"
echo -e "  docs/configuration-management.md"
echo -e "  docs/migration-guide.md" 