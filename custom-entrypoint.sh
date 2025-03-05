#!/bin/bash

echo "Using custom entrypoint with correct hostnames"
/app/wait-for-it.sh dive25-kong:8001 -t 120 -- /app/wait-for-it.sh dive25-keycloak:8080 -t 120 -- /app/configure-oidc.sh && touch /app/oidc-config-completed && tail -f /dev/null 