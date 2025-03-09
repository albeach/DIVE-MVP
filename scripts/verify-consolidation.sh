#!/bin/bash
set -e

# DIVE25 Authentication Configuration Verification Script
# This script checks that the consolidated authentication approach is properly implemented

echo "==============================================="
echo "DIVE25 Authentication Configuration Verification"
echo "==============================================="
echo "Checking for consolidated authentication files..."
echo

# Define files that should exist
REQUIRED_FILES=(
  "kong/kong-configure-unified.sh"
  "keycloak/themes/dive25/login/resources/js/login-config.js"
  "keycloak/Dockerfile"
  "keycloak/configure-keycloak-unified.sh"
  "scripts/cleanup-patches.sh"
  "scripts/setup-and-test.sh"
)

# Define redundant files that should be removed
REDUNDANT_FILES=(
  "kong/fix-oidc-dns.sh"
  "kong/fix-oidc-dns-summary.md"
  "kong/fix-kong-config.sh"
  "kong/reset-kong-dns.sh"
  "kong/configure-oidc.sh"
  "kong/kong-configure.sh"
  "keycloak/fix-keycloak-config.sh"
  "keycloak/fix-keycloak-redirect.sh"
  "keycloak/fix-keycloak-realm.sh"
  "keycloak/fix-keycloak-well-known.sh"
  "keycloak/fix-redirect-comprehensive.sh"
  "keycloak/backup-fix-keycloak-config.sh"
  "fix-keycloak-port.sh"
  "keycloak/redirect-fix-summary.md"
  "keycloak/redirect-fix-summary-final.md"
  "keycloak/configure-issuer.sh"
  "keycloak/configure-csp.sh"
  "update-keycloak-port.sh"
  "update-keycloak-url.sh"
  "keycloak/configure-keycloak.sh"
  "reset-kong-dns.sh"
  "fix-redirect-comprehensive.sh"
)

# Check required files
echo "1. Checking for required files:"
MISSING_FILES=0
for file in "${REQUIRED_FILES[@]}"; do
  if [ -f "$file" ]; then
    echo "  ✅ Found: $file"
  else
    echo "  ❌ Missing: $file"
    MISSING_FILES=$((MISSING_FILES+1))
  fi
done

# Check if redundant files have been removed
echo
echo "2. Checking for redundant fix scripts:"

REDUNDANT_FOUND=0
for file in "${REDUNDANT_FILES[@]}"; do
  if [ -f "$file" ]; then
    echo "  ⚠️ Redundant file still exists: $file"
    REDUNDANT_FOUND=$((REDUNDANT_FOUND+1))
  else
    echo "  ✅ Removed: $file"
  fi
done

# Check if setup-and-test.sh includes the cleanup step
echo
echo "3. Checking if setup-and-test.sh includes cleanup step:"
if grep -q "cleanup-patches.sh" scripts/setup-and-test.sh; then
  echo "  ✅ setup-and-test.sh includes the cleanup step"
  CLEANUP_INCLUDED=true
else
  echo "  ❌ setup-and-test.sh does not include the cleanup step"
  CLEANUP_INCLUDED=false
fi

# Check if key required scripts contain the necessary configuration
echo
echo "4. Verifying script contents:"

# Check unified Kong script for key configurations
if [ -f "kong/kong-configure-unified.sh" ]; then
  if grep -q "configure_oidc" kong/kong-configure-unified.sh && \
     grep -q "reset_kong_dns" kong/kong-configure-unified.sh && \
     grep -q "configure_port_8443" kong/kong-configure-unified.sh && \
     grep -q "setup_ssl" kong/kong-configure-unified.sh; then
    echo "  ✅ kong-configure-unified.sh contains required configuration functions"
  else
    echo "  ❌ kong-configure-unified.sh is missing required configuration functions"
  fi
fi

# Check Dockerfile for theme configuration
if [ -f "keycloak/Dockerfile" ]; then
  if grep -q "login-config.js" keycloak/Dockerfile; then
    echo "  ✅ Dockerfile includes login-config.js setup"
  else
    echo "  ❌ Dockerfile does not include login-config.js setup"
  fi
fi

# Check login-config.js for key functionality
if [ -f "keycloak/themes/dive25/login/resources/js/login-config.js" ]; then
  if grep -q "well-known/openid-configuration" keycloak/themes/dive25/login/resources/js/login-config.js && \
     grep -q "redirect_uri" keycloak/themes/dive25/login/resources/js/login-config.js; then
    echo "  ✅ login-config.js contains required redirect fixes"
  else
    echo "  ❌ login-config.js is missing required redirect fixes"
  fi
fi

# Check unified Keycloak script for key configurations
if [ -f "keycloak/configure-keycloak-unified.sh" ]; then
  if grep -q "update_issuer_url" keycloak/configure-keycloak-unified.sh && \
     grep -q "configure_csp" keycloak/configure-keycloak-unified.sh && \
     grep -q "configure_clients" keycloak/configure-keycloak-unified.sh; then
    echo "  ✅ configure-keycloak-unified.sh contains required configuration functions"
  else
    echo "  ❌ configure-keycloak-unified.sh is missing required configuration functions"
  fi
fi

echo
echo "==============================================="
echo "Verification Summary"
echo "==============================================="

if [ $MISSING_FILES -eq 0 ]; then
  echo "✅ All required files are present"
else
  echo "❌ $MISSING_FILES required files are missing"
fi

if [ $REDUNDANT_FOUND -eq 0 ]; then
  echo "✅ All redundant fix scripts have been removed"
else
  echo "⚠️ $REDUNDANT_FOUND redundant fix scripts still exist (run cleanup-patches.sh to remove)"
fi

if [ "$CLEANUP_INCLUDED" = true ]; then
  echo "✅ setup-and-test.sh includes the cleanup step"
else
  echo "❌ setup-and-test.sh does not include the cleanup step"
fi

if [ $MISSING_FILES -eq 0 ] && [ "$CLEANUP_INCLUDED" = true ]; then
  echo
  echo "🎉 Consolidated authentication configuration is PROPERLY IMPLEMENTED!"
  echo "Authentication will work correctly with the consolidated approach."
else
  echo
  echo "⚠️ Consolidated authentication configuration is INCOMPLETE!"
  echo "Please fix the issues mentioned above to complete the implementation."
fi 