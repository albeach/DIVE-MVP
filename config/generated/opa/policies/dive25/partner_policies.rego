# opa/policies/dive25/partner_policies.rego
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
allow = true if {
    partner_type := get_partner_type(input.user.countryOfAffiliation)
    policy := partner_policies[partner_type]
    
    # Check that the resource's classification (after normalization)
    # is among the allowed classifications (also normalized)
    normalized_resource_classification := normalize_classification(input.resource.classification)
    normalized_resource_classification in [normalize_classification(c) | c := policy.allowed_classifications[_]]
    
    # Check that the user's clearance level is sufficient for the resource's classification
    clearance_level_sufficient(input.user, input.resource)
    
    # Check that the user has all required caveats for the resource
    all_required_caveats_present(input.user, input.resource)
    
    # Check that the user's partner type is authorized for all COI tags on the resource
    all_coi_tags_allowed(input.user, input.resource)
    
    # Check that the user has all required COI tags for the resource
    all_coi_tags_present(input.user, input.resource)
    
    # Check that the user's country of affiliation is allowed to access the resource
    # based on the resource's releasability
    country_releasability_check(input.user, input.resource)
}

# Determine the partner type based on the country code
get_partner_type(country) = "five_eyes" if {
    country in ["USA", "GBR", "CAN", "AUS", "NZL"]
}

get_partner_type(country) = "nato" if {
    country in ["ALB", "BEL", "BGR", "HRV", "CZE", "DNK", "EST", "FRA", "DEU", "GRC", "HUN", "ISL", "ITA", "LVA", "LTU", "LUX", "MNE", "NLD", "MKD", "NOR", "POL", "PRT", "ROU", "SVK", "SVN", "ESP", "TUR"]
}

get_partner_type(country) = "eu" if {
    country in ["AUT", "BEL", "BGR", "HRV", "CYP", "CZE", "DNK", "EST", "FIN", "FRA", "DEU", "GRC", "HUN", "IRL", "ITA", "LVA", "LTU", "LUX", "MLT", "NLD", "POL", "PRT", "ROU", "SVK", "SVN", "ESP", "SWE"]
}

get_partner_type(country) = "other" if {
    not country in ["USA", "GBR", "CAN", "AUS", "NZL"]
    not country in ["ALB", "BEL", "BGR", "HRV", "CZE", "DNK", "EST", "FRA", "DEU", "GRC", "HUN", "ISL", "ITA", "LVA", "LTU", "LUX", "MNE", "NLD", "MKD", "NOR", "POL", "PRT", "ROU", "SVK", "SVN", "ESP", "TUR"]
    not country in ["AUT", "BEL", "BGR", "HRV", "CYP", "CZE", "DNK", "EST", "FIN", "FRA", "DEU", "GRC", "HUN", "IRL", "ITA", "LVA", "LTU", "LUX", "MLT", "NLD", "POL", "PRT", "ROU", "SVK", "SVN", "ESP", "SWE"]
}

# Check if the user's clearance level is sufficient for the resource's classification
clearance_level_sufficient(user, resource) if {
    clearance_levels := {
        "NONE": 0,
        "CONFIDENTIAL": 1,
        "SECRET": 2,
        "TOP SECRET": 3
    }
    
    user_clearance := clearance_levels[user.clearanceLevel]
    resource_classification := clearance_levels[resource.classification]
    
    user_clearance >= resource_classification
}

# Check if the user has all required caveats for the resource
all_required_caveats_present(user, resource) if {
    # If the resource has no caveats, this check passes
    count(resource.caveats) == 0
}

all_required_caveats_present(user, resource) if {
    # All resource caveats must be present in the user's caveats
    count(resource.caveats) > 0
    missing_caveats := {caveat | 
        caveat := resource.caveats[_]
        not caveat in user.caveats
    }
    count(missing_caveats) == 0
}

# Check if the user's partner type is authorized for all COI tags on the resource
all_coi_tags_allowed(user, resource) if {
    # If the resource has no COI tags, this check passes
    count(resource.coiTags) == 0
}

all_coi_tags_allowed(user, resource) if {
    # All resource COI tags must be allowed for the user's partner type
    count(resource.coiTags) > 0
    partner_type := get_partner_type(user.countryOfAffiliation)
    policy := partner_policies[partner_type]
    
    unauthorized_coi_tags := {tag |
        tag := resource.coiTags[_]
        not tag in policy.allowed_coi_tags
    }
    
    count(unauthorized_coi_tags) == 0
}

# Check if the user has all required COI tags for the resource
all_coi_tags_present(user, resource) if {
    # If the resource has no COI tags, this check passes
    count(resource.coiTags) == 0
}

all_coi_tags_present(user, resource) if {
    # All resource COI tags must be present in the user's COI tags
    count(resource.coiTags) > 0
    missing_coi_tags := {tag | 
        tag := resource.coiTags[_]
        not tag in user.coiTags
    }
    count(missing_coi_tags) == 0
}

# Check if the user's country of affiliation is allowed to access the resource
# based on the resource's releasability
country_releasability_check(user, resource) if {
    # If the resource has no releasability restrictions, this check passes
    count(resource.releasability) == 0
}

country_releasability_check(user, resource) if {
    # The user's country must be in the resource's releasability list
    count(resource.releasability) > 0
    user.countryOfAffiliation in resource.releasability
}

# Normalize classification to handle different formats and aliases
normalize_classification(classification) = "UNCLASSIFIED" if {
    classification in ["UNCLASSIFIED", "U", "UNCLAS"]
}

normalize_classification(classification) = "CONFIDENTIAL" if {
    classification in ["CONFIDENTIAL", "C", "CONF"]
}

normalize_classification(classification) = "SECRET" if {
    classification in ["SECRET", "S"]
}

normalize_classification(classification) = "TOP SECRET" if {
    classification in ["TOP SECRET", "TS"]
}

normalize_classification(classification) = classification if {
    not classification in ["UNCLASSIFIED", "U", "UNCLAS"]
    not classification in ["CONFIDENTIAL", "C", "CONF"]
    not classification in ["SECRET", "S"]
    not classification in ["TOP SECRET", "TS"]
}

# Error message for classification mismatch
classification_mismatch_error(user, resource) = msg if {
    partner_type := get_partner_type(user.countryOfAffiliation)
    policy := partner_policies[partner_type]
    normalized_resource_classification := normalize_classification(resource.classification)
    allowed_classifications := [normalize_classification(c) | c := policy.allowed_classifications[_]]
    not normalized_resource_classification in allowed_classifications
    
    msg := sprintf("User from %s (partner type: %s) is not authorized to access resources classified as %s. Allowed classifications: %v", 
                  [user.countryOfAffiliation, partner_type, resource.classification, policy.allowed_classifications])
}

# Error message for insufficient clearance level
clearance_level_error(user, resource) = msg if {
    clearance_levels := {
        "NONE": 0,
        "CONFIDENTIAL": 1,
        "SECRET": 2,
        "TOP SECRET": 3
    }
    
    user_clearance := clearance_levels[user.clearanceLevel]
    resource_classification := clearance_levels[resource.classification]
    
    user_clearance < resource_classification
    
    msg := sprintf("User has insufficient clearance level (%s) for resource classified as %s", 
                  [user.clearanceLevel, resource.classification])
}

# Error message for missing required caveats
missing_caveats_error(user, resource) = msg if {
    count(resource.caveats) > 0
    missing_caveats := {caveat | 
        caveat := resource.caveats[_]
        not caveat in user.caveats
    }
    count(missing_caveats) > 0
    
    msg := sprintf("User is missing required caveats: %v", [missing_caveats])
}

# Error message for unauthorized COI access
coi_access_error(user, resource) = msg if {
    count(resource.coiTags) > 0
    partner_type := get_partner_type(user.countryOfAffiliation)
    policy := partner_policies[partner_type]
    
    unauthorized_coi_tags := {tag |
        tag := resource.coiTags[_]
        not tag in policy.allowed_coi_tags
    }
    
    count(unauthorized_coi_tags) > 0
    
    msg := sprintf("Partner type %s is not authorized for COI tags: %v", [partner_type, unauthorized_coi_tags])
}

# Error message for missing COI tags
missing_coi_tags_error(user, resource) = msg if {
    count(resource.coiTags) > 0
    missing_coi_tags := {tag | 
        tag := resource.coiTags[_]
        not tag in user.coiTags
    }
    count(missing_coi_tags) > 0
    
    msg := sprintf("User is missing required COI tags: %v", [missing_coi_tags])
}

# Error message for releasability restrictions
releasability_error(user, resource) = msg if {
    count(resource.releasability) > 0
    not user.countryOfAffiliation in resource.releasability
    
    msg := sprintf("Resource is not releasable to %s. Releasable to: %v", 
                  [user.countryOfAffiliation, resource.releasability])
}