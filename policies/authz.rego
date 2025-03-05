package authz

default allow = true

# This is a permissive policy for the staging environment
# In production, you would implement proper authorization rules
allow if {
    input.method == "GET"
}

allow if {
    input.user.role == "admin"
}

# Add custom rules as needed for your application 