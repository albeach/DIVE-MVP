# keycloak/Dockerfile
FROM quay.io/keycloak/keycloak:21.0 as builder

ENV KC_DB=postgres

# Install custom providers if needed
# RUN curl -sL https://github.com/some-provider/provider.jar -o /opt/keycloak/providers/provider.jar

# Configure Keycloak
RUN /opt/keycloak/bin/kc.sh build

FROM quay.io/keycloak/keycloak:21.0
COPY --from=builder /opt/keycloak/ /opt/keycloak/

# Copy themes
COPY ./themes/dive25 /opt/keycloak/themes/dive25

# Ensure the theme's JavaScript directory exists
RUN mkdir -p /opt/keycloak/themes/dive25/login/resources/js

# Copy fix scripts into the theme
COPY ./themes/dive25/login/resources/js/login-config.js /opt/keycloak/themes/dive25/login/resources/js/

# Copy unified configuration script
COPY ./configure-keycloak-unified.sh /opt/keycloak/
RUN chmod +x /opt/keycloak/configure-keycloak-unified.sh

# Update theme.properties to include our script
RUN if [ -f /opt/keycloak/themes/dive25/login/theme.properties ]; then \
    if ! grep -q "scripts=" /opt/keycloak/themes/dive25/login/theme.properties; then \
        echo "scripts=js/login-config.js" >> /opt/keycloak/themes/dive25/login/theme.properties; \
    elif ! grep -q "login-config.js" /opt/keycloak/themes/dive25/login/theme.properties; then \
        sed -i 's/scripts=/scripts=js\/login-config.js /g' /opt/keycloak/themes/dive25/login/theme.properties; \
    fi; \
else \
    mkdir -p /opt/keycloak/themes/dive25/login; \
    echo "parent=base" > /opt/keycloak/themes/dive25/login/theme.properties; \
    echo "scripts=js/login-config.js" >> /opt/keycloak/themes/dive25/login/theme.properties; \
fi

# Copy import files for initial setup
COPY ./realm-export.json /opt/keycloak/data/import/
# Set environment variable to import realm on startup
ENV KC_FEATURES=admin-api,impersonation,import-realm

ENTRYPOINT ["/opt/keycloak/bin/kc.sh"]
CMD ["start-dev", "--import-realm"]