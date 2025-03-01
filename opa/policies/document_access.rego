// opa/policies/document_access.rego
package dive25.document_access

import data.dive25.partner_policies
import data.access_policy

# Default policy is to deny access
default allow = false

# Allow access if partner_policies allow or it's a default accessible resource
allow {
    partner_policies.allow
}

allow {
    access_policy.default_access
}

# Return an explanation for the decision
explanation = msg {
    partner_policies.allow
    msg = "Access granted based on partner policy rules"
}

explanation = msg {
    access_policy.default_access
    msg = "Access granted based on default access policy"
}

explanation = msg {
    not partner_policies.allow
    not access_policy.default_access
    msg = partner_policies.error
}