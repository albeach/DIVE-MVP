# DIVE25 System Architecture Overview

## Introduction

The DIVE25 Document Access System is designed as a secure, microservices-based architecture that provides controlled access to classified documents for NATO partner nations. This document outlines the system's core components, their interactions, and the overall architectural design principles.

## System Components

### High-Level Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                                                                         │
│  ┌─────────┐    ┌──────────┐    ┌─────────┐    ┌─────────────────────┐  │
│  │         │    │          │    │         │    │                     │  │
│  │ Browser │────▶  Kong    │────▶ Frontend│────▶ Authentication with │  │
│  │         │    │ Gateway  │    │ (Next.js)│   │ Keycloak (OIDC)     │  │
│  └─────────┘    └──────────┘    └─────────┘    └─────────────────────┘  │
│                      │                                    │             │
│                      │                                    │             │
│                 ┌────▼─────┐                      ┌──────▼──────┐       │
│                 │          │                      │             │       │
│                 │ Backend  │◀─────────────────────▶ OpenLDAP    │       │
│                 │ API      │                      │ Directory   │       │
│                 │          │                      │             │       │
│                 └────┬─────┘                      └─────────────┘       │
│                      │                                                  │
│          ┌───────────┴───────────┐                                      │
│          │                       │                                      │
│    ┌─────▼─────┐           ┌─────▼─────┐         ┌──────────────┐       │
│    │           │           │           │         │              │       │
│    │ MongoDB   │           │ Open      │◀────────▶ Policy       │       │
│    │ Database  │           │ Policy    │         │ Rules (Rego) │       │
│    │           │           │ Agent     │         │              │       │
│    └───────────┘           └───────────┘         └──────────────┘       │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                            ┌───────▼───────┐
                            │               │
                            │ Prometheus   │
                            │ & Grafana    │
                            │ Monitoring   │
                            │               │
                            └───────────────┘
```

### Component Description

#### 1. Frontend (Next.js)

The frontend is built with Next.js and React, providing a modern, responsive user interface. It includes:

- **Authentication Integration:** OIDC client integration with Keycloak
- **Document Browsing:** UI for searching and accessing documents
- **User Profile Management:** Self-service profile updates
- **Admin Panels:** Administrative interfaces for system management
- **Responsive Design:** Works on desktop and mobile devices

#### 2. Backend API (Node.js)

The backend API provides RESTful endpoints for all system functionality:

- **Document Management:** CRUD operations for documents
- **User Management:** User administration functions
- **Access Control:** Integration with OPA for authorization decisions
- **LDAP Integration:** User attribute lookup and verification
- **Authentication:** JWT validation and session management

#### 3. Kong API Gateway

Kong serves as the API gateway and provides:

- **Routing:** Routes requests to appropriate services
- **SSL Termination:** Handles HTTPS connections
- **Rate Limiting:** Prevents API abuse
- **Authentication:** LDAP and OIDC authentication plugins
- **Monitoring:** Request logging and metrics collection

#### 4. Keycloak Identity Provider

Keycloak manages authentication and identity:

- **Identity Management:** User authentication and registration
- **Federation:** Integration with external identity providers
- **Single Sign-On (SSO):** Centralized authentication for all system components
- **OAuth2/OIDC:** Standard protocol implementation
- **Multi-Factor Authentication:** Additional security layer

#### 5. OpenLDAP Directory

OpenLDAP stores user attributes and group memberships:

- **User Directory:** Centralized user attribute storage
- **Group Management:** User group and role associations
- **Attribute Storage:** Security clearance and other attributes
- **Directory Services:** LDAP protocol support for lookups

#### 6. MongoDB Database

MongoDB stores document metadata and system data:

- **Document Metadata:** Title, classification, owner, etc.
- **Access Logs:** Record of document access
- **System Configuration:** Configuration settings
- **User Preferences:** User-specific settings

#### 7. Open Policy Agent (OPA)

OPA enforces access control policies:

- **Policy Evaluation:** Determines if access should be granted
- **Attribute-Based Access Control:** Uses user and document attributes
- **Policy Rules:** Written in the Rego language
- **Centralized Decisions:** Single source of authorization truth

#### 8. Prometheus & Grafana

Monitoring and visualization tools:

- **Metrics Collection:** System performance data
- **Alerting:** Notification of system issues
- **Dashboards:** Visualization of system health
- **Log Aggregation:** Centralized logging

## Communication Flows

### Authentication Flow

1. User accesses the frontend application
2. Frontend redirects to Keycloak for authentication
3. User provides credentials to Keycloak
4. Keycloak authenticates the user (potentially consulting LDAP for attributes)
5. Keycloak issues JWT tokens to the frontend
6. Frontend includes tokens in API requests
7. Backend API validates tokens and extracts user information

### Document Access Flow

1. User requests a document through the frontend
2. Frontend sends request to Backend API via Kong
3. Backend API retrieves document metadata from MongoDB
4. Backend API sends an authorization query to OPA
5. OPA evaluates request against policy rules
6. If authorized, Backend API provides document access
7. Access is logged for audit purposes

## Security Architecture

The DIVE25 system implements multiple security layers:

- **Network Segmentation:** Components are isolated in separate containers
- **TLS Everywhere:** All communications use TLS encryption
- **Authentication:** Multiple authentication mechanisms (OIDC, LDAP)
- **Authorization:** Fine-grained access control with OPA
- **Audit Logging:** Comprehensive activity logging
- **Least Privilege:** Containers run with minimal permissions
- **Secrets Management:** Sensitive data is properly protected

## Deployment Architecture

The system can be deployed in several ways:

1. **Development Environment:** Docker Compose for local development
2. **Testing Environment:** Kubernetes with CI/CD pipeline
3. **Production Environment:** Kubernetes with high availability

### Container Orchestration

The system uses Docker containers orchestrated with:

- **Docker Compose:** For development environments
- **Kubernetes:** For testing and production environments

## Data Storage

The system uses several storage mechanisms:

- **MongoDB:** Document metadata and system data
- **OpenLDAP:** User attributes and directory information
- **File Storage:** Actual document content
- **PostgreSQL:** Keycloak and Kong configuration

## Scalability Considerations

The system is designed to scale horizontally:

- **Stateless Services:** API and frontend can be scaled out
- **Database Clustering:** MongoDB can be configured for clustering
- **Load Balancing:** Kong provides API load balancing
- **Microservices Architecture:** Independent scaling of components

## Next Steps

For a more detailed understanding of specific components, refer to:

- [Security Architecture](security.md)
- [Data Flow Diagrams](data-flow.md)
- [Integration Points](integration.md)

For implementation details, refer to the [Technical Documentation](../technical/api.md) section. 