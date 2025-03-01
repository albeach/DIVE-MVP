# keycloak/Dockerfile
FROM quay.io/keycloak/keycloak:21.0 as builder

ENV KC_DB=postgres

# Install custom providers
# RUN curl -sL https://github.com/some-provider/provider.jar -o /opt/keycloak/providers/provider.jar

# Configure Keycloak
RUN /opt/keycloak/bin/kc.sh build

FROM quay.io/keycloak/keycloak:21.0
COPY --from=builder /opt/keycloak/ /opt/keycloak/

# Copy themes
COPY ./themes/dive25 /opt/keycloak/themes/dive25

# Add script for post-startup configuration
COPY ./configure-keycloak.js /opt/keycloak/bin/
COPY ./realm-export.json /opt/keycloak/bin/
COPY ./identity-providers /opt/keycloak/bin/identity-providers
COPY ./test-users /opt/keycloak/bin/test-users

# Install Node.js for configuration script
USER root
RUN microdnf update -y && microdnf install -y nodejs npm
RUN npm install axios
USER 1000

ENTRYPOINT ["/opt/keycloak/bin/kc.sh"]
CMD ["start-dev"]
