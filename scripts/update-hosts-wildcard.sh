#!/bin/bash

# Script to update hosts file with additional subdomains for DIVE25

# Check if running as root/sudo
if [ "$(id -u)" -ne 0 ]; then
   echo "This script must be run as root or with sudo" 
   exit 1
fi

echo "Updating hosts file with additional subdomains for DIVE25..."

# Define additional hosts to add
ADDITIONAL_HOSTS=(
    "test.dive25.local"
    "wildcard.dive25.local"
    "app.dive25.local"
    "docs.dive25.local"
    "auth.dive25.local"
    "metrics.dive25.local"
    "dashboard.dive25.local"
    "mongo-express.dive25.local"
    "phpldapadmin.dive25.local"
    "kong.dive25.local"
    "konga.dive25.local"
)

# Check if entries already exist
HOSTS_FILE="/etc/hosts"
HOSTS_BACKUP="${HOSTS_FILE}.bak.$(date +%Y%m%d%H%M%S)"

# Make a backup of the hosts file
cp $HOSTS_FILE $HOSTS_BACKUP
echo "Created backup of hosts file at $HOSTS_BACKUP"

# Add entries if they don't exist
for HOST in "${ADDITIONAL_HOSTS[@]}"; do
    if grep -q "^127.0.0.1 $HOST" $HOSTS_FILE; then
        echo "Host entry for $HOST already exists"
    else
        echo "Adding host entry for $HOST"
        echo "127.0.0.1 $HOST" >> $HOSTS_FILE
    fi
done

echo "Host entries update complete."
echo ""
echo "Added the following URLs:"
for HOST in "${ADDITIONAL_HOSTS[@]}"; do
    echo "- $HOST"
done
echo ""
echo "To test the Kong routing with these domains, run: ./scripts/test-kong-routing.sh" 