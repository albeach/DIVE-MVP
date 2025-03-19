# opa/policies/access_policy.rego
package access_policy

# Define clearance hierarchy from lowest to highest
clearance = {
  "UNCLASSIFIED": 0,
  "RESTRICTED": 1,
  "NATO CONFIDENTIAL": 2,
  "NATO SECRET": 3,
  "COSMIC TOP SECRET": 4
}

# Define NATO member nations
nato_nations = {
  "ALB": true,  # Albania
  "BEL": true,  # Belgium
  "BGR": true,  # Bulgaria
  "CAN": true,  # Canada
  "HRV": true,  # Croatia
  "CZE": true,  # Czech Republic
  "DNK": true,  # Denmark
  "EST": true,  # Estonia
  "FIN": true,  # Finland
  "FRA": true,  # France
  "DEU": true,  # Germany
  "GRC": true,  # Greece
  "HUN": true,  # Hungary
  "ISL": true,  # Iceland
  "ITA": true,  # Italy
  "LVA": true,  # Latvia
  "LTU": true,  # Lithuania
  "LUX": true,  # Luxembourg
  "MNE": true,  # Montenegro
  "NLD": true,  # Netherlands
  "MKD": true,  # North Macedonia
  "NOR": true,  # Norway
  "POL": true,  # Poland
  "PRT": true,  # Portugal
  "ROU": true,  # Romania
  "SVK": true,  # Slovakia
  "SVN": true,  # Slovenia
  "ESP": true,  # Spain
  "SWE": true,  # Sweden
  "TUR": true,  # Turkey
  "GBR": true,  # United Kingdom
  "USA": true   # United States
}

# Define Five Eyes nations
fvey_nations = {
  "AUS": true,  # Australia
  "CAN": true,  # Canada
  "NZL": true,  # New Zealand
  "GBR": true,  # United Kingdom
  "USA": true   # United States
}

# Define EU member nations
eu_nations = {
  "AUT": true,  # Austria
  "BEL": true,  # Belgium
  "BGR": true,  # Bulgaria
  "HRV": true,  # Croatia
  "CYP": true,  # Cyprus
  "CZE": true,  # Czech Republic
  "DNK": true,  # Denmark
  "EST": true,  # Estonia
  "FIN": true,  # Finland
  "FRA": true,  # France
  "DEU": true,  # Germany
  "GRC": true,  # Greece
  "HUN": true,  # Hungary
  "IRL": true,  # Ireland
  "ITA": true,  # Italy
  "LVA": true,  # Latvia
  "LTU": true,  # Lithuania
  "LUX": true,  # Luxembourg
  "MLT": true,  # Malta
  "NLD": true,  # Netherlands
  "POL": true,  # Poland
  "PRT": true,  # Portugal
  "ROU": true,  # Romania
  "SVK": true,  # Slovakia
  "SVN": true,  # Slovenia
  "ESP": true,  # Spain
  "SWE": true   # Sweden
}

# Default access for basic resources
default_access if {
    # Unclassified resources are accessible to all users
    input.resource.classification == "UNCLASSIFIED"
}