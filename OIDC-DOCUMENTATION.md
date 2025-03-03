# OpenID Connect (OIDC) Authentication Documentation

## Overview

This document explains the OpenID Connect (OIDC) authentication implementation in the DIVE25 platform, focusing on the integration between Kong API Gateway and Keycloak Identity Provider. It also documents the fix implemented for the `session:start()` issue with the `lua-resty-openidc` library.

## Architecture

The OIDC authentication flow in DIVE25 involves the following components:

1. **Kong API Gateway**: Acts as an OpenID Connect Relying Party (RP)
2. **Keycloak**: Acts as the OpenID Connect Provider (OP)
3. **Custom OIDC Plugin**: Handles the authentication flow in Kong

## Authentication Flow

The OpenID Connect authentication flow implemented is the Authorization Code Flow:

1. User attempts to access a protected resource (e.g., `http://frontend.dive25.local`)
2. Kong intercepts the request and checks for an authenticated session
3. If no session exists, Kong redirects the user to Keycloak's authorization endpoint
4. User authenticates with Keycloak (username/password)
5. Keycloak redirects back to Kong with an authorization code
6. Kong exchanges the code for ID and access tokens at Keycloak's token endpoint
7. Kong creates a session and stores the tokens
8. Kong sets user information headers and proxies the request to the backend service

## Implementation Details

### Kong OIDC Plugin

The custom OIDC plugin (`oidc-auth`) is configured in Kong to:

1. Intercept requests to protected services
2. Handle the OIDC authentication flow
3. Validate tokens
4. Set user information headers for backend services

### Session Management Fix

We encountered an issue with the `lua-resty-openidc` library, specifically around the `session:start()` method which has been deprecated in newer versions of the `resty.session` library.

#### Problem

The original code used:

```lua
local session = require("resty.session").open(session_opts)
session:start()
```

However, in newer versions of the `resty.session` library, the `start()` method has been removed, causing errors.

#### Solution

We patched the `openidc.lua` file to:

1. Check if the session object has a `start` method
2. If not, handle session initialization using the newer API
3. Ensure proper discovery document loading by adding checks for both `discovery` and `discovery_document_url` parameters

The key changes include:

```lua
-- Check for discovery URL in either discovery or discovery_document_url
local discovery_url = opts.discovery_document_url or opts.discovery
if not discovery_url then
  return nil, "no discovery URL provided in options"
end

-- Handle session properly for newer resty.session versions
local function ensure_session_started(session)
  if session.start then
    session:start()
  end
  return session
end
```

## Testing the Authentication

To test the OIDC authentication:

1. Update your hosts file to map `frontend.dive25.local` to `127.0.0.1` (use the provided `setup-hosts.sh` script)
2. Ensure all services are running with `docker-compose up -d`
3. Access `http://frontend.dive25.local` in your browser
4. You should be redirected to the Keycloak login page
5. After successful authentication, you'll be redirected back to the application

## Troubleshooting

If you encounter issues:

1. Check Kong logs: `docker logs dive25-kong`
2. Ensure Keycloak is accessible: `curl -k http://keycloak:8080/auth/realms/dive25/.well-known/openid-configuration`
3. Verify the OIDC plugin configuration in Kong: `curl http://localhost:8001/services/frontend-service/plugins`

## Keycloak Configuration

The Keycloak realm `dive25` is configured with:

1. Client ID: `dive25-frontend`
2. Client Secret: (check environment variables or configuration)
3. Valid Redirect URIs: `http://kong:8000/callback`
4. Web Origins: `+`

## References

1. [OpenID Connect Core Specification](https://openid.net/specs/openid-connect-core-1_0.html)
2. [lua-resty-openidc Documentation](https://github.com/zmartzone/lua-resty-openidc)
3. [Kong OIDC Plugin Documentation](https://docs.konghq.com/hub/kong-inc/openid-connect/)
4. [Keycloak Documentation](https://www.keycloak.org/documentation) 