#!/bin/bash
# opa/test_policy.sh

# This script tests the OPA policies with various inputs

OPA_URL="http://localhost:8181/v1/data"
POLICY_PATH="dive25/document_access/allow"

echo "Testing OPA policies..."

# Function to test policy with a specific input
test_policy() {
    local description="$1"
    local input_file="$2"
    local expected_result="$3"
    
    echo "Test: $description"
    
    # Execute the policy query
    result=$(curl -s -X POST "$OPA_URL/$POLICY_PATH" \
      -H 'Content-Type: application/json' \
      -d @"$input_file" | jq -r '.result')
    
    # Compare result with expected
    if [ "$result" == "$expected_result" ]; then
        echo "✅ PASS"
    else
        echo "❌ FAIL: Expected $expected_result, got $result"
    fi
    echo ""
}

# Run test cases
test_policy "Basic FVEY access" "tests/basic_fvey_access.json" "true"
test_policy "Insufficient clearance" "tests/insufficient_clearance.json" "false"
test_policy "Missing caveats" "tests/missing_caveats.json" "false"
test_policy "Missing COI" "tests/missing_coi.json" "false"
test_policy "Releasability mismatch" "tests/releasability_mismatch.json" "false"
test_policy "NATO access" "tests/nato_access.json" "true"
test_policy "EU access" "tests/eu_access.json" "true"

echo "All tests completed!"