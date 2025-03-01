#!/bin/bash
# mongodb/setup.sh

set -e

echo "Setting up MongoDB for DIVE25..."

# Create directories if they don't exist
mkdir -p data/key
mkdir -p logs

# Generate keyfile for replica set authentication (if needed)
if [ ! -f data/key/mongo-keyfile ]; then
  echo "Generating MongoDB keyfile..."
  openssl rand -base64 756 > data/key/mongo-keyfile
  chmod 400 data/key/mongo-keyfile
fi

# Set environment variables
export MONGO_ROOT_USERNAME=${MONGO_ROOT_USERNAME:-admin}
export MONGO_ROOT_PASSWORD=${MONGO_ROOT_PASSWORD:-admin_password}
export MONGO_EXPRESS_USERNAME=${MONGO_EXPRESS_USERNAME:-admin}
export MONGO_EXPRESS_PASSWORD=${MONGO_EXPRESS_PASSWORD:-admin_password}

# Start Docker Compose
echo "Starting MongoDB services..."
docker-compose up -d

echo "Waiting for MongoDB to start..."
sleep 10

# Check if MongoDB is running
if docker-compose exec mongo mongosh --eval "db.adminCommand('ping')" > /dev/null; then
  echo "MongoDB is running!"
else
  echo "Error: MongoDB is not running properly."
  exit 1
fi

echo "MongoDB setup completed successfully!"
echo "You can access MongoDB Express at: http://localhost:8081"
echo "Username: $MONGO_EXPRESS_USERNAME"
echo "Password: $MONGO_EXPRESS_PASSWORD"