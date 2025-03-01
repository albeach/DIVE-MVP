// opa/policies/dive25/partner_policies.rego
package dive25.partner_policies

import data.access_policy.clearance
import data.access_policy.nato_nations
import data.access_policy.fvey_nations
import data.access_policy.eu_nations

# Default rule: deny access unless explicitly allowed
default allow = false
default error = "Access denied by default"

# Partner-specific policy definitions
# Contains allowed classifications, required caveats, and allowed COI tags per partner
partner_policies = {
    "FVEY": {
        "allowed_classifications": [
            "UNCLASSIFIED",
            "RESTRICTED",
            "CONFIDENTIAL",
            "SECRET",
            "TOP SECRET"
        ],
        "required_caveats": ["FVEY"],
        "allowed_coi_tags": ["OpAlpha", "OpBravo", "OpGamma", "MissionX", "MissionZ"]
    },
    "NATO": {
        "allowed_classifications": [
            "UNCLASSIFIED",
            "RESTRICTED",
            "NATO CONFIDENTIAL",
            "NATO SECRET",
            "COSMIC TOP SECRET"
        ],
        "required_caveats": ["NATO"],
        "allowed_coi_tags": ["OpAlpha", "OpBravo", "OpGamma", "MissionX", "MissionZ"]
    },
    "EU": {
        "allowed_classifications": [
            "UNCLASSIFIED",
            "RESTRICTED",
            "EU CONFIDENTIAL",
            "EU SECRET",
            "EU TOP SECRET"
        ],
        "required_caveats": ["EU"],
        "allowed_coi_tags": ["MissionX", "MissionZ"]
    }
}

# The main rule grants access if all partner-specific conditions are satisfied
allow = true {
    partner_type := get_partner_type(input.user.countryOfAffiliation)
    policy := partner_policies[partner_type]
    
    # Check that the resource's classification (after normalization)
    # is among the allowed classifications (also normalized)
    normalized_resource_classification := normalize_classification(input.resource.classification)
    normalized_resource_classification in [normalize_classification(c) | c := policy.allowed_classifications[_]]
    
    # Ensure the user's clearance is sufficient for the resource classification
    user_clearance_level := clearance[normalize_classification(input.user.clearance)]
    resource_clearance_level := clearance[normalized_resource_classification]
    user_clearance_level >= resource_clearance_level
    
    # Verify that any required caveats are present in the user's caveats
    all_required_caveats_present(policy.required_caveats, input.user.caveats)
    
    # Verify that all resource COI tags are allowed for this partner type
    # and the user has access to all required COI tags
    all_coi_tags_allowed(policy.allowed_coi_tags, input.resource.coiTags)
    all_coi_tags_present(input.resource.coiTags, input.user.coi)
    
    # Verify releasability matches user's country affiliation
    country_releasability_check(input.resource.releasableTo, input.user.countryOfAffiliation)
}

# Helper function: get_partner_type returns the partner type for a given country
get_partner_type(country) = "FVEY" {
    fvey_nations[country]
}

get_partner_type(country) = "NATO" {
    nato_nations[country]
}

get_partner_type(country) = "EU" {
    eu_nations[country]
}

# If country doesn't belong to any defined partner group, return default
get_partner_type(country) = "DEFAULT" {
    not fvey_nations[country]
    not nato_nations[country]
    not eu_nations[country]
}

# Verifies that all required caveats are present in the user's caveats
all_required_caveats_present(required_caveats, user_caveats) {
    count(required_caveats) == 0
}

all_required_caveats_present(required_caveats, user_caveats) {
    count(required_caveats) > 0
    every caveat in required_caveats {
        caveat in user_caveats
    }
}

# Verifies that all resource COI tags are allowed for the partner type
all_coi_tags_allowed(allowed_tags, resource_tags) {
    count(resource_tags) == 0
}

all_coi_tags_allowed(allowed_tags, resource_tags) {
    count(resource_tags) > 0
    every tag in resource_tags {
        tag in allowed_tags
    }
}

# Verifies that the user has access to all COI tags required by the resource
all_coi_tags_present(resource_tags, user_tags) {
    count(resource_tags) == 0
}

all_coi_tags_present(resource_tags, user_tags) {
    count(resource_tags) > 0
    every tag in resource_tags {
        tag in user_tags
    }
}

# Checks if the user's country is in the resource's releasability list
country_releasability_check(releasableTo, country) {
    count(releasableTo) == 0  # If no releasability constraints, allow access
}

country_releasability_check(releasableTo, country) {
    count(releasableTo) > 0
    releasableTo[_] == country  # Direct country match
}

country_releasability_check(releasableTo, country) {
    count(releasableTo) > 0
    "FVEY" in releasableTo
    fvey_nations[country]  # Country is part of FVEY
}

country_releasability_check(releasableTo, country) {
    count(releasableTo) > 0
    "NATO" in releasableTo
    nato_nations[country]  # Country is part of NATO
}

country_releasability_check(releasableTo, country) {
    count(releasableTo) > 0
    "EU" in releasableTo
    eu_nations[country]  # Country is part of EU
}

# normalize_classification maps partner-specific classifications to standard keys
normalize_classification(classification) = normalized {
    classification == "NATO CONFIDENTIAL"
    normalized := "CONFIDENTIAL"
}

normalize_classification(classification) = normalized {
    classification == "NATO SECRET"
    normalized := "SECRET"
}

normalize_classification(classification) = normalized {
    classification == "COSMIC TOP SECRET"
    normalized := "TOP SECRET"
}

normalize_classification(classification) = normalized {
    classification == "EU CONFIDENTIAL"
    normalized := "CONFIDENTIAL"
}

normalize_classification(classification) = normalized {
    classification == "EU SECRET"
    normalized := "SECRET"
}

normalize_classification(classification) = normalized {
    classification == "EU TOP SECRET"
    normalized := "TOP SECRET"
}

# If no normalization is needed, the classification remains unchanged
normalize_classification(classification) = classification {
    not classification == "NATO CONFIDENTIAL"
    not classification == "NATO SECRET"
    not classification == "COSMIC TOP SECRET"
    not classification == "EU CONFIDENTIAL"
    not classification == "EU SECRET"
    not classification == "EU TOP SECRET"
}

# Error message for classification mismatch
error = msg {
    partner_type := get_partner_type(input.user.countryOfAffiliation)
    policy := partner_policies[partner_type]
    
    normalized_resource_classification := normalize_classification(input.resource.classification)
    not normalized_resource_classification in [normalize_classification(c) | c := policy.allowed_classifications[_]]
    
    msg := sprintf("User from %s not authorized to access %s classification", [input.user.countryOfAffiliation, input.resource.classification])
}

# Error message for clearance level insufficiency
error = msg {
    partner_type := get_partner_type(input.user.countryOfAffiliation)
    policy := partner_policies[partner_type]
    
    normalized_resource_classification := normalize_classification(input.resource.classification)
    normalized_resource_classification in [normalize_classification(c) | c := policy.allowed_classifications[_]]
    
    user_clearance_level := clearance[normalize_classification(input.user.clearance)]
    resource_clearance_level := clearance[normalized_resource_classification]
    user_clearance_level < resource_clearance_level
    
    msg := sprintf("User clearance %s insufficient for resource classification %s", [input.user.clearance, input.resource.classification])
}

# Error message for missing caveats
error = msg {
    partner_type := get_partner_type(input.user.countryOfAffiliation)
    policy := partner_policies[partner_type]
    
    normalized_resource_classification := normalize_classification(input.resource.classification)
    normalized_resource_classification in [normalize_classification(c) | c := policy.allowed_classifications[_]]
    
    user_clearance_level := clearance[normalize_classification(input.user.clearance)]
    resource_clearance_level := clearance[normalized_resource_classification]
    user_clearance_level >= resource_clearance_level
    
    count(policy.required_caveats) > 0
    missing_caveats := [caveat | caveat := policy.required_caveats[_]; not caveat in input.user.caveats]
    count(missing_caveats) > 0
    
    msg := sprintf("User missing required caveats: %v", [missing_caveats])
}

# Error message for COI access
error = msg {
    partner_type := get_partner_type(input.user.countryOfAffiliation)
    policy := partner_policies[partner_type]
    
    count(input.resource.coiTags) > 0
    unauthorized_coi := [tag | tag := input.resource.coiTags[_]; not tag in policy.allowed_coi_tags]
    count(unauthorized_coi) > 0
    
    msg := sprintf("Partner type %s not authorized for COI tags: %v", [partner_type, unauthorized_coi])
}

# Error message for missing COI tags
error = msg {
    partner_type := get_partner_type(input.user.countryOfAffiliation)
    policy := partner_policies[partner_type]
    
    count(input.resource.coiTags) > 0
    every tag in policy.allowed_coi_tags {
        tag in input.resource.coiTags
    }
    
    missing_coi := [tag | tag := input.resource.coiTags[_]; not tag in input.user.coi]
    count(missing_coi) > 0
    
    msg := sprintf("User missing required COI tags: %v", [missing_coi])
}

# Error message for releasability restrictions
error = msg {
    count(input.resource.releasableTo) > 0
    not country_releasability_check(input.resource.releasableTo, input.user.countryOfAffiliation)
    
    msg := sprintf("Resource not releasable to %s", [input.user.countryOfAffiliation])
}