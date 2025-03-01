#!/bin/bash
# This script creates the directory structure and blank files for the dive25-api project

# Create base directory
mkdir -p dive25-api
cd dive25-api || exit

# Create root files
touch Dockerfile docker-compose.yml package.json

# Create directories
mkdir -p kubernetes
mkdir -p src/config
mkdir -p src/controllers
mkdir -p src/services
mkdir -p src/models
mkdir -p src/middleware
mkdir -p src/utils
mkdir -p src/routes
mkdir -p tests
mkdir -p opa-policies

# Create blank files in kubernetes folder
touch kubernetes/api-deployment.yaml
touch kubernetes/api-service.yaml
touch kubernetes/api-ingress.yaml
touch kubernetes/configmap.yaml
touch kubernetes/secrets.yaml
touch kubernetes/namespace.yaml

# Create blank files in src/config
touch src/config/index.js
touch src/config/keycloak.config.js
touch src/config/mongodb.config.js
touch src/config/opa.config.js
touch src/config/ldap.config.js

# Create blank file for app.js
touch src/app.js

# Create blank files in src/controllers
touch src/controllers/auth.controller.js
touch src/controllers/documents.controller.js
touch src/controllers/users.controller.js
touch src/controllers/audit.controller.js

# Create blank files in src/services
touch src/services/auth.service.js
touch src/services/documents.service.js
touch src/services/users.service.js
touch src/services/opa.service.js
touch src/services/ldap.service.js
touch src/services/audit.service.js

# Create blank files in src/models
touch src/models/document.model.js
touch src/models/user.model.js
touch src/models/audit.model.js

# Create blank files in src/middleware
touch src/middleware/auth.middleware.js
touch src/middleware/error.middleware.js
touch src/middleware/logging.middleware.js

# Create blank files in src/utils
touch src/utils/error.utils.js
touch src/utils/jwt.utils.js
touch src/utils/validation.utils.js
touch src/utils/logger.js
touch src/utils/metrics.js

# Create blank files in src/routes
touch src/routes/index.js
touch src/routes/auth.routes.js
touch src/routes/documents.routes.js
touch src/routes/users.routes.js
touch src/routes/audit.routes.js

# Create blank files in opa-policies
touch opa-policies/partner_policies.rego
touch opa-policies/access_policy.rego

echo "Project structure created successfully."
