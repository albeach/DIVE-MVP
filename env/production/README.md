# Production Environment Configuration

This directory contains configuration files for the production environment deployment of DIVE25.

## Files

- `secrets.env`: Environment variables for production deployment. Contains sensitive information that should be encrypted before being committed to version control.

## Deployment

To deploy to the production environment, use the universal deployment script:

```bash
# Set up the production environment
./scripts/env-setup.sh -e prod -a setup

# Deploy to production
./scripts/env-setup.sh -e prod -a deploy
```

## Security Considerations

For production deployments, follow these security best practices:

1. **Secure Secrets Management**: 
   - Use Sealed Secrets for Kubernetes deployments
   - Rotate all credentials regularly
   - Never commit unencrypted secrets to version control

2. **SSL/TLS**:
   - Use proper SSL certificates from a trusted CA
   - Configure HTTPS for all services
   - Set up automatic certificate renewal

3. **Access Control**:
   - Implement strict network policies
   - Use role-based access control (RBAC) for Kubernetes
   - Limit SSH access to production servers

4. **Monitoring and Alerting**:
   - Set up alerts for abnormal system behavior
   - Configure log aggregation
   - Monitor API usage and system performance

## Environment Variables

Production environment variables are stored in `secrets.env`. This file should be created from the template and populated with production values:

```bash
cp ../../.env.example ./secrets.env
```

Configure the following variables specifically for production:

- Set `ENVIRONMENT=production`
- Update `PROD_BASE_DOMAIN` to the production domain
- Set strong passwords for all services
- Configure proper CORS settings
- Update external service endpoints

## Kubernetes Configuration

The Kubernetes configuration for production is stored in `k8s/environments/production`. This includes:

- Resource limits and requests
- Replica counts for high availability
- Ingress configurations for production domains
- PersistentVolume claims for data persistence

## Backup and Disaster Recovery

Configure regular backups of:

- MongoDB data
- PostgreSQL databases
- LDAP directory
- Configuration files

For disaster recovery, document the process to restore services from backups and keep this documentation updated. 