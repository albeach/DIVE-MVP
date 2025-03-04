# DIVE25 User Guide

This guide provides comprehensive instructions for end users of the DIVE25 Document Access System. It covers authentication, document access, user profile management, and other essential functionality.

## Getting Started

### System Overview

The DIVE25 Document Access System provides secure, federated access to classified documents for NATO partner nations. The system ensures that:

- Only authorized users can access documents
- Documents are only accessible at appropriate classification levels
- All access is logged for auditing purposes
- Federation allows access across partner organizations

### Accessing the System

Access the DIVE25 system through your web browser at:

- Production: https://dive25.local (or your configured domain)
- Development: https://dive25.local (if using the local development setup)

## Authentication

### Logging In

1. Navigate to the DIVE25 login page
2. Click "Login" on the top right of the screen
3. You will be redirected to the authentication page
4. Enter your username and password
5. If configured, you may need to provide multi-factor authentication
6. Upon successful authentication, you will be redirected to the dashboard

### Federation Options

If your organization uses federated authentication:

1. On the login page, click "Login with your organization"
2. Select your organization from the list
3. You will be redirected to your organization's login page
4. Complete the authentication process with your organizational credentials
5. You will be redirected back to DIVE25 upon successful authentication

### Password Reset

If you forget your password:

1. Click "Forgot Password" on the login page
2. Enter your username or email address
3. Follow the instructions sent to your email to reset your password

## Dashboard

After logging in, you will see the main dashboard which includes:

### Dashboard Layout

- **Top Navigation Bar**: User profile, notifications, and logout
- **Left Sidebar**: Document categories, favorites, recent documents
- **Main Content Area**: Document search, recent documents, and announcements
- **Status Bar**: System status and notifications

### Key Dashboard Elements

- **Document Search**: Quick search for documents
- **Recent Documents**: Recently accessed documents
- **Favorites**: Documents marked as favorites
- **Announcements**: System announcements and notifications
- **Quick Access**: Shortcuts to common actions

## Document Management

### Searching for Documents

1. Use the search bar at the top of the dashboard
2. Enter keywords, document ID, or classification
3. Apply filters for:
   - Document type
   - Classification level
   - Date range
   - Author/owner
   - Keywords/tags
4. View search results in the main content area
5. Sort results by relevance, date, title, or classification

### Document Metadata

Each document includes metadata such as:

- Title
- Classification level
- Author/Owner
- Creation date
- Last modified date
- Keywords/Tags
- Description
- Version information

### Viewing Documents

To view a document:

1. Click on the document title in search results or listings
2. The document details page will open
3. Document content will be displayed if you have appropriate access
4. If access is denied, a message will explain the reason

### Document Actions

Depending on your permissions, you may be able to:

- **View**: Read the document content
- **Download**: Save a local copy (if allowed by policy)
- **Print**: Print the document (if allowed by policy)
- **Share**: Generate a secure link for other authorized users
- **Request Access**: Request elevated access for a document

## User Profile Management

### Viewing Your Profile

1. Click on your username in the top right corner
2. Select "Profile" from the dropdown menu
3. View your profile information including:
   - Personal information
   - Organization
   - Clearance level
   - Account settings

### Updating Profile Information

1. Navigate to your profile page
2. Click "Edit Profile"
3. Update your information
4. Click "Save Changes"

Note: Some information may be managed by your organization and cannot be changed directly.

### Security Settings

From your profile, you can manage security settings:

1. Change password
2. Configure multi-factor authentication
3. View active sessions
4. Review access logs

## Administrative Functions

These functions are only available to users with administrative privileges:

### User Management

Administrators can:

1. Create new user accounts
2. Modify user permissions
3. Deactivate accounts
4. Reset passwords
5. Review user activity logs

### Document Administration

Document administrators can:

1. Upload new documents
2. Update document metadata
3. Archive or delete documents
4. Manage access policies
5. Review document access logs

## Security Features

### Classification Handling

Documents are labeled with classification levels:

- UNCLASSIFIED
- RESTRICTED
- CONFIDENTIAL
- SECRET
- TOP SECRET

Users can only access documents at or below their clearance level, and only if they have appropriate need-to-know attributes.

### Access Control Indicators

The system provides visual indicators of access status:

- **Green**: You have full access
- **Yellow**: Limited access or additional restrictions
- **Red**: No access or restricted content

### Session Security

For your security:

- Sessions automatically timeout after a period of inactivity
- Concurrent sessions may be limited based on policy
- All actions are logged for security auditing
- Suspicious activity may trigger additional authentication

## Troubleshooting

### Common Issues

#### Access Denied

If you receive an "Access Denied" message:

1. Verify your clearance level is appropriate for the document
2. Check if you have the necessary need-to-know attributes
3. Contact your security officer if you believe you should have access

#### Document Not Found

If a document search returns "Not Found":

1. Check your search terms for typos
2. Verify the document still exists and hasn't been archived
3. Ensure you have permissions to see the document in search results

#### Authentication Issues

If you experience login problems:

1. Verify your username and password
2. Check if your account is locked after multiple failed attempts
3. Contact your administrator for assistance

### Getting Help

For assistance:

1. Click "Help" in the top navigation bar
2. Browse the help topics for guidance
3. Use the "Contact Support" form for specific issues
4. For urgent issues, contact your local system administrator

## Appendix

### Keyboard Shortcuts

- **Ctrl+F / Cmd+F**: Focus search bar
- **Ctrl+H / Cmd+H**: Go to home dashboard
- **Ctrl+P / Cmd+P**: View current document properties
- **Ctrl+S / Cmd+S**: Save changes (when editing)
- **Esc**: Close current dialog or cancel operation

### Glossary

- **ABAC**: Attribute Based Access Control
- **Clearance**: Security level authorization
- **Federation**: Cross-organization authentication
- **LDAP**: Lightweight Directory Access Protocol
- **Need-to-know**: Access control principle limiting access to those who need the information
- **OIDC**: OpenID Connect authentication protocol

### Reference Documents

- [NATO Security Policy](https://www.nato.int/cps/en/natohq/topics_69275.htm)
- [Classification Guidelines](../technical/classification.md)
- [Access Control Policy](../operations/access-control.md)

## Feedback

We welcome your feedback to improve DIVE25:

1. Click "Feedback" in the footer
2. Complete the feedback form
3. Submit your comments and suggestions 