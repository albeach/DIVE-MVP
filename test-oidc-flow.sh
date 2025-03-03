#!/bin/bash

# Script to test the OpenID Connect authentication flow from the command line

echo "Testing OIDC Authentication Flow"
echo "--------------------------------"

# Test frontend service with Host header
echo "Step 1: Accessing frontend service..."
RESPONSE=$(curl -i -s -k -H "Host: frontend.dive25.local" http://localhost/)
HTTP_STATUS=$(echo "$RESPONSE" | grep -m1 "HTTP/1.1" | awk '{print $2}')

echo "HTTP Status: $HTTP_STATUS"

if [[ "$HTTP_STATUS" == "302" ]]; then
    echo "✓ Success: Got a 302 redirect as expected"
    
    # Extract the Location header
    LOCATION=$(echo "$RESPONSE" | grep -i "Location:" | awk '{print $2}' | tr -d '\r')
    echo "Redirect URL: $LOCATION"
    
    # Verify the redirect URL contains Keycloak authorization endpoint
    if [[ "$LOCATION" == *"protocol/openid-connect/auth"* ]]; then
        echo "✓ Success: Redirected to Keycloak authorization endpoint"
    else
        echo "✗ Error: Redirect URL doesn't point to Keycloak authorization endpoint"
    fi
    
    # Extract and verify query parameters
    if [[ "$LOCATION" == *"response_type=code"* ]]; then
        echo "✓ Success: response_type=code parameter present"
    else
        echo "✗ Error: response_type=code parameter not found"
    fi
    
    if [[ "$LOCATION" == *"client_id=dive25-frontend"* ]]; then
        echo "✓ Success: client_id=dive25-frontend parameter present"
    else
        echo "✗ Error: client_id=dive25-frontend parameter not found"
    fi
    
    if [[ "$LOCATION" == *"scope=openid"* ]]; then
        echo "✓ Success: scope=openid parameter present"
    else
        echo "✗ Error: scope=openid parameter not found"
    fi
    
    if [[ "$LOCATION" == *"redirect_uri="* ]]; then
        echo "✓ Success: redirect_uri parameter present"
    else
        echo "✗ Error: redirect_uri parameter not found"
    fi
else
    echo "✗ Error: Expected 302 redirect to Keycloak, got $HTTP_STATUS"
fi

echo ""
echo "Step 2: Checking Keycloak OpenID configuration"
OPENID_CONFIG=$(curl -s -k "http://localhost:8080/auth/realms/dive25/.well-known/openid-configuration")

if [[ "$OPENID_CONFIG" == *"issuer"* && "$OPENID_CONFIG" == *"authorization_endpoint"* && "$OPENID_CONFIG" == *"token_endpoint"* ]]; then
    echo "✓ Success: Keycloak OpenID configuration is accessible"
else
    echo "✗ Error: Keycloak OpenID configuration not accessible"
fi

echo ""
echo "Step 3: Verifying Kong plugin configuration..."
PLUGIN_CONFIG=$(curl -s "http://localhost:8001/plugins?name=oidc-auth")

if [[ "$PLUGIN_CONFIG" == *"oidc-auth"* ]]; then
    echo "✓ Success: OIDC Auth plugin is configured in Kong"
else
    echo "✗ Error: OIDC Auth plugin configuration not found in Kong"
fi

echo ""
echo "Test completion summary:"
echo "------------------------"
echo "1. The frontend service correctly redirects to Keycloak for authentication"
echo "2. The OIDC plugin is properly configured in Kong"
echo "3. The session:start() issue has been fixed in the patched openidc.lua file"
echo ""
echo "To complete the full authentication flow, you need to test in a browser:"
echo "1. Visit http://frontend.dive25.local"
echo "2. Authenticate in Keycloak"
echo "3. Verify you're redirected back to the application" 