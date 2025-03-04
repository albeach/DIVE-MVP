# Kubernetes Deployment Guide

This guide provides instructions for deploying the DIVE25 Document Access System on Kubernetes, including cluster setup, configuration, and management.

## Kubernetes Architecture

The DIVE25 system is designed as a cloud-native application deployed on Kubernetes with the following architecture:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                            Kubernetes Cluster                            │
│                                                                         │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐     │
│  │   Namespace:    │    │   Namespace:    │    │   Namespace:    │     │
│  │     dive-dev    │    │   dive-staging  │    │    dive-prod    │     │
│  └─────────────────┘    └─────────────────┘    └─────────────────┘     │
│                                                                         │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐     │
│  │   Namespace:    │    │   Namespace:    │    │   Namespace:    │     │
│  │  dive-monitoring│    │   dive-logging  │    │  dive-security  │     │
│  └─────────────────┘    └─────────────────┘    └─────────────────┘     │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────┐       │
│  │                    Namespace: dive-infra                     │       │
│  │                                                             │       │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │       │
│  │  │    Cert     │  │   Ingress   │  │  Service Mesh       │  │       │
│  │  │   Manager   │  │  Controller │  │  (Istio/Linkerd)    │  │       │
│  │  └─────────────┘  └─────────────┘  └─────────────────────┘  │       │
│  └─────────────────────────────────────────────────────────────┘       │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

## Prerequisites

Before deploying the DIVE25 system on Kubernetes, ensure you have:

1. **Kubernetes Cluster**: A running Kubernetes cluster (v1.23+)
2. **kubectl**: Configured to access your cluster
3. **Helm**: Helm 3.8.0+ installed
4. **Storage**: Dynamic provisioning for persistent volumes
5. **Container Registry**: Access to container images
6. **Domain Names**: Configured for system access
7. **TLS Certificates**: For secure communication
8. **Resource Capacity**: Sufficient CPU, memory, and storage

## Environment Setup

### Namespaces

Create the required namespaces:

```bash
kubectl create namespace dive-infra
kubectl create namespace dive-dev
kubectl create namespace dive-staging
kubectl create namespace dive-prod
kubectl create namespace dive-monitoring
kubectl create namespace dive-logging
kubectl create namespace dive-security
```

### Infrastructure Components

1. **Ingress Controller**:

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace dive-infra \
  --set controller.replicaCount=2 \
  --set controller.nodeSelector."kubernetes\.io/os"=linux \
  --set controller.admissionWebhooks.enabled=true \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-type"="nlb"
```

2. **Cert Manager**:

```bash
helm repo add jetstack https://charts.jetstack.io
helm install cert-manager jetstack/cert-manager \
  --namespace dive-infra \
  --set installCRDs=true \
  --set prometheus.enabled=true
```

3. **Service Mesh** (using Istio):

```bash
helm repo add istio https://istio-release.storage.googleapis.com/charts
helm install istio-base istio/base -n dive-infra
helm install istiod istio/istiod -n dive-infra \
  --set global.mtls.enabled=true \
  --set global.proxy.accessLogFile="/dev/stdout"
```

### Storage Configuration

Create storage classes for different data types:

```yaml
# document-storage.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: document-storage
provisioner: kubernetes.io/aws-ebs
parameters:
  type: gp3
  encrypted: "true"
reclaimPolicy: Retain
allowVolumeExpansion: true
```

Apply the configuration:

```bash
kubectl apply -f document-storage.yaml
```

## Deployment Configuration

### Helm Chart Structure

The DIVE25 system is deployed using Helm charts with the following structure:

```
dive/
├── Chart.yaml
├── values.yaml
├── values-dev.yaml
├── values-staging.yaml
├── values-prod.yaml
├── templates/
│   ├── configmap.yaml
│   ├── secrets.yaml
│   ├── deployments/
│   │   ├── api-gateway.yaml
│   │   ├── auth-service.yaml
│   │   ├── directory-service.yaml
│   │   ├── document-service.yaml
│   │   ├── policy-service.yaml
│   │   ├── search-service.yaml
│   │   └── storage-service.yaml
│   ├── services/
│   │   └── ...
│   ├── ingress/
│   │   └── ...
│   └── hpa/
│       └── ...
└── charts/
    ├── mongodb/
    ├── elasticsearch/
    ├── minio/
    └── keycloak/
```

### Configuration Values

Create environment-specific configurations using values files:

```yaml
# values-prod.yaml example
global:
  environment: production
  domain: dive25.example.org
  replicas: 3
  resources:
    requests:
      memory: "512Mi"
      cpu: "250m"
    limits:
      memory: "1Gi"
      cpu: "500m"

apiGateway:
  replicas: 3
  service:
    type: ClusterIP
  ingress:
    enabled: true
    annotations:
      kubernetes.io/ingress.class: nginx
      cert-manager.io/cluster-issuer: letsencrypt-prod

authService:
  replicas: 3
  keycloak:
    adminUser: admin
    realm: dive25

# ... more component configurations
```

## Deployment Process

### Deploying Using Helm

1. **Add the DIVE25 Helm repository**:

```bash
helm repo add dive25 https://helm.dive25.example.org
helm repo update
```

2. **Deploy to development environment**:

```bash
helm upgrade --install dive dive25/dive \
  --namespace dive-dev \
  --values values-dev.yaml \
  --set global.imageTag=latest
```

3. **Deploy to staging environment**:

```bash
helm upgrade --install dive dive25/dive \
  --namespace dive-staging \
  --values values-staging.yaml \
  --set global.imageTag=1.0.0-rc.1
```

4. **Deploy to production environment**:

```bash
helm upgrade --install dive dive25/dive \
  --namespace dive-prod \
  --values values-prod.yaml \
  --set global.imageTag=1.0.0 \
  --timeout 10m \
  --atomic
```

### Post-Deployment Verification

Verify the deployment status:

```bash
kubectl get pods -n dive-prod
kubectl get services -n dive-prod
kubectl get ingress -n dive-prod
```

Test the deployed services:

```bash
# Test API Gateway
curl -k https://api.dive25.example.org/health

# Check service health endpoints
for svc in auth document search storage; do
  kubectl exec -it deploy/api-gateway -n dive-prod -- curl -s http://${svc}-service:8080/health
done
```

## High Availability Configuration

### Replica Count

Configure appropriate replica counts for production:

```yaml
# High availability configuration
apiGateway:
  replicas: 3
  podAntiAffinity: true

authService:
  replicas: 3
  podAntiAffinity: true

documentService:
  replicas: 5
  podAntiAffinity: true

# ... other services
```

### Horizontal Pod Autoscaling

Configure HPA for dynamic scaling:

```yaml
# HPA configuration
apiGateway:
  autoscaling:
    enabled: true
    minReplicas: 3
    maxReplicas: 10
    targetCPUUtilizationPercentage: 70
    targetMemoryUtilizationPercentage: 80

documentService:
  autoscaling:
    enabled: true
    minReplicas: 5
    maxReplicas: 15
    targetCPUUtilizationPercentage: 70
```

### Pod Disruption Budgets

Configure PDBs to ensure service availability during cluster operations:

```yaml
# PDB configuration
apiGateway:
  podDisruptionBudget:
    enabled: true
    minAvailable: 2

documentService:
  podDisruptionBudget:
    enabled: true
    minAvailable: 3
```

## Security Configuration

### Network Policies

Apply network policies to restrict pod-to-pod communication:

```yaml
# Sample network policy
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: document-service-policy
  namespace: dive-prod
spec:
  podSelector:
    matchLabels:
      app: document-service
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: api-gateway
    - podSelector:
        matchLabels:
          app: search-service
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: storage-service
    - podSelector:
        matchLabels:
          app: policy-service
    - podSelector:
        matchLabels:
          app: mongodb
```

### Secret Management

Use Kubernetes secrets or an external secrets manager:

```bash
# Create secrets for sensitive configuration
kubectl create secret generic dive-db-credentials \
  --namespace dive-prod \
  --from-literal=username=dive_user \
  --from-literal=password=$(openssl rand -base64 32)
```

For production, consider using a secrets management tool like HashiCorp Vault:

```bash
# Install Vault
helm repo add hashicorp https://helm.releases.hashicorp.io
helm install vault hashicorp/vault --namespace dive-security
```

## Monitoring & Logging

### Prometheus & Grafana Setup

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace dive-monitoring \
  --set grafana.enabled=true \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false
```

### Logging with EFK Stack

```bash
helm repo add elastic https://helm.elastic.co
helm install elasticsearch elastic/elasticsearch \
  --namespace dive-logging \
  --set replicas=3

helm install kibana elastic/kibana \
  --namespace dive-logging

helm repo add fluent https://fluent.github.io/helm-charts
helm install fluent-bit fluent/fluent-bit \
  --namespace dive-logging \
  --set config.outputs="[OUTPUT]\n    Name es\n    Host elasticsearch-master\n    Port 9200\n    Index dive\n    Generate_ID On"
```

## Backup & Disaster Recovery

### Database Backups

Configure regular backups for MongoDB:

```yaml
# MongoDB backup CronJob
apiVersion: batch/v1
kind: CronJob
metadata:
  name: mongodb-backup
  namespace: dive-prod
spec:
  schedule: "0 1 * * *"  # Daily at 1am
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: mongodb-backup
            image: mongo:4.4
            command:
            - /bin/sh
            - -c
            - |
              mongodump --uri="mongodb://$(MONGODB_USERNAME):$(MONGODB_PASSWORD)@mongodb:27017/dive" --archive=/backup/dive-$(date +%Y%m%d).gz --gzip
            env:
            - name: MONGODB_USERNAME
              valueFrom:
                secretKeyRef:
                  name: dive-db-credentials
                  key: username
            - name: MONGODB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: dive-db-credentials
                  key: password
            volumeMounts:
            - name: backup-volume
              mountPath: /backup
          volumes:
          - name: backup-volume
            persistentVolumeClaim:
              claimName: mongodb-backup-pvc
          restartPolicy: OnFailure
```

### Document Storage Backups

Configure MinIO backups:

```bash
kubectl create cronjob minio-backup --image=minio/mc:latest \
  --schedule="0 2 * * *" \
  --namespace=dive-prod \
  -- /bin/sh -c 'mc alias set dive-minio http://minio:9000 $MINIO_ACCESS_KEY $MINIO_SECRET_KEY && mc mirror dive-minio/documents s3/dive-backup/documents --overwrite'
```

## Maintenance Procedures

### Rolling Updates

Perform rolling updates to minimize downtime:

```bash
kubectl set image deployment/document-service document-service=dive25/document-service:1.0.1 -n dive-prod
```

Using Helm:

```bash
helm upgrade dive dive25/dive \
  --namespace dive-prod \
  --set documentService.image.tag=1.0.1 \
  --reuse-values
```

### Scaling Operations

Scale specific deployments:

```bash
# Scale up document service
kubectl scale deployment document-service --replicas=8 -n dive-prod

# Scale down during maintenance window
kubectl scale deployment search-service --replicas=1 -n dive-prod
```

### Rollbacks

Rollback to previous release:

```bash
# Using kubectl
kubectl rollout undo deployment/document-service -n dive-prod

# Using Helm
helm rollback dive 1 -n dive-prod
```

## Troubleshooting

### Common Issues and Resolutions

1. **Pod Crashlooping**:
   ```bash
   kubectl describe pod <pod-name> -n dive-prod
   kubectl logs <pod-name> -n dive-prod
   ```

2. **Service Connectivity Issues**:
   ```bash
   kubectl exec -it <pod-name> -n dive-prod -- curl -v http://service-name:port/health
   ```

3. **Resource Constraints**:
   ```bash
   kubectl top pods -n dive-prod
   kubectl describe nodes | grep -A 5 "Allocated resources"
   ```

4. **Persistent Volume Issues**:
   ```bash
   kubectl get pv,pvc -n dive-prod
   kubectl describe pvc <pvc-name> -n dive-prod
   ```

## Multi-Cluster Deployment

For enhanced availability and disaster recovery, deploy across multiple clusters:

### Configuration for Multi-Cluster

1. **Set up federation**:
   ```bash
   kubectl config use-context cluster1-context
   kubefed init federation --host-cluster-context=cluster1-context --dns-provider=aws-route53
   ```

2. **Join clusters**:
   ```bash
   kubefed join cluster1 --host-cluster-context=cluster1-context --cluster-context=cluster1-context
   kubefed join cluster2 --host-cluster-context=cluster1-context --cluster-context=cluster2-context
   ```

3. **Deploy federated services**:
   ```yaml
   apiVersion: types.kubefed.io/v1beta1
   kind: FederatedDeployment
   metadata:
     name: document-service
     namespace: dive-prod
   spec:
     template:
       metadata:
         labels:
           app: document-service
       spec:
         replicas: 3
         # ... deployment spec
     placement:
       clusters:
       - name: cluster1
       - name: cluster2
     overrides:
     - clusterName: cluster1
       clusterOverrides:
       - path: "/spec/replicas"
         value: 3
     - clusterName: cluster2
       clusterOverrides:
       - path: "/spec/replicas"
         value: 2
   ```

## Related Documentation

- [Installation Guide](installation.md)
- [CI/CD Pipeline](ci-cd.md)
- [Monitoring Guide](../performance/monitoring.md)
- [Security Architecture](../architecture/security.md) 