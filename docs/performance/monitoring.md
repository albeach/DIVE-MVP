# Monitoring Guide

This guide outlines the monitoring strategy and implementation for the DIVE25 Document Access System. It covers monitoring infrastructure, metrics collection, alerting, dashboards, and troubleshooting processes.

## Monitoring Strategy

The DIVE25 monitoring system follows these key principles:

1. **Comprehensive Coverage**: Monitor all critical system components
2. **Layered Approach**: Monitor at infrastructure, application, and business levels
3. **Actionable Alerts**: Alerts should be meaningful and lead to specific actions
4. **Performance Insights**: Provide visibility into system performance and bottlenecks
5. **Security Monitoring**: Track security-relevant events and anomalies

## Monitoring Infrastructure

### Components

The DIVE25 monitoring stack consists of:

| Component | Purpose | Implementation |
|-----------|---------|----------------|
| Metrics Collection | Gather performance metrics | Prometheus |
| Time-Series Database | Store metrics data | Prometheus, InfluxDB |
| Logs Management | Collect and analyze logs | Elasticsearch, Logstash, Kibana (ELK) |
| Visualization | Dashboards and reporting | Grafana |
| Alerting | Alert notification and management | Alertmanager, PagerDuty |
| Tracing | Distributed request tracing | Jaeger |
| Synthetic Monitoring | Simulated user interactions | Blackbox Exporter |

### Architecture

The monitoring architecture follows this high-level design:

```
┌───────────┐  ┌───────────┐  ┌───────────┐  ┌───────────┐
│ Web Client│  │API Gateway│  │ Services  │  │ Databases │
└─────┬─────┘  └─────┬─────┘  └─────┬─────┘  └─────┬─────┘
      │              │              │              │
┌─────▼──────────────▼──────────────▼──────────────▼─────┐
│                  Exporters & Agents                     │
│  (Node Exporter, JMX Exporter, Filebeat, OpenTelemetry) │
└─────────────────────────┬─────────────────────────────┬─┘
                          │                             │
                ┌─────────▼────────┐         ┌──────────▼─────────┐
                │    Prometheus    │         │   Logging Stack     │
                │  (Metrics Store) │         │  (ELK/Loki/Fluent)  │
                └─────────┬────────┘         └──────────┬──────────┘
                          │                             │
                ┌─────────▼────────┐         ┌──────────▼──────────┐
                │   Alertmanager   │         │       Jaeger        │
                │   (Alerts)       │         │     (Tracing)       │
                └─────────┬────────┘         └──────────┬──────────┘
                          │                             │
                          └──────────────┬──────────────┘
                                         │
                                  ┌──────▼──────┐
                                  │   Grafana   │
                                  │ (Dashboard) │
                                  └──────┬──────┘
                                         │
                               ┌─────────▼─────────┐
                               │    Notification   │
                               │     Channels      │
                               └───────────────────┘
```

## Metrics Collection

### System Metrics

Key system metrics monitored across all nodes:

- **CPU Usage**: Utilization percentage
- **Memory**: Used, available, cached
- **Disk**: Usage, I/O operations, latency
- **Network**: Throughput, packet rate, errors
- **System Load**: 1/5/15 minute averages
- **Process Metrics**: CPU, memory per process

### Application Metrics

Application-specific metrics:

- **Request Rate**: Requests per second
- **Error Rate**: Percentage of failed requests
- **Response Time**: Latency percentiles (p50, p90, p99)
- **Saturation**: Queue depth, concurrent connections
- **JVM Metrics**: Heap usage, garbage collection (for Java services)
- **Node.js Metrics**: Event loop lag, active handles (for Node.js services)

### Business Metrics

Business-level metrics:

- **Document Operations**: Uploads, downloads, searches
- **User Activity**: Logins, active sessions
- **Error Counts**: By type and service
- **API Usage**: Calls by endpoint and client
- **Authorization**: Access grants/denials

### Metric Exporters

Service-specific exporters:

| Service | Exporter | Metrics Path |
|---------|----------|--------------|
| API Gateway | Kong Prometheus Plugin | `/metrics` |
| Document Service | Prometheus Client | `/actuator/prometheus` |
| Search Service | Prometheus Client | `/metrics` |
| Authentication Service | JMX Exporter | `/metrics` |
| Storage Service | MinIO Prometheus Metrics | `/minio/prometheus/metrics` |
| Databases | MongoDB/PostgreSQL Exporters | `/metrics` |
| Kubernetes | kube-state-metrics | `/metrics` |

## Log Management

### Log Collection

Logs are collected using:

1. **Filebeat**: For file-based logs
2. **Fluentd**: For container logs
3. **Application Logs**: Direct to Elasticsearch or via message queue

### Log Format

Standard log format:

```json
{
  "timestamp": "2023-04-15T13:45:20.153Z",
  "level": "ERROR",
  "service": "document-service",
  "traceId": "abc123def456",
  "userId": "user123",
  "message": "Failed to process document",
  "context": {
    "documentId": "doc456",
    "errorCode": "PROC_ERR_001"
  },
  "exception": "java.io.IOException: File not found"
}
```

### Log Retention

- **Hot Storage**: 7 days (full detail)
- **Warm Storage**: 30 days (indexed)
- **Cold Storage**: 365 days (compliance archive)

## Distributed Tracing

Request tracing provides end-to-end visibility:

1. **Instrumentation**: Services use OpenTelemetry for trace generation
2. **Trace Propagation**: Consistent headers across service boundaries
3. **Trace Sampling**: Adaptive sampling based on request properties
4. **Visualization**: Jaeger UI for trace analysis

Example trace flow:

```
Client → API Gateway → Auth Service → Document Service → Storage Service
```

## Dashboard Setup

### Main Dashboards

1. **System Overview**: High-level system health
   - Service status
   - Error rates
   - Resource utilization
   - Request volume

2. **Service Dashboards**: Per-service metrics
   - Document Service metrics
   - Search Service performance
   - Authentication Service operations
   - Storage Service throughput

3. **Business Metrics**: User activity and data trends
   - Document operations by type
   - Active users
   - Search query patterns
   - Access patterns

### Example Grafana Dashboard Layout

#### System Overview Dashboard

```
┌───────────────────┐ ┌───────────────────┐ ┌───────────────────┐
│                   │ │                   │ │                   │
│   Service Status  │ │  Global Error     │ │ System Resource   │
│                   │ │  Rate             │ │ Utilization       │
└───────────────────┘ └───────────────────┘ └───────────────────┘

┌───────────────────────────┐ ┌───────────────────────────────┐
│                           │ │                               │
│   Request Rate            │ │   Response Time               │
│   (by service)            │ │   (by service)                │
│                           │ │                               │
└───────────────────────────┘ └───────────────────────────────┘

┌───────────────────┐ ┌───────────────────┐ ┌───────────────────┐
│                   │ │                   │ │                   │
│ Database          │ │ Message Queue     │ │ Cache Hit         │
│ Operations        │ │ Depth             │ │ Rate              │
└───────────────────┘ └───────────────────┘ └───────────────────┘

┌───────────────────────────────────────────────────────────────┐
│                                                               │
│   Recent Alerts and Events                                    │
│                                                               │
└───────────────────────────────────────────────────────────────┘
```

## Alerting

### Alert Categories

Alerts are categorized by severity:

1. **Critical**: Immediate action required, service impact
2. **Warning**: Potential issues requiring attention
3. **Info**: Informational alerts for awareness

### Key Alerts

| Alert | Description | Threshold | Severity |
|-------|-------------|-----------|----------|
| HighErrorRate | Service error rate too high | >5% for 5m | Critical |
| APILatency | API response time too high | >500ms p95 for 5m | Warning |
| DiskSpaceLow | Disk space running low | <15% free | Warning |
| ServiceDown | Service is not responding | 3 failed probes | Critical |
| CPUUsageHigh | CPU usage too high | >85% for 10m | Warning |
| MemoryUsageHigh | Memory usage too high | >85% for 10m | Warning |
| DocumentProcessingBacklog | Document processing queue too deep | >100 items for 15m | Warning |
| SecurityScanFailed | Security scan detected issues | Any failure | Critical |

### Alert Routing

Alerts are routed based on:

1. **Team**: Development, Operations, Security
2. **Service**: Document, Search, Authentication, etc.
3. **Severity**: Critical, Warning, Info
4. **Business Hours**: Different routes during/outside business hours

### Alert Response Procedures

1. **Acknowledge**: Confirm receipt of alert
2. **Assess**: Determine impact and urgency
3. **Investigate**: Identify root cause
4. **Resolve**: Fix the immediate issue
5. **Document**: Record incident details
6. **Review**: Post-incident analysis

## Health Checks

Health checks provide service status:

1. **Liveness**: Basic service availability
2. **Readiness**: Service ability to handle requests
3. **Dependency**: Status of dependent services
4. **Business Logic**: Key business functions

Health check endpoints:

| Service | Endpoint | Check Type |
|---------|----------|------------|
| API Gateway | `/health` | Liveness, Dependencies |
| Document Service | `/actuator/health` | Liveness, Readiness, Business Logic |
| Search Service | `/health` | Liveness, Readiness, Elasticsearch Dependency |
| Auth Service | `/health/status` | Liveness, Readiness, Database Dependency |
| Storage Service | `/minio/health` | Liveness, Storage Dependency |

## Performance Testing

Regular performance testing identifies bottlenecks:

1. **Load Testing**: Simulated normal load
2. **Stress Testing**: Beyond normal capacity
3. **Soak Testing**: Extended duration testing
4. **Spike Testing**: Sudden traffic increases

Key performance metrics:

| Metric | Target | Critical Threshold |
|--------|--------|-------------------|
| Document Upload Response Time | <2s (p95) | >5s (p95) |
| Document Search Response Time | <1s (p95) | >3s (p95) |
| Authentication Response Time | <300ms (p95) | >1s (p95) |
| Maximum Concurrent Users | 5,000 | <2,000 |
| Document Processing Rate | >100/minute | <50/minute |

## Troubleshooting Process

### Incident Response

When issues are detected:

1. **Identify**: Determine affected components
2. **Isolate**: Narrow down the problem area
3. **Investigate**: Analyze logs, metrics, and traces
4. **Resolve**: Apply fix or workaround
5. **Verify**: Confirm resolution
6. **Document**: Record incident details

### Common Issues and Solutions

| Issue | Symptoms | Investigation Steps | Possible Causes |
|-------|----------|---------------------|----------------|
| High Latency | Slow response times | Check service metrics, database query times, trace spans | Database bottleneck, network issues, resource contention |
| Error Spikes | Increased error rates | Review error logs, check recent deployments | Code bug, dependency failure, resource exhaustion |
| Resource Exhaustion | High CPU/memory usage | Check resource metrics, identify consuming processes | Memory leak, inefficient queries, traffic spike |
| Authentication Failures | Login errors, 401 responses | Check auth service logs, token validation issues | Expired certificates, configuration error, service unavailability |

### Debugging Tools

1. **Logging**: Increase log verbosity temporarily
2. **Tracing**: Follow request flows across services
3. **Profiling**: Identify code-level bottlenecks
4. **Network Analysis**: Packet capture and analysis
5. **Database Explain Plans**: Query performance analysis

## Implementing Monitoring

### Prometheus Configuration

Basic Prometheus scrape configuration:

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'kubernetes-pods'
    kubernetes_sd_configs:
      - role: pod
    relabel_configs:
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: true
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
        action: replace
        target_label: __metrics_path__
        regex: (.+)
      - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
        action: replace
        regex: ([^:]+)(?::\d+)?;(\d+)
        replacement: $1:$2
        target_label: __address__
      - action: labelmap
        regex: __meta_kubernetes_pod_label_(.+)
      - source_labels: [__meta_kubernetes_namespace]
        action: replace
        target_label: kubernetes_namespace
      - source_labels: [__meta_kubernetes_pod_name]
        action: replace
        target_label: kubernetes_pod_name
```

### Alert Rules

Example Prometheus alert rules:

```yaml
groups:
- name: document-service
  rules:
  - alert: HighErrorRate
    expr: sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m])) > 0.05
    for: 5m
    labels:
      severity: critical
      service: document-service
    annotations:
      summary: "High error rate on document service"
      description: "Document service error rate is {{ $value | humanizePercentage }} over the last 5 minutes (> 5%)."
      
  - alert: APIHighLatency
    expr: histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket{handler!="metrics"}[5m])) by (le, service)) > 0.5
    for: 5m
    labels:
      severity: warning
      service: document-service
    annotations:
      summary: "High API latency on document service"
      description: "95th percentile of HTTP request duration is above 500ms: {{ $value }} seconds."
```

### Logging Configuration

Example Logback configuration (Java services):

```xml
<configuration>
  <appender name="JSON" class="ch.qos.logback.core.ConsoleAppender">
    <encoder class="net.logstash.logback.encoder.LogstashEncoder">
      <includeMdc>true</includeMdc>
      <includeContext>false</includeContext>
      <customFields>{"service":"document-service","environment":"${ENV}"}</customFields>
    </encoder>
  </appender>
  
  <root level="INFO">
    <appender-ref ref="JSON" />
  </root>
  
  <logger name="org.dive25.document" level="INFO" />
</configuration>
```

## Monitoring Deployment

The monitoring stack is deployed as follows:

1. **Kubernetes Resources**:
   - Prometheus StatefulSet
   - Alertmanager Deployment
   - Grafana Deployment
   - ELK Stack/Loki for logs
   - Jaeger for tracing

2. **Configuration Management**:
   - Prometheus configuration in ConfigMaps
   - Alert rules in ConfigMaps
   - Dashboards as code (Grafonnet)
   - Secret management for credentials

3. **Persistence**:
   - PersistentVolumes for metrics data
   - PersistentVolumes for log data
   - Regular backups of configuration

### Resource Requirements

Recommended resources:

| Component | CPU (Request/Limit) | Memory (Request/Limit) | Storage |
|-----------|---------------------|------------------------|---------|
| Prometheus | 2/4 CPU cores | 8/16 GB | 100 GB |
| Alertmanager | 0.2/1 CPU cores | 0.5/2 GB | 5 GB |
| Grafana | 0.5/1 CPU cores | 1/2 GB | 10 GB |
| Elasticsearch | 4/8 CPU cores | 16/32 GB | 500 GB |
| Jaeger | 1/2 CPU cores | 2/4 GB | 50 GB |

## Monitoring Security

Security considerations:

1. **Authentication**: Require auth for all monitoring UIs
2. **Authorization**: Role-based access to dashboards
3. **Encryption**: TLS for all monitoring endpoints
4. **Secrets Management**: Secure handling of credentials
5. **Network Segmentation**: Restrict monitoring access

## Related Documentation

- [Performance Optimization](optimization.md)
- [Scalability Guide](../deployment/scalability.md)
- [Security Architecture](../architecture/security.md)
- [Operations Guide](../deployment/operations.md)
- [Kubernetes Deployment](../deployment/kubernetes.md) 