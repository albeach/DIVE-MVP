# DIVE25 OpenLDAP Configuration

This directory contains the OpenLDAP configuration for the DIVE25 application.

## Directory Structure

```
openldap/
├── bootstrap/               # Bootstrap configuration
│   ├── ldif/                # LDIF files for initial data
│   │   ├── 01-dive25-structure.ldif  # Base structure
│   │   ├── 02-dive25-values.ldif     # Predefined values
│   │   ├── 03-dive25-users.ldif      # Sample users
│   │   └── 04-dive25-groups.ldif     # User groups
│   ├── schema/              # Custom schema definitions
│   │   └── dive25.schema    # DIVE25 specific schema
│   ├── config/              # OpenLDAP configuration
│   │   └── dive25.conf      # DIVE25 specific configuration
│   └── setup.sh             # Bootstrap initialization script
├── certs/                   # SSL/TLS certificates
│   ├── ca.crt               # CA certificate
│   ├── ca.key               # CA private key
│   ├── server.crt           # Server certificate
│   └── server.key           # Server private key
├── data/                    # LDAP data storage
├── config/                  # LDAP configuration storage
├── docker-compose.yml       # Docker Compose for standalone deployment
├── setup.sh                 # Main setup script
├── generate-passwords.sh    # Helper script for password hashing
└── README.md                # This file
```

## Setup Instructions

1. **Generate certificates and initialize the structure**:

   ```bash
   ./setup.sh
   ```

   This will:
   - Create necessary directories
   - Generate self-signed certificates for TLS
   - Generate password hashes for sample users
   - Start the OpenLDAP and phpLDAPadmin containers

2. **Access phpLDAPadmin**:

   Open http://localhost:8085 in your browser and login with:
   - Login DN: `cn=admin,dc=dive25,dc=local`
   - Password: `admin_password` (or the value of LDAP_ADMIN_PASSWORD environment variable)

## Custom Schema

The DIVE25 application uses a custom LDAP schema with the following attributes:

- `clearance`: Security clearance level (TOP_SECRET, SECRET, CONFIDENTIAL, UNCLASSIFIED)
- `caveats`: Security caveats (TS, SCI, S, C, etc.)
- `countryOfAffiliation`: Country code (US, UK, CA, AU, NZ)
- `coi`: Communities of Interest (ADMIN, SYSTEM, RESEARCH, ANALYSIS, etc.)

These attributes are used by the application to determine access control based on security policies.

## Integration with DIVE25 Application

The DIVE25 API integrates with OpenLDAP for user authentication and attribute retrieval. The relevant environment variables in the API service are:

```yaml
LDAP_URL: ldap://openldap:389
LDAP_BIND_DN: cn=admin,dc=dive25,dc=local
LDAP_BIND_CREDENTIALS: admin_password
LDAP_SEARCH_BASE: dc=dive25,dc=local
LDAP_USER_SEARCH_FILTER: (uid={{username}})
LDAP_USER_SEARCH_ATTRIBUTES: uid,cn,mail,givenName,sn,o,countryOfAffiliation,clearance,caveats,coi
LDAP_GROUP_SEARCH_BASE: ou=groups,dc=dive25,dc=local
LDAP_GROUP_SEARCH_FILTER: (member={{dn}})
LDAP_GROUP_SEARCH_ATTRIBUTES: cn,description
```

These variables can be customized in the main docker-compose.yml file.

## Kong API Gateway Integration

The DIVE25 application integrates Kong API Gateway with OpenLDAP for authentication. The configuration includes:

1. **Kong LDAP Authentication Plugin**:
   - The LDAP authentication plugin is enabled in Kong
   - Configuration in `kong/kong.ldap.yml` defines the integration

2. **Kong-LDAP Configuration Service**:
   - A dedicated container applies the LDAP configuration to Kong
   - Automatically configures the routes that require LDAP authentication

3. **Testing Kong LDAP Authentication**:
   - Use the `/api/v1/ldap/authenticate` endpoint to test LDAP credentials
   - Kong uses this for authenticating API requests

## User Groups and Authorization

The OpenLDAP configuration includes group-based authorization:

1. **Group Structure**:
   - Groups are defined in `04-dive25-groups.ldif`
   - Groups are organized by role (administrators, analysts, researchers)
   - Security-based groups for clearance levels and country affiliations

2. **API Integration**:
   - The `/api/v1/ldap/users/{username}/groups` endpoint retrieves user groups
   - Group membership is used for authorization decisions

3. **OPA Integration**:
   - User attributes and group membership are passed to OPA policies
   - Security decisions are based on both attributes and group membership

## Custom Configuration

To modify the OpenLDAP configuration:

1. Edit the appropriate files in the `bootstrap/` directory
2. Restart the OpenLDAP container:

   ```bash
   docker-compose down
   docker-compose up -d
   ```

## Troubleshooting

- **LDAP Connection Issues**: Check that the LDAP_URL is correctly configured and that the OpenLDAP container is running
- **Authentication Failures**: Verify the LDAP_BIND_DN and LDAP_BIND_CREDENTIALS values
- **User Not Found**: Check the LDAP_SEARCH_BASE and LDAP_USER_SEARCH_FILTER values
- **Missing Attributes**: Verify that the custom schema is correctly loaded and that users have the required attributes
- **Group Issues**: Ensure group definitions are loaded and the member attribute references valid user DNs
- **Kong Authentication Failures**: Check the Kong LDAP plugin configuration and logs

For more detailed logs:

```bash
docker logs dive25-openldap
docker logs dive25-kong
``` 