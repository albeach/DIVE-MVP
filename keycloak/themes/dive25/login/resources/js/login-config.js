// DIVE25 Keycloak Redirect Fix
// This script intercepts and modifies the well-known configuration
// and other redirects to ensure URLs use correct ports and domains

(function () {
    console.log("DIVE25: Initializing login-config.js to fix redirect URLs");

    // Store the original XMLHttpRequest.open method
    const originalOpen = XMLHttpRequest.prototype.open;

    // Override the open method to intercept well-known configuration responses
    XMLHttpRequest.prototype.open = function (method, url, async, user, password) {
        // Call the original method
        originalOpen.apply(this, arguments);

        // If this is a request for the well-known configuration
        if (url.includes('.well-known/openid-configuration')) {
            // Add a response handler
            this.addEventListener('load', function () {
                if (this.responseText) {
                    try {
                        // Parse the JSON response
                        const config = JSON.parse(this.responseText);

                        // Check if we need to modify any URLs
                        let modified = false;

                        // Function to fix URLs in the config
                        const fixUrl = (key) => {
                            if (!config[key]) return;

                            // Fix any non-8443 ports
                            if (config[key].includes(':4432/')) {
                                console.log(`DIVE25: Fixing ${key} URL from 4432 to 8443: ${config[key]}`);
                                config[key] = config[key].replace(':4432/', ':8443/');
                                modified = true;
                            }

                            if (config[key].includes(':8080/')) {
                                console.log(`DIVE25: Fixing ${key} URL from 8080 to 8443: ${config[key]}`);
                                config[key] = config[key].replace(':8080/', ':8443/');
                                modified = true;
                            }

                            // Ensure HTTPS for external URLs
                            if (config[key].startsWith('http://') &&
                                !config[key].includes('localhost') &&
                                !config[key].includes('127.0.0.1')) {
                                console.log(`DIVE25: Changing ${key} URL from HTTP to HTTPS: ${config[key]}`);
                                config[key] = config[key].replace('http://', 'https://');
                                modified = true;
                            }
                        };

                        // Fix all relevant URLs
                        const keysToFix = [
                            'issuer',
                            'authorization_endpoint',
                            'token_endpoint',
                            'introspection_endpoint',
                            'userinfo_endpoint',
                            'end_session_endpoint',
                            'jwks_uri',
                            'check_session_iframe',
                            'registration_endpoint',
                            'revocation_endpoint',
                            'device_authorization_endpoint',
                            'backchannel_authentication_endpoint'
                        ];

                        // Apply fixes to all keys
                        keysToFix.forEach(fixUrl);

                        // Fix nested URLs in mtls_endpoint_aliases if present
                        if (config.mtls_endpoint_aliases) {
                            Object.keys(config.mtls_endpoint_aliases).forEach(key => {
                                const mtlsUrl = config.mtls_endpoint_aliases[key];
                                if (mtlsUrl) {
                                    // Only fix internal URLs to ensure proper service-to-service communication
                                    if (mtlsUrl.includes(':4432/')) {
                                        console.log(`DIVE25: Fixing mtls_endpoint_aliases.${key} URL: ${mtlsUrl}`);
                                        config.mtls_endpoint_aliases[key] = mtlsUrl.replace(':4432/', ':8443/');
                                        modified = true;
                                    }
                                }
                            });
                        }

                        // If we modified any URLs, override the response
                        if (modified) {
                            console.log("DIVE25: Modified well-known configuration to use correct ports and protocols");
                            Object.defineProperty(this, 'responseText', {
                                get: function () {
                                    return JSON.stringify(config);
                                }
                            });
                        }
                    } catch (e) {
                        console.error("DIVE25: Error processing well-known configuration:", e);
                    }
                }
            });
        }
    };

    // Fix redirect after login
    // This intercepts the form submission from Keycloak login page
    document.addEventListener('DOMContentLoaded', function () {
        console.log("DIVE25: Setting up login form interception");

        // Find the login form and intercept submission if needed
        const loginForm = document.getElementById('kc-form-login');
        if (loginForm) {
            loginForm.addEventListener('submit', function (e) {
                console.log("DIVE25: Login form submitted");

                // Get the redirect_uri parameter from the URL
                const urlParams = new URLSearchParams(window.location.search);
                const redirectUri = urlParams.get('redirect_uri');

                if (redirectUri) {
                    console.log("DIVE25: Found redirect_uri:", redirectUri);

                    // Check if redirect_uri needs fixing
                    if (redirectUri.includes(':3000/') || redirectUri.includes(':3001/') || redirectUri.includes(':3002/')) {
                        console.log("DIVE25: Fixing frontend port in redirect_uri");

                        // Create a fixed redirect_uri using port 8443
                        const fixedRedirectUri = redirectUri.replace(/:(300[0-2])\//, ':8443/');

                        // Update the redirect_uri parameter in the form
                        let found = false;
                        for (let i = 0; i < loginForm.elements.length; i++) {
                            if (loginForm.elements[i].name === 'redirect_uri') {
                                loginForm.elements[i].value = fixedRedirectUri;
                                found = true;
                                console.log("DIVE25: Updated redirect_uri form field to:", fixedRedirectUri);
                                break;
                            }
                        }

                        // If no field exists, create one
                        if (!found) {
                            const input = document.createElement('input');
                            input.type = 'hidden';
                            input.name = 'redirect_uri';
                            input.value = fixedRedirectUri;
                            loginForm.appendChild(input);
                            console.log("DIVE25: Added redirect_uri form field:", fixedRedirectUri);
                        }
                    }
                }
            });
        }
    });

    console.log("DIVE25: Redirect fix initialization complete");
})(); 