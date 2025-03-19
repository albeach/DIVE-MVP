#!/bin/bash
set -e

# Wait for Grafana to start
echo "Waiting for Grafana to start..."
until $(curl --output /dev/null --silent --head --fail http://grafana:3000); do
  printf '.'
  sleep 5
done

echo "Grafana is up. Setting up dashboards..."

# Create a System Overview dashboard
echo "Creating System Overview dashboard..."
curl -X POST -H "Content-Type: application/json" -d '{
  "dashboard": {
    "id": null,
    "title": "System Overview",
    "panels": [
      {
        "type": "timeseries",
        "title": "CPU Usage",
        "gridPos": {"x":0,"y":0,"w":12,"h":8},
        "id": 1,
        "targets": [
          {
            "refId": "A",
            "expr": "1 - avg(rate(node_cpu_seconds_total{mode=\"idle\"}[1m]))",
            "legendFormat": "CPU Usage"
          }
        ]
      },
      {
        "type": "timeseries",
        "title": "Memory Usage",
        "gridPos": {"x":12,"y":0,"w":12,"h":8},
        "id": 2,
        "targets": [
          {
            "refId": "A",
            "expr": "node_memory_MemTotal_bytes - node_memory_MemFree_bytes - node_memory_Buffers_bytes - node_memory_Cached_bytes",
            "legendFormat": "Memory Usage"
          }
        ]
      },
      {
        "type": "stat",
        "title": "Uptime",
        "gridPos": {"x":0,"y":8,"w":6,"h":6},
        "id": 3,
        "targets": [
          {
            "refId": "A",
            "expr": "node_time_seconds - node_boot_time_seconds",
            "legendFormat": "Uptime"
          }
        ]
      }
    ],
    "schemaVersion": 36,
    "version": 0,
    "refresh": "10s"
  },
  "overwrite": true
}' -u admin:admin http://grafana:3000/api/dashboards/db

# Create a Network Traffic dashboard
echo "Creating Network Traffic dashboard..."
curl -X POST -H "Content-Type: application/json" -d '{
  "dashboard": {
    "id": null,
    "title": "Network Traffic",
    "panels": [
      {
        "type": "timeseries",
        "title": "Network Receive",
        "gridPos": {"x":0,"y":0,"w":12,"h":8},
        "id": 1,
        "targets": [
          {
            "refId": "A",
            "expr": "rate(node_network_receive_bytes_total[1m])",
            "legendFormat": "{{device}}"
          }
        ]
      },
      {
        "type": "timeseries",
        "title": "Network Transmit",
        "gridPos": {"x":12,"y":0,"w":12,"h":8},
        "id": 2,
        "targets": [
          {
            "refId": "A",
            "expr": "rate(node_network_transmit_bytes_total[1m])",
            "legendFormat": "{{device}}"
          }
        ]
      }
    ],
    "schemaVersion": 36,
    "version": 0,
    "refresh": "10s"
  },
  "overwrite": true
}' -u admin:admin http://grafana:3000/api/dashboards/db

# Create API Monitoring dashboard
echo "Creating API Monitoring dashboard..."
curl -X POST -H "Content-Type: application/json" -d '{
  "dashboard": {
    "id": null,
    "title": "API Monitoring",
    "panels": [
      {
        "type": "timeseries",
        "title": "Request Rate",
        "gridPos": {"x":0,"y":0,"w":12,"h":8},
        "id": 1,
        "targets": [
          {
            "refId": "A",
            "expr": "sum(rate(http_requests_total[5m])) by (handler)",
            "legendFormat": "{{handler}}"
          }
        ]
      },
      {
        "type": "timeseries",
        "title": "Response Time",
        "gridPos": {"x":12,"y":0,"w":12,"h":8},
        "id": 2,
        "targets": [
          {
            "refId": "A",
            "expr": "histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le, handler))",
            "legendFormat": "{{handler}}"
          }
        ]
      },
      {
        "type": "timeseries",
        "title": "Error Rate",
        "gridPos": {"x":0,"y":8,"w":24,"h":8},
        "id": 3,
        "targets": [
          {
            "refId": "A",
            "expr": "sum(rate(http_requests_total{status=~\"5..\"}[5m])) by (handler) / sum(rate(http_requests_total[5m])) by (handler)",
            "legendFormat": "{{handler}}"
          }
        ]
      }
    ],
    "schemaVersion": 36,
    "version": 0,
    "refresh": "10s"
  },
  "overwrite": true
}' -u admin:admin http://grafana:3000/api/dashboards/db

# Create Logs Explorer Dashboard
echo "Creating Logs Explorer Dashboard..."
curl -X POST -H "Content-Type: application/json" -d '{
  "dashboard": {
    "id": null,
    "title": "Logs Explorer",
    "panels": [
      {
        "gridPos": {
          "h": 9,
          "w": 24,
          "x": 0,
          "y": 0
        },
        "id": 1,
        "options": {
          "showLabels": false,
          "showTime": true,
          "sortOrder": "Descending",
          "wrapLogMessage": true,
          "dedupStrategy": "none",
          "enableLogDetails": true
        },
        "pluginVersion": "8.3.0",
        "targets": [
          {
            "expr": "{job=\"docker\"} |= \"$search\"",
            "refId": "A",
            "datasource": "Loki"
          }
        ],
        "title": "All Container Logs",
        "type": "logs"
      },
      {
        "gridPos": {
          "h": 15,
          "w": 24,
          "x": 0,
          "y": 9
        },
        "id": 2,
        "options": {
          "showLabels": false,
          "showTime": true,
          "sortOrder": "Descending",
          "wrapLogMessage": true,
          "dedupStrategy": "none",
          "enableLogDetails": true
        },
        "pluginVersion": "8.3.0",
        "targets": [
          {
            "expr": "{service=\"$service\"} |= \"$search\"",
            "refId": "A",
            "datasource": "Loki"
          }
        ],
        "title": "Selected Service Logs",
        "type": "logs"
      }
    ],
    "schemaVersion": 36,
    "templating": {
      "list": [
        {
          "allValue": "",
          "current": {
            "selected": false,
            "text": "All",
            "value": "$__all"
          },
          "datasource": "Loki",
          "definition": "label_values(service)",
          "hide": 0,
          "includeAll": true,
          "label": "Service",
          "multi": false,
          "name": "service",
          "options": [],
          "query": "label_values(service)",
          "refresh": 1,
          "regex": "",
          "skipUrlSync": false,
          "sort": 1,
          "type": "query"
        },
        {
          "current": {
            "selected": false,
            "text": "",
            "value": ""
          },
          "hide": 0,
          "label": "Search",
          "name": "search",
          "options": [
            {
              "selected": true,
              "text": "",
              "value": ""
            }
          ],
          "query": "",
          "skipUrlSync": false,
          "type": "textbox"
        }
      ]
    },
    "time": {
      "from": "now-1h",
      "to": "now"
    },
    "version": 0,
    "refresh": "10s"
  },
  "overwrite": true
}' -u admin:admin http://grafana:3000/api/dashboards/db

# Add Loki datasource if not exists
echo "Adding Loki datasource..."
curl -X POST -H "Content-Type: application/json" -d '{
  "name": "Loki",
  "type": "loki",
  "url": "http://loki:3100",
  "access": "proxy",
  "basicAuth": false,
  "isDefault": false,
  "jsonData": {
    "maxLines": 1000
  }
}' -u admin:admin http://grafana:3000/api/datasources || true

echo "Setup complete!" 