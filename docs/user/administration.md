# Administrator Guide

This guide provides comprehensive instructions for DIVE25 Document Access System administrators responsible for managing users, documents, permissions, and system configuration.

## Administrator Roles and Responsibilities

The DIVE25 system defines several administrative roles with different responsibilities:

1. **System Administrator**
   - System installation and configuration
   - Infrastructure management
   - Software updates and patches
   - System monitoring and alerts
   - Backup and recovery procedures

2. **Security Administrator**
   - User access control
   - Security policy configuration
   - Security incident response
   - Audit log review
   - Compliance reporting

3. **Content Administrator**
   - Document management
   - Metadata standards enforcement
   - Classification review
   - Document lifecycle management
   - Search configuration

4. **User Administrator**
   - User account management
   - Group and role assignments
   - User training and support
   - Access request processing
   - User activity monitoring

## Administrative Interface

### Accessing the Admin Console

1. Navigate to `https://[dive-system-url]/admin`
2. Authenticate using administrator credentials
3. Enable multi-factor authentication if prompted
4. The admin dashboard provides access to all administrative functions

![Admin Dashboard](../images/admin-dashboard.png)

### Admin Console Layout

The admin console is organized into the following main sections:

- **Dashboard**: System status, statistics, and alerts
- **Users & Access**: User, group, and role management
- **Documents**: Document management and metadata
- **System**: Configuration, logs, and maintenance
- **Security**: Policies, auditing, and compliance
- **Reports**: Analytics and reporting tools

## User Management

### Creating New Users

1. Navigate to **Users & Access** > **Users** > **Add User**
2. Complete the required user information:
   - Username (must be unique)
   - Full name
   - Email address
   - Initial password or option to send activation link
   - Organization/unit
   - Security clearance level
3. Assign appropriate roles and groups
4. Set account expiration date (if applicable)
5. Click **Create User**

```json
// Example user creation API request
POST /api/v1/admin/users
{
  "username": "jsmith",
  "fullName": "John Smith",
  "email": "john.smith@example.org",
  "initialPassword": "Temporary-Password-123",
  "forcePasswordChange": true,
  "organization": "NATO HQ",
  "clearanceLevel": "NATO_SECRET",
  "roles": ["document_viewer", "document_creator"],
  "groups": ["intelligence_unit", "planning_team"],
  "accountExpiration": "2023-12-31T23:59:59Z"
}
```

### Managing User Groups

1. Navigate to **Users & Access** > **Groups** > **Manage Groups**
2. To create a new group:
   - Click **Add Group**
   - Provide group name and description
   - Assign default roles for group members
   - Add users to the group
3. To modify an existing group:
   - Select the group from the list
   - Edit group details, roles, or membership
   - Click **Save Changes**

### Role-Based Access Control

The DIVE25 system uses role-based access control (RBAC) combined with attribute-based policies. Standard roles include:

| Role Name | Description | Default Permissions |
|-----------|-------------|---------------------|
| system_admin | System administration | Full system access |
| security_admin | Security administration | User and security policy management |
| content_admin | Content administration | Document and metadata management |
| user_admin | User administration | User account management |
| document_creator | Document creation | Create and edit own documents |
| document_approver | Document approval | Review and approve documents |
| document_viewer | Document viewing | View documents (based on clearance) |
| auditor | System auditing | View audit logs and reports |

To assign roles to users:

1. Navigate to **Users & Access** > **Users**
2. Select the user to modify
3. Under the **Roles** tab, add or remove roles
4. Click **Save Changes**

## Security Policy Management

### Configuring Authentication Policies

1. Navigate to **Security** > **Authentication**
2. Configure authentication settings:
   - Password complexity requirements
   - Multi-factor authentication settings
   - Session timeout parameters
   - Failed login attempt limits
   - Authentication source configuration (LDAP/AD integration)

Example password policy configuration:

```yaml
password_policy:
  min_length: 12
  require_uppercase: true
  require_lowercase: true
  require_numeric: true
  require_special: true
  password_history: 24
  max_age_days: 90
  lockout_threshold: 5
  lockout_duration_minutes: 30
```

### Managing Security Classifications

1. Navigate to **Security** > **Classifications**
2. Configure document classification levels:
   - Add/edit classification levels
   - Define handling requirements for each level
   - Configure visual markings and metadata
   - Set access requirements for each level

Standard NATO classification levels:

| Classification | Description | Access Requirements |
|----------------|-------------|---------------------|
| NATO UNCLASSIFIED | Lowest sensitivity level | Basic NATO clearance |
| NATO RESTRICTED | Limited distribution | NATO Restricted clearance |
| NATO CONFIDENTIAL | Sensitive information | NATO Confidential clearance |
| NATO SECRET | High sensitivity | NATO Secret clearance |
| COSMIC TOP SECRET | Highest sensitivity | COSMIC Top Secret clearance |

### Configuring Document Access Policies

1. Navigate to **Security** > **Access Policies**
2. Create or modify policy rules:
   - Define conditions (user attributes, document attributes)
   - Specify permitted actions (view, edit, download, etc.)
   - Set policy priority order
   - Enable/disable policies

Example policy definition:

```json
{
  "policy_name": "Intelligence_Documents_Access",
  "description": "Controls access to intelligence documents",
  "conditions": {
    "user": {
      "clearance_level": ["NATO_SECRET", "COSMIC_TOP_SECRET"],
      "groups": ["intelligence_unit"]
    },
    "document": {
      "classification": ["NATO_CONFIDENTIAL", "NATO_SECRET"],
      "categories": ["intelligence", "operations"]
    }
  },
  "permissions": ["view", "download", "print"],
  "priority": 100,
  "enabled": true
}
```

## Document Management

### Document Classification Review

1. Navigate to **Documents** > **Classification Review**
2. Review documents pending classification verification:
   - Check document content against applied classification
   - Approve or modify document classification
   - Add handling instructions if needed
   - Document the review decision

### Metadata Management

1. Navigate to **Documents** > **Metadata Schemas**
2. Configure metadata schemas:
   - Define required metadata fields
   - Create custom metadata templates
   - Configure validation rules
   - Set default values

Example metadata schema for operational documents:

```json
{
  "schema_name": "operational_document",
  "required_fields": [
    "title", "author", "classification", "operation_name", 
    "document_type", "effective_date"
  ],
  "optional_fields": [
    "expiration_date", "related_documents", "keywords", 
    "distribution_list", "version"
  ],
  "field_validation": {
    "classification": {
      "type": "enum",
      "values": ["NATO_UNCLASSIFIED", "NATO_RESTRICTED", "NATO_CONFIDENTIAL", "NATO_SECRET"]
    },
    "effective_date": {
      "type": "date",
      "min": "current_date"
    }
  }
}
```

### Content Lifecycle Management

1. Navigate to **Documents** > **Lifecycle**
2. Configure document lifecycle policies:
   - Define retention periods for different document types
   - Set review schedules for classified documents
   - Configure archiving rules
   - Set up document expiration and purge policies

Example lifecycle policy:

```yaml
document_lifecycle:
  operational_plans:
    retention_period: 7_years
    review_schedule: 1_year
    archive_after: 2_years
    purge_after: 10_years
    retention_triggers:
      - operation_end_date
      - document_superseded
  intelligence_reports:
    retention_period: 10_years
    review_schedule: 6_months
    archive_after: 3_years
    purge_after: 15_years
    special_handling: true
```

## System Configuration

### System Settings

1. Navigate to **System** > **Configuration**
2. Configure system-wide settings:
   - API rate limits
   - Document upload size limits
   - Thumbnail generation settings
   - Search indexing configuration
   - Notification settings

### Storage Configuration

1. Navigate to **System** > **Storage**
2. Configure document storage:
   - Storage locations and quotas
   - Replication settings
   - Backup schedules
   - Encryption settings

### Search Configuration

1. Navigate to **System** > **Search**
2. Configure search functionality:
   - Index update frequency
   - Searchable fields
   - Custom analyzers and tokenizers
   - Relevance tuning

Example search configuration:

```yaml
search_configuration:
  index_update_frequency: 5_minutes
  full_reindex_schedule: daily
  text_extraction:
    enabled_formats:
      - pdf
      - docx
      - pptx
      - xlsx
      - txt
    ocr_enabled: true
    language_detection: true
  field_weights:
    title: 5.0
    content: 1.0
    keywords: 3.0
    author: 2.0
    summary: 4.0
  result_highlighting: true
  max_results_per_page: 100
```

## Monitoring and Maintenance

### System Health Monitoring

1. Navigate to **System** > **Health**
2. Monitor system components:
   - Service status and uptime
   - Resource utilization (CPU, memory, disk)
   - Database performance
   - API response times
   - Queue depths

![System Health Dashboard](../images/system-health.png)

### Audit Logging

1. Navigate to **Security** > **Audit Logs**
2. View and analyze security-relevant events:
   - Authentication events
   - Access control decisions
   - Admin actions
   - Document operations
   - Policy changes

The audit log provides the following information:

- Timestamp
- Event type
- User/service identifier
- IP address
- Action performed
- Target resource
- Status/result
- Additional context

Example audit log query:

```sql
-- Find all document access attempts for classified documents
SELECT 
  timestamp, user_id, ip_address, action, document_id, result
FROM audit_logs
WHERE 
  action = 'document_access' AND
  document_classification IN ('NATO_CONFIDENTIAL', 'NATO_SECRET') AND
  timestamp > '2023-01-01T00:00:00Z'
ORDER BY timestamp DESC;
```

### Backup and Recovery

1. Navigate to **System** > **Backup & Recovery**
2. Configure backup settings:
   - Backup schedules
   - Retention policy
   - Storage location
   - Verification procedures

3. Perform recovery operations:
   - System restore
   - Document recovery
   - Point-in-time recovery

Backup schedule example:

```yaml
backup_strategy:
  database:
    full_backup: daily
    incremental_backup: hourly
    retention: 30_days
    verification: true
  document_storage:
    full_backup: weekly
    incremental_backup: daily
    retention: 90_days
  configuration:
    backup: daily
    retention: 90_days
  location:
    primary: azure_storage
    secondary: aws_s3
```

## Reporting and Analytics

### User Activity Reports

1. Navigate to **Reports** > **User Activity**
2. Generate reports on user activities:
   - Login patterns
   - Document access statistics
   - Search queries
   - Download activities
   - Administrative actions

### System Usage Analytics

1. Navigate to **Reports** > **System Usage**
2. View analytics on system usage:
   - Active users over time
   - Document operations per hour/day/month
   - Storage utilization trends
   - API call volume
   - Search performance

### Compliance Reporting

1. Navigate to **Reports** > **Compliance**
2. Generate compliance reports:
   - Security policy compliance
   - Classification handling compliance
   - Access control effectiveness
   - Required security control implementation

Example compliance dashboard metrics:

- Percentage of documents with proper classification
- Number of classification handling violations
- Access policy effectiveness score
- Required security control implementation status

## Troubleshooting Common Issues

### Authentication Problems

| Issue | Possible Causes | Resolution Steps |
|-------|----------------|------------------|
| User cannot log in | Incorrect credentials, account locked, expired password | Check account status, reset password, unlock account |
| MFA device not working | Device synchronization issue, device lost | Reset MFA, provide temporary access code |
| SSO integration failure | Configuration error, identity provider outage | Check SSO configuration, contact identity provider |

### Document Access Issues

| Issue | Possible Causes | Resolution Steps |
|-------|----------------|------------------|
| User cannot view document | Insufficient clearance, missing group membership | Check user attributes against access policy requirements |
| Document not found in search | Indexing delay, search permission issue | Verify document exists, check indexing status, verify search permissions |
| Cannot download document | Download policy restriction, network issue | Verify download permissions, check network connectivity |

### System Performance Issues

| Issue | Possible Causes | Resolution Steps |
|-------|----------------|------------------|
| Slow search response | Index fragmentation, high query volume | Optimize index, increase search service resources |
| Document upload fails | File size limit, storage capacity, format validation | Check file size against limits, verify storage availability |
| API timeouts | High system load, resource constraints | Check system resources, increase service capacity |

## Related Documentation

- [Installation Guide](../deployment/installation.md)
- [Security Architecture](../architecture/security.md)
- [API Documentation](../technical/api.md)
- [User Guide](guide.md) 