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

# Copy import files for initial setup
COPY ./realm-export.json /opt/keycloak/data/import/
# Set environment variable to import realm on startup
ENV KC_FEATURES=admin-api,impersonation,import-realm

ENTRYPOINT ["/opt/keycloak/bin/kc.sh"]
CMD ["start-dev", "--import-realm"]