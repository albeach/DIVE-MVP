#!/bin/bash

# Script to test Kong routing for wildcard domains with verbose output
echo "Testing Kong routing for *.dive25.local domains with verbose output..."

# Test domain
TEST_DOMAIN="test.dive25.local"

echo "Testing domain: $TEST_DOMAIN"
echo "HTTP Test:"
curl -v -H "Host: $TEST_DOMAIN" http://localhost:80

echo -e "\n\nHTTPS Test (with -k to ignore certificate validation):"
curl -v -k -H "Host: $TEST_DOMAIN" https://localhost:443

echo -e "\n\nChecking Kong logs for routing issues:"
echo "docker logs dive25-kong | grep -E 'no Route matched|debug.router' | tail -20" 