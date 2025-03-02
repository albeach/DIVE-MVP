const fs = require('fs');
const path = require('path');
const jsdoc2md = require('jsdoc-to-markdown');
const glob = require('glob');

// Generate API documentation
async function generateApiDocs() {
    console.log('Generating API documentation...');

    const apiSourceFiles = glob.sync('../api/src/**/*.js');
    const apiDocs = jsdoc2md.renderSync({
        files: apiSourceFiles,
        configure: '../api/jsdoc.json',
    });

    fs.writeFileSync(path.join(__dirname, 'technical/api.md'), apiDocs);
}

// Generate Frontend documentation
async function generateFrontendDocs() {
    console.log('Generating Frontend documentation...');

    const frontendSourceFiles = glob.sync('../frontend/src/**/*.{js,jsx,ts,tsx}');
    const frontendDocs = jsdoc2md.renderSync({
        files: frontendSourceFiles,
        configure: '../frontend/jsdoc.json',
    });

    fs.writeFileSync(path.join(__dirname, 'technical/frontend.md'), frontendDocs);
}

// Generate Architecture documentation
async function generateArchitectureDocs() {
    console.log('Generating Architecture documentation...');

    // This is just a placeholder - in a real system, 
    // you might use tools like PlantUML or Mermaid to generate diagrams

    const architectureDoc = `
# DIVE25 System Architecture

## Overview

DIVE25 is a secure, federated document access system for NATO partners, designed to provide secure access to classified documents with proper authentication and authorization controls.

## Components

The system comprises several components:

- **Frontend**: Next.js + Tailwind CSS user interface
- **Backend API**: Node.js API for document access and management
- **Keycloak**: Identity and access management for federation
- **OpenLDAP**: Central directory for user attributes
- **MongoDB**: Document metadata storage
- **Open Policy Agent (OPA)**: Policy enforcement using Rego rules
- **Kong**: API gateway and reverse proxy
- **Prometheus & Grafana**: Monitoring and logging

## Security Architecture

The system implements a defense-in-depth approach with:

1. **Authentication**: Federated authentication through Keycloak
2. **Authorization**: Attribute-Based Access Control (ABAC) using OPA
3. **Network Security**: Kubernetes Network Policies and Kong API Gateway
4. **Data Protection**: Encrypted storage and proper classification handling
5. **Monitoring**: Comprehensive logging and alerting through Prometheus and Grafana

## Deployment Architecture

The system is deployed using Kubernetes for both development and production environments:

- **Development**: Kubernetes cluster with development-specific configurations
- **Production**: Kubernetes cluster with production-specific security hardening
`;

    fs.writeFileSync(path.join(__dirname, 'architecture/overview.md'), architectureDoc);
}

// Generate Deployment documentation
async function generateDeploymentDocs() {
    console.log('Generating Deployment documentation...');

    const deploymentDoc = `
# DIVE25 Deployment Guide

## Prerequisites

- Kubernetes cluster (v1.22+)
- Kubectl configured to access the cluster
- Kustomize (v4.5+)
- Container registry access

## Deployment Steps

1. **Clone the Repository**

   \`\`\`bash
   git clone https://github.com/your-org/dive25.git
   cd dive25
   \`\`\`

2. **Configure Environment**

   For development:
   \`\`\`bash
   # Update secrets in k8s/environments/development/secrets/
   # Configure domain in k8s/environments/development/kustomization.yaml
   \`\`\`

   For production:
   \`\`\`bash
   # Update secrets in k8s/environments/production/secrets/
   # Configure domain in k8s/environments/production/kustomization.yaml
   \`\`\`

3. **Deploy**

   For development:
   \`\`\`bash
   kustomize build k8s/environments/development | kubectl apply -f -
   \`\`\`

   For production:
   \`\`\`bash
   kustomize build k8s/environments/production | kubectl apply -f -
   \`\`\`

4. **Verify Deployment**

   \`\`\`bash
   kubectl get pods -n dive25-dev  # For development
   kubectl get pods -n dive25-prod  # For production
   \`\`\`

## Monitoring

The system includes Prometheus and Grafana for monitoring:

- **Prometheus**: Available at \`https://prometheus.dive25.local\` (dev) or \`https://prometheus.dive25.com\` (prod)
- **Grafana**: Available at \`https://grafana.dive25.local\` (dev) or \`https://grafana.dive25.com\` (prod)

Default Grafana credentials:
- Username: admin
- Password: See secrets in \`k8s/environments/{env}/secrets/grafana-admin-password\`

## Troubleshooting

### Common Issues

1. **Pod Startup Failures**
   - Check logs: \`kubectl logs -n dive25-{env} {pod-name}\`
   - Check events: \`kubectl get events -n dive25-{env}\`

2. **Authentication Issues**
   - Verify Keycloak is running: \`kubectl get pods -n dive25-{env} | grep keycloak\`
   - Check Keycloak logs: \`kubectl logs -n dive25-{env} {keycloak-pod-name}\`

3. **Network Issues**
   - Verify services: \`kubectl get svc -n dive25-{env}\`
   - Check ingress: \`kubectl get ingress -n dive25-{env}\`
   - Test connectivity: \`kubectl exec -it {pod-name} -n dive25-{env} -- curl {service-url}\`
`;

    fs.writeFileSync(path.join(__dirname, 'deployment/guide.md'), deploymentDoc);
}

// Generate Operations documentation
async function generateOperationsDocs() {
    console.log('Generating Operations documentation...');

    const operationsDoc = `
# DIVE25 Operations Guide

## Routine Operations

### Backup and Restore

#### MongoDB Backup

\`\`\`bash
# Manual backup
kubectl exec -it {mongodb-pod} -n dive25-{env} -- mongodump --archive=/tmp/backup.gz --gzip

# Copy backup locally
kubectl cp dive25-{env}/{mongodb-pod}:/tmp/backup.gz ./backup-$(date +%Y%m%d).gz
\`\`\`

#### MongoDB Restore

\`\`\`bash
# Copy backup to pod
kubectl cp ./backup.gz dive25-{env}/{mongodb-pod}:/tmp/backup.gz

# Restore from backup
kubectl exec -it {mongodb-pod} -n dive25-{env} -- mongorestore --archive=/tmp/backup.gz --gzip
\`\`\`

### Logging

Logs are collected by Prometheus and visualized in Grafana:

1. Access Grafana at \`https://grafana.dive25.{domain}\`
2. Navigate to the "Logs" dashboard
3. Filter logs by component, level, or custom query

For direct log access:

\`\`\`bash
# View logs for a specific pod
kubectl logs -n dive25-{env} {pod-name}

# Follow logs in real-time
kubectl logs -n dive25-{env} {pod-name} -f

# View logs for all pods with a specific label
kubectl logs -n dive25-{env} -l app=dive25-api
\`\`\`

### Scaling

\`\`\`bash
# Scale API deployment
kubectl scale deployment -n dive25-{env} {env}-dive25-api --replicas=3

# Scale Frontend deployment
kubectl scale deployment -n dive25-{env} {env}-dive25-frontend --replicas=3
\`\`\`

## Security Operations

### Secret Rotation

1. **Keycloak Credentials**

   \`\`\`bash
   # Generate new secret
   NEW_SECRET=$(openssl rand -base64 32)
   
   # Update secret in Kubernetes
   kubectl create secret generic -n dive25-{env} keycloak-admin-secret \
     --from-literal=admin-password=$NEW_SECRET --dry-run=client -o yaml | \
     kubectl apply -f -
     
   # Restart Keycloak pods
   kubectl rollout restart deployment -n dive25-{env} {env}-keycloak
   \`\`\`

2. **Database Credentials**

   \`\`\`bash
   # Generate new password
   NEW_PASSWORD=$(openssl rand -base64 32)
   
   # Update MongoDB user password
   kubectl exec -it {mongodb-pod} -n dive25-{env} -- mongosh admin --eval \
     "db.changeUserPassword('dive25_app', '$NEW_PASSWORD')"
     
   # Update secret in Kubernetes
   kubectl create secret generic -n dive25-{env} mongodb-credentials \
     --from-literal=password=$NEW_PASSWORD --dry-run=client -o yaml | \
     kubectl apply -f -
     
   # Restart API pods to pick up new credentials
   kubectl rollout restart deployment -n dive25-{env} {env}-dive25-api
   \`\`\`

### Security Incident Response

In case of a security incident:

1. **Isolate**
   - Restrict network access: \`kubectl apply -f k8s/incident-response/isolate-networkpolicy.yaml\`
   - Scale down non-essential services: \`kubectl scale deployment -n dive25-{env} {deployment} --replicas=0\`

2. **Investigate**
   - Capture logs: \`kubectl logs -n dive25-{env} {pod} > incident-logs.txt\`
   - Capture pod details: \`kubectl describe pod -n dive25-{env} {pod} > incident-pod.txt\`

3. **Remediate**
   - Rotate secrets (see Secret Rotation section)
   - Apply security patches: \`kubectl apply -f k8s/security-patches/\`
   - Deploy updated containers: Update image versions and apply

4. **Report**
   - Document incident details
   - Review logs and timeline
   - Prepare incident report
`;

    fs.writeFileSync(path.join(__dirname, 'operations/guide.md'), operationsDoc);
}

// Main execution
async function main() {
    try {
        // Create documentation directories if they don't exist
        const directories = [
            'technical',
            'architecture',
            'deployment',
            'operations',
        ];

        directories.forEach(dir => {
            const dirPath = path.join(__dirname, dir);
            if (!fs.existsSync(dirPath)) {
                fs.mkdirSync(dirPath, { recursive: true });
            }
        });

        // Generate documentation
        await generateApiDocs();
        await generateFrontendDocs();
        await generateArchitectureDocs();
        await generateDeploymentDocs();
        await generateOperationsDocs();

        console.log('Documentation generation completed successfully!');
    } catch (error) {
        console.error('Error generating documentation:', error);
        process.exit(1);
    }
}

// Run the main function
main();