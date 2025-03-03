#!/bin/bash

# Script to set up hosts file entries for DIVE25 local development

# Check if running as root/sudo
if [ "$(id -u)" -ne 0 ]; then
   echo "This script must be run as root or with sudo" 
   exit 1
fi

echo "Setting up hosts file entries for DIVE25..."

# Define the hosts to add
HOSTS=(
    "frontend.dive25.local"
    "api.dive25.local"
    "keycloak.dive25.local"
    "admin.dive25.local"
    "grafana.dive25.local"
    "prometheus.dive25.local"
)

# Check if entries already exist
HOSTS_FILE="/etc/hosts"
HOSTS_BACKUP="${HOSTS_FILE}.bak.$(date +%Y%m%d%H%M%S)"

# Make a backup of the hosts file
cp $HOSTS_FILE $HOSTS_BACKUP
echo "Created backup of hosts file at $HOSTS_BACKUP"

# Add entries if they don't exist
for HOST in "${HOSTS[@]}"; do
    if grep -q "^127.0.0.1 $HOST" $HOSTS_FILE; then
        echo "Host entry for $HOST already exists"
    else
        echo "Adding host entry for $HOST"
        echo "127.0.0.1 $HOST" >> $HOSTS_FILE
    fi
done

echo "Host entries setup complete."
echo ""
echo "You can now access the following URLs:"
echo "- Frontend: http://frontend.dive25.local"
echo "- API: http://api.dive25.local"
echo "- Keycloak: http://keycloak.dive25.local:8080/auth"
echo "- Admin: http://admin.dive25.local:8001"
echo "- Grafana: http://grafana.dive25.local:3100"
echo "- Prometheus: http://prometheus.dive25.local:9090"
echo ""
echo "To test the OIDC authentication, navigate to http://frontend.dive25.local in your browser." 