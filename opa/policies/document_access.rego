# opa/policies/document_access.rego
package dive25.document_access

import data.dive25.partner_policies
import data.access_policy

# Default deny
default allow = false

# Default empty explanation
default explanation = "Access denied due to insufficient permissions"

# Allow access if user has appropriate clearance, caveats, and releasability
allow if {
    # Check if user has sufficient clearance level
    access_policy.clearance[input.user.clearance] >= access_policy.clearance[input.resource.classification]
    
    # Check if user has all required caveats
    has_all_required_caveats
    
    # Check releasability constraints
    meets_releasability_requirements
    
    # Check for organization/COI matches if needed
    meets_coi_requirements
}

# Allow for admin users regardless of classification
allow if {
    is_in_array(input.user.roles, "admin")
}

# Allow for document creators (owners)
allow if {
    input.resource.createdBy == input.user.uniqueId
}

# Check if user has all required caveats
has_all_required_caveats if {
    # If resource has no caveats, this check passes
    count(input.resource.caveats) == 0
}

has_all_required_caveats if {
    # All resource caveats must be in user's caveats
    count(input.resource.caveats) > 0
    missing_caveats := [c | c := input.resource.caveats[_]; not is_in_array(input.user.caveats, c)]
    count(missing_caveats) == 0
}

# Check if document is releasable to user's country
meets_releasability_requirements if {
    # If no releasability constraints, document is releasable to all
    count(input.resource.releasableTo) == 0
}

meets_releasability_requirements if {
    # Document must be releasable to user's country
    is_in_array(input.resource.releasableTo, input.user.countryOfAffiliation)
}

meets_releasability_requirements if {
    # Special handling for group releasability (NATO, FVEY, EU)
    is_in_array(input.resource.releasableTo, "NATO")
    access_policy.nato_nations[input.user.countryOfAffiliation]
}

meets_releasability_requirements if {
    is_in_array(input.resource.releasableTo, "FVEY")
    access_policy.fvey_nations[input.user.countryOfAffiliation]
}

meets_releasability_requirements if {
    is_in_array(input.resource.releasableTo, "EU")
    access_policy.eu_nations[input.user.countryOfAffiliation]
}

# Check COI requirements
meets_coi_requirements if {
    # If resource has no COI tags, this check passes
    count(input.resource.coiTags) == 0
}

meets_coi_requirements if {
    # User must have at least one matching COI
    count(input.resource.coiTags) > 0
    common_cois := [c | c := input.resource.coiTags[_]; is_in_array(input.user.coi, c)]
    count(common_cois) > 0
}

# Return detailed explanations based on denial reasons
explanation = msg if {
    not allow
    user_clearance := access_policy.clearance[input.user.clearance]
    resource_clearance := access_policy.clearance[input.resource.classification]
    user_clearance < resource_clearance
    
    msg := sprintf("Access denied: Your clearance level (%s) is insufficient for this document (%s)", [input.user.clearance, input.resource.classification])
}

explanation = msg if {
    not allow
    user_clearance := access_policy.clearance[input.user.clearance]
    resource_clearance := access_policy.clearance[input.resource.classification]
    user_clearance >= resource_clearance
    
    count(input.resource.caveats) > 0
    missing_caveats := [c | c := input.resource.caveats[_]; not is_in_array(input.user.caveats, c)]
    count(missing_caveats) > 0
    
    msg := sprintf("Access denied: You are missing required caveats: %v", [missing_caveats])
}

explanation = msg if {
    not allow
    user_clearance := access_policy.clearance[input.user.clearance]
    resource_clearance := access_policy.clearance[input.resource.classification]
    user_clearance >= resource_clearance
    
    count(input.resource.caveats) > 0
    missing_caveats := [c | c := input.resource.caveats[_]; not is_in_array(input.user.caveats, c)]
    count(missing_caveats) == 0
    
    not meets_releasability_requirements
    
    msg := sprintf("Access denied: Document is not releasable to %s", [input.user.countryOfAffiliation])
}

explanation = msg if {
    not allow
    user_clearance := access_policy.clearance[input.user.clearance]
    resource_clearance := access_policy.clearance[input.resource.classification]
    user_clearance >= resource_clearance
    
    has_all_required_caveats
    meets_releasability_requirements
    not meets_coi_requirements
    
    msg := sprintf("Access denied: You are not a member of any Communities of Interest (COI) required to access this document: %v", [input.resource.coiTags])
}

explanation = "Access granted" if {
    allow
}

# Helper function to check if a value exists in an array
is_in_array(arr, val) if {
    some i
    arr[i] == val
}