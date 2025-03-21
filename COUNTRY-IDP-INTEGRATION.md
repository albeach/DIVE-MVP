# Country-Specific Identity Provider Integration

This document outlines the implementation of country-specific Identity Providers (IdPs) for the DIVE25 application to enable users to authenticate through their respective country's authentication service.

## Overview

The DIVE25 application now supports multiple country-specific Identity Providers through Keycloak's Identity Provider federation feature. Users can select their country on the login screen, and they will be redirected to their country's specific authentication service.

## Supported Countries

The following countries are supported:

- 🇺🇸 United States
- 🇬🇧 United Kingdom
- 🇨🇦 Canada
- 🇦🇺 Australia
- 🇳🇿 New Zealand

## Architecture

The implementation follows these key components:

1. **Keycloak Configuration**: Each country has a dedicated Identity Provider configuration in Keycloak.
2. **Frontend Country Selection**: A new country selection page allows users to choose their country.
3. **Attribute Mapping**: Each country IdP has mapper configurations to standardize user attributes.
4. **Kong Integration**: Kong API Gateway continues to handle authentication through Keycloak.

## Authentication Flow

1. User accesses the DIVE25 application
2. User clicks "Sign In" button
3. User is redirected to the country selection page
4. User selects their country
5. User is redirected to their country's Identity Provider
6. After authentication, user is redirected back to the application with a valid token
7. Kong validates the token and allows access to protected resources

## Configuration Files

### Keycloak Identity Providers

IdP configuration files are stored in `keycloak/identity-providers/`:

- `usa-oidc-idp-config.json`: United States IdP configuration
- `uk-oidc-idp-config.json`: United Kingdom IdP configuration
- `canada-oidc-idp-config.json`: Canada IdP configuration
- `australia-oidc-idp-config.json`: Australia IdP configuration
- `newzealand-oidc-idp-config.json`: New Zealand IdP configuration

### Keycloak Configuration Scripts

- `keycloak/configure-country-idps.sh`: Script to configure country-specific IdPs in Keycloak
- Update to `keycloak/configure-keycloak.sh`: Added call to configure country IdPs

### Frontend Components

- `frontend/src/components/auth/CountrySelector.tsx`: Component for country selection
- `frontend/src/pages/country-select.tsx`: Page for country selection
- Updates to `frontend/src/context/auth-context.tsx`: Added country-specific IdP support
- Updates to `frontend/src/components/auth/LoginButton.tsx`: Modified to use country selection

## Attribute Mapping

Each country IdP is configured with the following attribute mappers:

1. **Country of Affiliation**: Maps a hardcoded country value
2. **Security Clearance**: Maps from IdP's `security_clearance` claim to user's `clearance` attribute
3. **Security Caveats**: Maps from IdP's `security_caveats` claim to user's `caveats` attribute
4. **Conflicts of Interest**: Maps from IdP's `conflicts_of_interest` claim to user's `coi` attribute

This ensures consistent user profiles regardless of the originating IdP.

## Customization

To add or modify country IdPs:

1. Create a new IdP configuration JSON file in `keycloak/identity-providers/`
2. Update the `COUNTRY_IDPS` array in `frontend/src/context/auth-context.tsx`
3. Update the `configure-country-idps.sh` script to include the new country

## Troubleshooting

If authentication issues occur:

1. Check Keycloak logs for IdP configuration issues
2. Verify that the IdP is properly configured on the country's side
3. Ensure attribute mapping is correctly set up for the new IdP
4. Check that redirect URIs are properly configured in both Keycloak and the country's IdP 