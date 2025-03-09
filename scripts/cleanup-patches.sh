#!/bin/bash
set -e

# Cleanup Patch Scripts
# This script removes redundant patch/fix scripts that have been consolidated
# into the main configuration files (kong/configure-oidc.sh and keycloak themes)

echo "========================================================"
echo "DIVE25 - Redundant Patch Cleanup"
echo "========================================================"
echo "This script will remove redundant patch scripts that have been"
echo "consolidated into the main configuration files:"
echo ""
echo "Kong fixes consolidated into: "
echo "  - kong/kong-configure-unified.sh (for routes, DNS, SSL, OIDC)"
echo "  - kong/Dockerfile (for container setup)"
echo ""
echo "Keycloak fixes consolidated into: "
echo "  - keycloak/themes/dive25/login/resources/js/login-config.js (for redirects)"
echo "  - keycloak/configure-keycloak-unified.sh (for realm, CSP, and issuer config)"
echo "  - keycloak/Dockerfile (for theme configuration)"
echo ""
echo "The following files will be removed:"
echo "1. kong/fix-oidc-dns.sh"
echo "2. kong/fix-oidc-dns-summary.md"
echo "3. keycloak/fix-keycloak-config.sh"
echo "4. keycloak/fix-keycloak-redirect.sh"
echo "5. keycloak/fix-keycloak-realm.sh"
echo "6. keycloak/fix-keycloak-well-known.sh"
echo "7. keycloak/fix-redirect-comprehensive.sh"
echo "8. keycloak/backup-fix-keycloak-config.sh"
echo "9. fix-keycloak-port.sh"
echo "10. keycloak/redirect-fix-summary.md"
echo "11. keycloak/redirect-fix-summary-final.md"
echo "12. keycloak/configure-issuer.sh"
echo "13. keycloak/configure-csp.sh"
echo "14. update-keycloak-port.sh"
echo "15. update-keycloak-url.sh"
echo "16. keycloak/configure-keycloak.sh"
echo "17. kong/fix-kong-config.sh"
echo "18. kong/reset-kong-dns.sh"
echo "19. reset-kong-dns.sh"
echo "20. fix-redirect-comprehensive.sh"
echo "21. kong/configure-oidc.sh"
echo "22. kong/kong-configure.sh"
echo ""

# Confirm with user before proceeding
read -p "Do you want to proceed with deletion? (y/n): " confirm
if [[ $confirm != "y" && $confirm != "Y" ]]; then
    echo "Operation cancelled. No files were deleted."
    exit 0
fi

echo ""
echo "Proceeding with deletion..."

# Function to safely remove a file if it exists
remove_if_exists() {
    if [ -f "$1" ]; then
        rm "$1"
        echo "✓ Removed: $1"
    else
        echo "⚠ File not found, skipping: $1"
    fi
}

# Remove Kong fix scripts
remove_if_exists "kong/fix-oidc-dns.sh"
remove_if_exists "kong/fix-oidc-dns-summary.md"
remove_if_exists "kong/fix-kong-config.sh"
remove_if_exists "kong/reset-kong-dns.sh"
remove_if_exists "kong/configure-oidc.sh"
remove_if_exists "kong/kong-configure.sh"

# Remove Keycloak fix scripts
remove_if_exists "keycloak/fix-keycloak-config.sh"
remove_if_exists "keycloak/fix-keycloak-redirect.sh"
remove_if_exists "keycloak/fix-keycloak-realm.sh"
remove_if_exists "keycloak/fix-keycloak-well-known.sh"
remove_if_exists "keycloak/fix-redirect-comprehensive.sh"
remove_if_exists "keycloak/backup-fix-keycloak-config.sh"
remove_if_exists "keycloak/redirect-fix-summary.md"
remove_if_exists "keycloak/redirect-fix-summary-final.md"
remove_if_exists "keycloak/configure-issuer.sh"
remove_if_exists "keycloak/configure-csp.sh"
remove_if_exists "keycloak/configure-keycloak.sh"

# Remove root fix scripts
remove_if_exists "fix-keycloak-port.sh"
remove_if_exists "update-keycloak-port.sh"
remove_if_exists "update-keycloak-url.sh"
remove_if_exists "reset-kong-dns.sh"
remove_if_exists "fix-redirect-comprehensive.sh"

echo ""
echo "✅ Cleanup completed successfully!"
echo ""
echo "The fixes from these scripts have been consolidated into:"
echo "- kong/kong-configure-unified.sh for all Kong configuration (DNS, SSL, OIDC, routes)"
echo "- keycloak/themes/dive25/login/resources/js/login-config.js for Keycloak redirects"
echo "- keycloak/configure-keycloak-unified.sh for Keycloak realm and security configuration"
echo "- keycloak/Dockerfile for theme configuration"
echo ""
echo "Documentation for these fixes is available in:"
echo "- docs/troubleshooting/infinite-redirection-fix.md"
echo "- README.md (Authentication Configuration section)"
echo "" 