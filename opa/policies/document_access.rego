# opa/policies/document_access.rego
package dive25.document_access

import data.dive25.partner_policies
import data.access_policy

# Default deny
default allow = false

# Allow access if partner_policies allow or it's a default accessible resource
allow if {
    partner_policies.allow
}

allow if {
    access_policy.default_access
}

# Return an explanation for the decision
explanation = msg if {
    allow
    msg = "Access granted"
}

explanation = msg if {
    not allow
    partner_policies.classification_mismatch_error(input.user, input.resource) != ""
    msg = partner_policies.classification_mismatch_error(input.user, input.resource)
}

explanation = msg if {
    not allow
    partner_policies.clearance_level_error(input.user, input.resource) != ""
    msg = partner_policies.clearance_level_error(input.user, input.resource)
}

explanation = msg if {
    not allow
    partner_policies.missing_caveats_error(input.user, input.resource) != ""
    msg = partner_policies.missing_caveats_error(input.user, input.resource)
}