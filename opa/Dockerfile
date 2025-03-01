# opa/Dockerfile
FROM openpolicyagent/opa:latest

# Copy policies
COPY ./policies /opt/opa/policies

# Copy config
COPY ./config.yaml /opt/opa/config.yaml

# Set entrypoint
ENTRYPOINT ["/opa", "run", "--server", "--config-file=/opt/opa/config.yaml", "--log-level=debug", "/opt/opa/policies"]
