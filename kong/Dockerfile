FROM kong:3.4.2

# Switch to root for system operations
USER root

# Install necessary dependencies for custom plugins
RUN apt-get update && \
    apt-get install -y git unzip luarocks gettext-base

# Clean up existing OIDC plugin
RUN rm -rf /usr/local/share/lua/5.1/kong/plugins/oidc
RUN luarocks remove --force kong-oidc || true

# Install required Lua libraries
RUN luarocks install lua-resty-openidc
RUN luarocks install lua-resty-jwt

# Set up custom OIDC plugin directory
RUN mkdir -p /usr/local/share/lua/5.1/kong/plugins/oidc-auth
COPY custom_plugins/oidc-auth /usr/local/share/lua/5.1/kong/plugins/oidc-auth
COPY custom_plugins/oidc-auth/openidc.lua /usr/local/share/lua/5.1/resty/openidc.lua

# Create Kong configuration directories
RUN mkdir -p /etc/kong/kong.conf.d/

# Enable the necessary plugins
RUN echo "KONG_PLUGINS=bundled,ldap-auth,oidc-auth" > /etc/kong/kong.conf.d/custom_plugins.conf

# Setup SSL certificates directory
RUN mkdir -p /etc/kong/ssl/ /etc/kong/certs/
COPY ssl/ca-certificates.crt /etc/kong/ssl/ca-certificates.crt
# Ensure the certificates are available at the paths specified in kong.conf
COPY certs/dive25-cert.pem /etc/kong/certs/
COPY certs/dive25-key.pem /etc/kong/certs/

# Fix permissions for SSL certificates
RUN chmod 644 /etc/kong/ssl/ca-certificates.crt \
    && chmod 644 /etc/kong/certs/dive25-cert.pem \
    && chmod 644 /etc/kong/certs/dive25-key.pem \
    && chown -R kong:kong /etc/kong/ssl /etc/kong/certs

# Copy the original configuration file as a template
COPY kong.yml /etc/kong/kong.yml.template

# Copy the configuration processor script and make it executable
COPY process-config.sh /process-config.sh
RUN chmod +x /process-config.sh

# Copy other Kong configuration files
COPY kong.conf /etc/kong/kong.conf
COPY kong.ldap.yml /etc/kong/ldap/kong.ldap.yml
COPY configure-ldap.sh /etc/kong/ldap/configure-ldap.sh

# Make sure all necessary files are owned by kong user
RUN chown -R kong:kong /etc/kong

# Use the process-config.sh as entrypoint to handle environment variable substitution
ENTRYPOINT ["/process-config.sh"]

# Default command is to start Kong
CMD ["kong", "start"]

# Switch back to kong user for running the service
USER kong 