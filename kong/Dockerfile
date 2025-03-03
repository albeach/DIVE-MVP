FROM kong:3.4.2

# Install dependencies
USER root
RUN apt-get update && \
    apt-get install -y git unzip luarocks

# Clean up any existing OIDC plugin installations
RUN rm -rf /usr/local/share/lua/5.1/kong/plugins/oidc
# Uninstall any existing OIDC plugins from LuaRocks
RUN luarocks remove --force kong-oidc || true

# Install a Kong 3.x compatible OIDC plugin
RUN luarocks install lua-resty-openidc
RUN luarocks install lua-resty-jwt

# Create directories for Kong plugins and custom plugins
RUN mkdir -p /usr/local/share/lua/5.1/kong/plugins/oidc-auth

# Copy custom OIDC plugin files
COPY custom_plugins/oidc-auth /usr/local/share/lua/5.1/kong/plugins/oidc-auth

# Copy patched openidc.lua file to fix session:start() issue
COPY custom_plugins/oidc-auth/openidc.lua /usr/local/share/lua/5.1/resty/openidc.lua

# Enable the plugins
RUN echo "KONG_PLUGINS=bundled,ldap-auth,oidc-auth" > /etc/kong/kong.conf.d/custom_plugins.conf

# Copy custom configurations
COPY kong.yml /etc/kong/kong.yml
COPY kong.ldap.yml /etc/kong/ldap/kong.ldap.yml
COPY configure-ldap.sh /etc/kong/ldap/configure-ldap.sh

USER kong 