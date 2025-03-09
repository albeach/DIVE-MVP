# Fixing Infinite Redirection Loop in Kong OIDC Authentication

## Problem Description

The system was experiencing an infinite redirection loop when accessing any URL through the Kong gateway. This happened because:

1. User attempts to access `https://dive25.local:8443`
2. Kong redirects to Keycloak for authentication at `https://keycloak.dive25.local:8443/realms/dive25/protocol/openid-connect/auth`
3. This request also goes through Kong, which again triggers the OIDC plugin
4. The OIDC plugin redirects back to Keycloak for authentication
5. This creates an infinite loop of redirections

The root cause was that the **OIDC plugin was applied globally to all routes** in Kong, including the Keycloak routes themselves. This caused authentication requests to Keycloak to trigger another authentication request, resulting in an infinite loop.

## Solution

The solution is to apply the OIDC plugin only to the frontend routes, not globally to all routes:

1. Remove any global OIDC plugin configuration
2. Create route-specific OIDC plugins for:
   - `frontend-route` - The main frontend route
   - `frontend-root-domain` - The root domain route (dive25.local)
   - `frontend-subdomain-8443` - The subdomain with SSL port (frontend.dive25.local:8443)

This ensures that:
- The frontend routes are properly protected with OIDC authentication
- Keycloak routes remain accessible for the authentication process
- API routes can use their own authentication methods

## Implementation Details

The fix was implemented by modifying the `configure-oidc.sh` script to:

1. Retrieve the IDs of frontend routes from Kong
2. Create separate OIDC plugin instances for each frontend route
3. Use the same configuration for each plugin instance

Code snippet from the updated script:

```bash
# Get IDs for frontend routes to scope the OIDC plugin correctly
FRONTEND_ROUTE_ID=$(curl -s $KONG_ADMIN_URL/services/frontend-service/routes/frontend-route | jq -r '.id')
FRONTEND_ROOT_ROUTE_ID=$(curl -s $KONG_ADMIN_URL/routes | jq -r '.data[] | select(.name=="frontend-root-domain") | .id')
FRONTEND_SUBDOMAIN_ROUTE_ID=$(curl -s $KONG_ADMIN_URL/routes | jq -r '.data[] | select(.name=="frontend-subdomain-8443") | .id')

# Create OIDC plugins for each frontend route instead of globally
if [ -n "$FRONTEND_ROUTE_ID" ]; then
  curl -s -X POST $KONG_ADMIN_URL/routes/$FRONTEND_ROUTE_ID/plugins \
    -d "name=oidc-auth" \
    -d "config.client_id=${KEYCLOAK_CLIENT_ID_FRONTEND}" \
    # ... other configuration parameters ...
fi

# Repeat for other frontend routes
```

## Testing the Fix

To verify the fix:

1. Access `https://dive25.local:8443` or `https://frontend.dive25.local:8443`
2. You should be redirected to Keycloak for authentication
3. Keycloak should display the login page without causing another redirect
4. After logging in, you should be redirected back to the frontend application

## Common Mistakes to Avoid

- **Don't apply the OIDC plugin globally** to all routes; always scope it to specific routes
- Ensure the Keycloak client configuration has the correct redirect URIs
- Make sure internal service-to-service communication uses HTTP to avoid SSL issues
- Verify that the frontend application's callback URL matches what's configured in Kong and Keycloak 

## Additional Authentication Issues

### State Parameter Mismatch

After fixing the redirection loop, you might encounter the following error:

```
Authentication failed: state from argument: [some-hash] does not match state restored from session: nil
```

This indicates a session handling issue in the OIDC flow:

1. **Root Cause**: When the authentication request is initiated, Kong generates a state parameter but fails to properly store it in the session. When Keycloak redirects back with the state parameter, Kong can't validate it because the original state is missing from the session.

2. **Solution**: 

   The key is to ensure proper session handling across domains with these critical settings:

   * **Consistent Session Secret**: Generate and use the same session secret for all OIDC plugin instances
   * **Proper Cookie Domain**: Use a domain that works for all your subdomains
   * **Cross-domain Cookies**: Set SameSite=None for cross-domain redirects
   * **Cookie Security**: Ensure cookies are secure and HTTP-only

3. **Implementation**: Add these parameters to each OIDC plugin configuration:

   ```bash
   # Generate a consistent session secret to be used across all plugins
   SESSION_SECRET=$(openssl rand -base64 32)
   
   # For each plugin configuration
   -d "config.session_storage=cookie" \
   -d "config.session_secret=${SESSION_SECRET}" \ # Use the same secret for all plugins
   -d "config.session_lifetime=3600" \
   -d "config.session_cookie_name=oidc_session" \
   -d "config.cookie_domain=dive25.local" \ # Use the root domain without a leading dot
   -d "config.cookie_path=/" \
   -d "config.cookie_secure=true" \
   -d "config.cookie_httponly=true" \
   -d "config.cookie_samesite=None" \ # Critical for cross-domain redirects
   -d "config.session_rolling_expiration=true"
   ```

4. **Browser Requirements**:
   * Since we're using SameSite=None, the browser must support this setting
   * Modern browsers require that cookies with SameSite=None also have the Secure flag
   * You may need to clear your browser cookies before testing again

This enhanced configuration ensures proper session state management throughout the authentication flow, especially when dealing with redirects between different domains or subdomains. 