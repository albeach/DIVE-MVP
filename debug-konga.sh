#!/bin/bash
# Small script to debug the konga repair function

# Source common functions
source ./scripts/setup-and-test-fixed.sh

# Run the function
repair_konga_config

# Done
echo "Debug complete" 