# opa/Dockerfile
FROM --platform=linux/arm64 openpolicyagent/opa:latest

# Copy policies
COPY ./policies /opt/opa/policies

# Copy config
COPY ./config.yaml /opt/opa/config.yaml

# Set entrypoint - adding the --watch flag to automatically reload policies
ENTRYPOINT ["/opa", "run", "--server", "--addr=0.0.0.0:8181", "--log-level=debug", "--watch", "/opt/opa/policies"]
