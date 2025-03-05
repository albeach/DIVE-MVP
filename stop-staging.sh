#!/bin/bash

echo "Stopping the staging environment..."
docker-compose -f docker-compose.staging.yml down

echo "Do you want to remove all volumes? This will delete all data. (y/n)"
read -r response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
  echo "Removing all volumes..."
  docker-compose -f docker-compose.staging.yml down -v
  echo "All volumes have been removed."
else
  echo "Volumes have been preserved."
fi

echo "Staging environment has been stopped." 