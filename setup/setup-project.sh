#!/bin/bash
# This script creates the project directory structure and blank files

# Top-level project directory (change as needed)
PROJECT_DIR="DIVE25"
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR" || exit 1

#############################
# API - Node.js Backend API #
#############################
mkdir -p api/kubernetes
mkdir -p api/src/config
mkdir -p api/src/controllers
mkdir -p api/src/services
mkdir -p api/src/models
mkdir -p api/src/middleware
mkdir -p api/src/utils
mkdir -p api/src/routes

touch api/Dockerfile
touch api/docker-compose.yml
touch api/package.json
touch api/src/app.js

#############################
# Frontend - Next.js/Tailwind#
#############################
mkdir -p frontend/src/app
mkdir -p frontend/src/components
mkdir -p frontend/src/context
mkdir -p frontend/src/hooks
mkdir -p frontend/src/lib
mkdir -p frontend/src/services
mkdir -p frontend/src/styles

touch frontend/Dockerfile
touch frontend/package.json
touch frontend/next.config.js
touch frontend/postcss.config.js
touch frontend/tailwind.config.js

###########################
# Keycloak Configuration  #
###########################
mkdir -p keycloak/identity-providers
mkdir -p keycloak/test-users
mkdir -p keycloak/themes

touch keycloak/Dockerfile
touch keycloak/configure-keycloak.js
touch keycloak/realm-export.json

###########################
# OpenLDAP Configuration  #
###########################
mkdir -p openldap/bootstrap
mkdir -p openldap/certs

touch openldap/docker-compose.yml
touch openldap/generate-passwords.sh
touch openldap/setup.sh

###############################
# OPA - Open Policy Agent     #
###############################
mkdir -p opa/policies/dive25

touch opa/Dockerfile
touch opa/config.yaml
touch opa/docker-compose.yml
touch opa/policies/dive25/partner_policies.rego
touch opa/policies/access_policy.rego

###############################
# Kong - API Gateway          #
###############################
mkdir -p kong/config

touch kong/docker-compose.yml
touch kong/setup.js

###############################
# MongoDB Configuration       #
###############################
mkdir -p mongodb/scripts

touch mongodb/docker-compose.yml
touch mongodb/init-mongo.js

###############################
# Prometheus Monitoring       #
###############################
touch prometheus/docker-compose.yml
touch prometheus/prometheus.yml

###############################
# Grafana Dashboards          #
###############################
mkdir -p grafana/datasources
mkdir -p grafana/dashboards
mkdir -p grafana/provisioning

touch grafana/docker-compose.yml

##################################
# Root-level Docker Compose File #
##################################
touch docker-compose.yml

##################################
# Kubernetes Deployment Manifests#
##################################
mkdir -p kubernetes/configmaps
mkdir -p kubernetes/secrets
mkdir -p kubernetes/deployments
mkdir -p kubernetes/services
mkdir -p kubernetes/ingress

touch kubernetes/namespace.yaml

#####################
# Documentation     #
#####################
mkdir -p docs/architecture
mkdir -p docs/deployment
mkdir -p docs/development
mkdir -p docs/user

#####################
# Utility Scripts   #
#####################
mkdir -p scripts
touch scripts/setup.sh
touch scripts/deploy.sh
touch scripts/test.sh

echo "Project structure created in '$PROJECT_DIR'"
