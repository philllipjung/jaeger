# Data Prepper + OTEL Collector Setup

Complete monitoring stack with **dual metrics export** to both Prometheus and OpenSearch.

## Architecture

```
┌─────────────┐     OTLP      ┌──────────────┐
│  Apps       │ ────────────> │ OTEL         │
│ (server1/2) │               │ Collector    │
└─────────────┘               │              │
                               │ HostMetrics  │
                               │ ResourceDet  │
                               │ DockerStats  │
                               └──────┬───────┘
                                      │
                    ┌─────────────────┴─────────────────┐
                    │                                   │
                    ↓                                   ↓
            ┌──────────────┐                   ┌──────────────┐
            │ Prometheus   │                   │ Data Prepper │
            │ :9090        │                   │ :21891       │
            └──────────────┘                   └──────┬───────┘
                                                    │
                                                    ↓
                                              ┌──────────────┐
                                              │ OpenSearch   │
                                              │ :9200        │
                                              └──────────────┘
```

## Features

### Dual Metrics Export
- **Prometheus:** Pre-aggregated metrics via Remote Write + Scraping
- **OpenSearch:** Raw metrics via Data Prepper for long-term storage

### OTEL Collector Components

| Component | Purpose |
|-----------|---------|
| **hostmetrics** | CPU, memory, disk, network metrics |
| **docker_stats** | Container resource usage |
| **otlp** | Application traces, metrics, logs |
| **resourcedetection** | Auto-detect host, cloud metadata |
| **memory_limiter** | Prevent OOM with memory limits |

### Data Prepper Pipelines

| Pipeline | Input | Output |
|----------|-------|--------|
| **metric-pipeline** | OTLP metrics | OpenSearch (otel_metrics) |
| **raw-trace-pipeline** | OTLP traces | OpenSearch (trace-analytics-raw) |
| **service-map-pipeline** | OTLP traces | OpenSearch (trace-analytics-service-map) |
| **logs-pipeline** | OTLP logs | OpenSearch (otel_logs) |

## Quick Start

### Start Monitoring Stack

```bash
cd /root/jaeger/docker-compose/monitor

# Start with Data Prepper
docker-compose -f docker-compose-with-data-prepper.yml up -d
```

### Access Points

| Service | URL | Purpose |
|---------|-----|---------|
| **Grafana** | http://localhost:3001 | Visualization dashboards |
| **Prometheus** | http://localhost:9090 | Metrics query and alerting |
| **OpenSearch Dashboards** | http://localhost:5601 | Logs and traces exploration |
| **Jaeger UI** | http://localhost:16686 | Distributed tracing UI |
| **OTEL Collector** | localhost:8889/metrics | Collector metrics |

## Configuration Files

| File | Description |
|------|-------------|
| `docker-compose-with-data-prepper.yml` | Docker Compose with Data Prepper |
| `otel-collector-config-hybrid.yml` | OTEL Collector config (dual export) |
| `data-prepper-config.yaml` | Data Prepper main config |
| `data-prepper-pipelines.yaml` | Data Prepper pipeline definitions |
| `prometheus-data-prepper.yml` | Prometheus scrape config |

## Port Summary

| Component | Port | Protocol | Description |
|-----------|------|----------|-------------|
| **OTLP (gRPC)** | 4317 | gRPC | OTLP gRPC receiver |
| **OTLP (HTTP)** | 4318 | HTTP | OTLP HTTP receiver |
| **Prometheus** | 9090 | HTTP | Prometheus UI |
| **Grafana** | 3001 | HTTP | Grafana UI |
| **OpenSearch** | 9200 | HTTP | OpenSearch API |
| **OpenSearch Dashboards** | 5601 | HTTP | Data visualization |
| **Data Prepper** | 2021 | HTTP | Data Prepper API |
| **Data Prepper** | 21890 | OTLP | Trace source |
| **Data Prepper** | 21891 | OTLP | Metrics source |
| **Data Prepper** | 4900 | HTTP | Health & metrics |
| **Jaeger UI** | 16686 | HTTP | Jaeger UI |

## Metrics Flow

### Host Metrics Collection

**Source:** OTEL Collector → Host Metrics Receiver

**Collected Metrics:**
```promql
# CPU
system_cpu_time{state="user|system|idle|nice|iowait|irq|softirq|steal"}
system_cpu_load_average{dimension="1|5|15"}
system_cpu_usage

# Memory
system_memory_usage{state="total|used|free|cached|buffer"}
system_memory_utilization

# Disk
system_disk_io_time{device="sda"}
system_disk_operations{direction="read|write",device="sda"}
system_disk_merged{direction="read|write",device="sda"}
system_disk_bytes{direction="read|write",device="sda"}

# Filesystem
system_filesystem_usage{mode="rw",device="/dev/sda1",mountpoint="/"}
system_filesystem_inodes{device="/dev/sda1",mountpoint="/"}
system_filesystem_utilization{device="/dev/sda1",mountpoint="/"}

# Network
system_network_packets{device="eth0",direction="receive|transmit"}
system_network_bytes{device="eth0",direction="receive|transmit"}
system_network_errors{device="eth0",direction="receive|transmit"}
```

**Destination:**
- Prometheus (via Remote Write)
- OpenSearch (via Data Prepper)

### Container Metrics (Docker Stats)

**Collected Metrics:**
```promql
# Container CPU
container_cpu_usage_seconds_total{container_name,namespace}
container_cpu_utilization

# Container Memory
container_memory_usage_bytes{container_name}
container_memory_cache
container_memory_rss
container_memory_swap

# Container Network
container_network_receive_bytes_total{container_name}
container_network_transmit_bytes_total{container_name}

# Container Block I/O
container_block_io_read_bytes_total{container_name}
container_block_io_write_bytes_total{container_name}
```

**Destination:**
- Prometheus (via Remote Write)
- OpenSearch (via Data Prepper)

### Application Metrics

**Source:** Applications send via OTLP

**Example:**
```bash
# Set OTLP endpoint
export OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=http://localhost:4318
export OTEL_EXPORTER_OTLP_METRICS_ENDPOINT=http://localhost:4318
export OTEL_EXPORTER_OTLP_LOGS_ENDPOINT=http://localhost:4318
```

**Destination:**
- Traces: OpenSearch (via Data Prepper)
- Metrics: Prometheus + OpenSearch (dual export)
- Logs: OpenSearch

## Resource Detection

The OTEL Collector's `resourcedetection` processor automatically adds:

### System Attributes
```
host.name: <hostname>
host.type: <os type>
host.arch: <architecture>
os.type: linux/windows/darwin
os.version: <version>
```

### Environment Variables
Set via `OTEL_RESOURCE_ATTRIBUTES`:
```bash
export OTEL_RESOURCE_ATTRIBUTES=\
  service.name=my-service,\
  service.version=1.0.0,\
  deployment.environment=production,\
  cloud.provider=aws,\
  cloud.region=us-west-2
```

### Cloud Detection (Optional)
Enable cloud detectors in `otel-collector-config-hybrid.yml`:
```yaml
processors:
  resourcedetection/cloud:
    detectors: [ec2, gce, azure]
    timeout: 10s
    override: false
```

**Detected Attributes:**
```
cloud.provider: aws/gcp/azure
cloud.account.id: <account>
cloud.region: us-west-2
cloud.availability_zone: us-west-2a
host.id: <instance-id>
```

## Querying Metrics

### Prometheus Queries

**Host Metrics:**
```promql
# CPU utilization
rate(system_cpu_usage{host.name="my-host"}[5m])

# Memory usage
system_memory_usage{state="used",host.name="my-host"}

# Disk I/O
rate(system_disk_bytes{direction="read",device="sda"}[5m])

# Network traffic
rate(system_network_bytes{device="eth0"}[5m])
```

**Container Metrics:**
```promql
# Container CPU usage
rate(container_cpu_usage_seconds_total{container_name="jaeger"}[5m])

# Container memory
container_memory_usage_bytes{container_name="jaeger"}

# Container network rate
rate(container_network_receive_bytes_total{container_name="otel-collector"}[5m])
```

### OpenSearch Queries

**Query via OpenSearch Dashboards:**
1. Navigate to http://localhost:5601
2. Create index pattern: `otel_metrics-*`
3. Query documents

**Query via API:**
```bash
# Search host metrics
curl -X GET "http://localhost:9200/otel_metrics-*/_search?pretty" \
  -H 'Content-Type: application/json' \
  -d '{
    "query": {
      "bool": {
        "must": [
          {"match": {"metricset.name": "hostmetrics"}},
          {"match": {"host.name": "my-host"}}
        ]
      }
    },
    "size": 10
  }'

# Search container metrics
curl -X GET "http://localhost:9200/otel_metrics-*/_search?pretty" \
  -H 'Content-Type: application/json' \
  -d '{
    "query": {
      "match": {"metricset.name": "docker"}}
    },
    "size": 10
  }'
```

## Grafana Dashboards

### Import Dashboards

1. Navigate to http://localhost:3001
2. Go to **+** → **Import**
3. Import dashboard IDs:
   - **Node Exporter Full**: 1860
   - **Docker and system monitoring**: 179
   - **Prometheus Statistics**: 3662

### Data Sources

**Prometheus:**
```
Name: Prometheus
Type: Prometheus
URL: http://prometheus:9090
Access: Server (default)
```

**OpenSearch:**
```
Name: OpenSearch
Type: OpenSearch
URL: http://opensearch:9200
Index: otel_metrics-*
Time field: @timestamp
```

## Troubleshooting

### Issue: Metrics Not Appearing in Prometheus

**Symptoms:**
- No metrics in Prometheus UI
- Remote Write not working

**Diagnosis:**
```bash
# Check OTEL Collector logs
docker logs otel-collector | grep -i "remote\|prometheus"

# Check Prometheus target status
curl -s 'http://localhost:9090/api/v1/targets' | jq '.data.activeTargets[] | {job: .labels.job, health: .health}'

# Check if Remote Write is receiving data
curl -s 'http://localhost:9090/api/v1/query?query=up' | jq '.data.result[] | {metric: .metric.__name__, value: .value[1]}'
```

**Solution:**
1. Verify OTEL Collector `prometheusremotewrite` exporter is configured
2. Check network connectivity: `docker exec otel-collector nc -zv prometheus 9090`
3. Verify Remote Write is enabled in Prometheus

### Issue: Metrics Not Appearing in OpenSearch

**Symptoms:**
- No indices created in OpenSearch
- Data Prepper pipeline not working

**Diagnosis:**
```bash
# Check Data Prepper logs
docker logs data-prepper | grep -i "error"

# Check pipeline status
curl http://localhost:2021/pipelines/metric-pipeline/status

# Check OpenSearch indices
curl http://localhost:9200/_cat/indices?v | grep otel
```

**Solution:**
1. Verify Data Prepper is healthy: `curl http://localhost:4900/health`
2. Check OpenSearch is accessible from Data Prepper
3. Review pipeline configuration in `data-prepper-pipelines.yaml`

### Issue: Host Metrics Not Collected

**Symptoms:**
- `system_cpu_usage` metrics missing
- Only container metrics available

**Diagnosis:**
```bash
# Check if hostmetrics receiver is enabled
docker exec otel-collector cat /etc/otel-collector-config.yml | grep -A5 "hostmetrics"

# Check OTEL Collector metrics
curl http://localhost:8889/metrics | grep system_cpu_usage
```

**Solution:**
1. Verify `hostmetrics` receiver is enabled in config
2. Check OTEL Collector has permissions (running as root)
3. Restart OTEL Collector: `docker-compose restart otel-collector`

### Issue: Docker Stats Not Working

**Symptoms:**
- `container_*` metrics missing
- Docker socket permission errors

**Diagnosis:**
```bash
# Check Docker socket mount
docker inspect otel-collector | grep -A5 "docker.sock"

# Check for permission errors
docker logs otel-collector | grep -i "permission\|docker"
```

**Solution:**
1. Verify Docker socket is mounted: `/var/run/docker.sock:/var/run/docker.sock`
2. Run container as root: `user: "0:0"` already set in compose
3. Restart OTEL Collector

### Issue: Resource Detection Not Working

**Symptoms:**
- `host.name` attribute missing
- Cloud attributes not detected

**Diagnosis:**
```bash
# Check processor configuration
docker exec otel-collector cat /etc/otel-collector-config.yml | grep -A10 "resourcedetection"

# Check metrics for resource attributes
curl http://localhost:8889/metrics | grep host_name
```

**Solution:**
1. Verify `resourcedetection` processor is in pipeline
2. Check detectors list: `[env, system]`
3. Set `OTEL_RESOURCE_ATTRIBUTES` environment variable
4. Restart OTEL Collector

## Performance Tuning

### OTEL Collector

**Batch Size:**
```yaml
processors:
  batch:
    timeout: 5s
    send_batch_size: 10240
    send_batch_max_size: 20480
```

**Memory Limits:**
```yaml
processors:
  memory_limiter:
    check_interval: 1s
    limit_mib: 512
    spike_limit_mib: 128
```

**Collection Intervals:**
```yaml
receivers:
  hostmetrics:
    collection_interval: 10s
  docker_stats:
    collection_interval: 10s
```

### Data Prepper

**Buffer Size:**
```yaml
buffer:
  bounded_blocking:
    buffer_size: 10240
    batch_size: 160
```

**Bulk Settings:**
```yaml
opensearch:
  bulk:
    max-size: 10
    max-docs: 1000
```

### Prometheus

**Remote Write Queue:**
```yaml
remote_write:
  queue_config:
    capacity: 10000
    max_shards: 50
    batch_send_deadline: 5s
```

## Advanced Configuration

### Add Prometheus Scrape Targets

Edit `prometheus-data-prepper.yml`:
```yaml
scrape_configs:
  - job_name: 'my-service'
    static_configs:
      - targets: ['my-service:9090']
    scrape_interval: 15s
```

### Add Custom Processors

**Metrics Transform:**
```yaml
processors:
  metrics_transform:
    transforms:
      - include: system_cpu_usage
        match_type: regexp
        action: update
        operations:
          - action: add_label
            label: cluster
            value: "production"
```

### Add Custom Exporters

**OpenSearch with Authentication:**
```yaml
exporters:
  opensearch/custom:
    http:
      endpoint: https://opensearch:9200
      tls:
        insecure: false
        cert_file: /path/to/cert.pem
    username: ${env:OPENSEARCH_USERNAME}
    password: ${env:OPENSEARCH_PASSWORD}
```

## Migration Guide

### From Standard OTEL Collector to Data Prepper

1. **Update docker-compose:**
   ```yaml
   # Add Data Prepper service
   data-prepper:
     image: opensearchproject/data-prepper:latest
     volumes:
       - ./data-prepper-pipelines.yaml:/usr/share/data-prepper/pipelines/data-prepper-pipelines.yaml
       - ./data-prepper-config.yaml:/usr/share/data-prepper/config/data-prepper-config.yaml
     ports:
       - "21891:21891"
   ```

2. **Update OTEL Collector exporters:**
   ```yaml
   exporters:
     otlp/metrics:
       endpoint: data-prepper:21891
   ```

3. **Restart services:**
   ```bash
   docker-compose -f docker-compose-with-data-prepper.yml up -d
   ```

## References

- [Data Prepper Documentation](https://opensearch.org/docs/latest/data-prepper/)
- [OpenTelemetry Collector](https://opentelemetry.io/docs/collector/)
- [Prometheus Remote Write](https://prometheus.io/docs/prometheus/latest/configuration/configuration/#remote_write)
- [Grafana Dashboards](https://grafana.com/grafana/dashboards/)
