#!/bin/bash
set -e

echo "==== Cleaning up miscellaneous patch scripts ===="
echo "Now that all fixes have been consolidated into the main configuration files,"
echo "we can remove these one-off patch scripts to keep the repository clean."

# List of Kong-related patch scripts to remove
KONG_PATCHES=(
  "kong/fix-oidc-dns.sh"
  "kong/fix-oidc-dns-summary.md"
)

# List of Keycloak-related patch scripts to remove
KEYCLOAK_PATCHES=(
  "keycloak/fix-keycloak-config.sh"
  "keycloak/fix-keycloak-redirect.sh"
  "fix-keycloak-port.sh"
  "keycloak/fix-keycloak-realm.sh"
  "keycloak/fix-keycloak-well-known.sh"
  "keycloak/fix-redirect-comprehensive.sh"
  "keycloak/backup-fix-keycloak-config.sh"
  "keycloak/redirect-fix-summary.md"
  "keycloak/redirect-fix-summary-final.md"
)

# Remove Kong patches
echo "Removing Kong patches..."
for patch in "${KONG_PATCHES[@]}"; do
  if [ -f "$patch" ]; then
    echo "  - Removing $patch"
    rm "$patch"
  else
    echo "  - $patch not found, skipping"
  fi
done

# Remove Keycloak patches
echo "Removing Keycloak patches..."
for patch in "${KEYCLOAK_PATCHES[@]}"; do
  if [ -f "$patch" ]; then
    echo "  - Removing $patch"
    rm "$patch"
  else
    echo "  - $patch not found, skipping"
  fi
done

echo ""
echo "All miscellaneous patch scripts have been removed."
echo "The fixes are now incorporated into the main configuration files:"
echo "  - kong/configure-oidc.sh"
echo "  - keycloak/themes/dive25/login/resources/js/login-config.js"
echo "  - keycloak/Dockerfile"
echo ""
echo "The setup process is now simplified. You can run your setup-and-test.sh script as usual,"
echo "and the authentication should work correctly without needing additional patches." 