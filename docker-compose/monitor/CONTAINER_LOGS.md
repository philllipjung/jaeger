# Container Logs Collection with OTEL Collector

## Overview

Container logs are now being collected automatically from all Docker containers and sent to OpenSearch for storage and analysis.

## Architecture

```
┌─────────────────┐     ┌──────────────┐     ┌────────────┐
│  Docker         │────▶│   OTEL       │────▶│ OpenSearch │
│  Containers     │     │   Collector  │     │            │
└─────────────────┘     └──────────────┘     └────────────┘
                              │
                              ▼
                        ┌──────────────┐
                        │   OpenSearch  │
                        │   Dashboards  │
                        └──────────────┘
```

## Log Sources

### 1. Docker Container Logs (`filelog/docker`)
- **Path**: `/var/lib/docker/containers/*/*.log`
- **Format**: JSON (Docker's native format)
- **Content**: stdout/stderr from all containers
- **Label**: `log_type: docker`

### 2. Kubernetes Container Logs (`filelog/containers`)
- **Path**: `/var/log/containers/*.log`
- **Format**: JSON with Kubernetes metadata
- **Content**: Container logs with K8s enrichment
- **Label**: `log_type: container`

### 3. Application Logs (OTLP)
- **Protocol**: OTLP (gRPC/HTTP)
- **Endpoint**: `0.0.0.0:4317` (gRPC) or `0.0.0.0:4318` (HTTP)
- **Content**: Structured logs from applications

## Configuration

### OTEL Collector Receivers

```yaml
receivers:
  # Docker container stdout/stderr logs
  filelog/docker:
    include:
      - /var/lib/docker/containers/*/*.log
    include_file_name: false
    include_file_path: true
    start_at: end
    poll_interval: 1s
    operators:
      - type: json_parser
        parse_from: body
        parse_to: attributes
      - type: move
        from: attributes.log
        to: body
      - type: move
        from: attributes.time
        to: attributes.timestamp
      - type: move
        from: attributes.stream
        to: attributes.log.stream
    attributes:
      log_type: docker

  # Container logs (Kubernetes format)
  filelog/containers:
    include:
      - /var/log/containers/*.log
    include_file_name: false
    include_file_path: true
    start_at: end
    operators:
      - type: json_parser
        parse_from: body
        parse_to: attributes
      - type: regex_parser
        regex: '^(?P<stream>[^ ]+) (?P<timestamp>[^ ]+) (?P<log>.+)$'
        parse_from: attributes.log
        parse_to: body
      - type: move
        from: attributes.stream
        to: attributes.log.stream
      - type: move
        from: attributes.log.timestamp
        to: attributes.log.timestamp
      - type: move
        from: attributes.log.log
        to: body
    attributes:
      log_type: container
```

### Logs Pipeline

```yaml
service:
  pipelines:
    logs:
      receivers: [filelog/containers, filelog/docker, otlp]
      processors: [resourcedetection/env, resource/add_custom_labels, batch]
      exporters: [opensearch]
```

### Docker Compose Volumes

```yaml
otel-collector:
  volumes:
    - ./otel-collector-connectors.yml:/etc/otel-collector.yml
    - /var/run/docker.sock:/var/run/docker.sock:ro
    - /var/log/containers:/var/log/containers:ro
    - /var/lib/docker/containers:/var/lib/docker/containers:ro
    - /var/log/journal:/var/log/journal:ro
    - /run/log/journal:/run/log/journal:ro
```

## Log Fields

All collected logs include these resource attributes:

| Field | Description | Example |
|-------|-------------|---------|
| `log_type` | Type of log source | docker, container, otlp |
| `host_name` | Host/container name | e3b7139ca07a |
| `os_type` | Operating system | linux |
| `cluster` | Cluster identifier | monitoring-stack |
| `datacenter` | Data center location | us-west-1 |
| `region` | Geographic region | us-west |
| `team` | Team ownership | platform |
| `environment` | Environment | production |
| `log.file.path` | Full path to log file | /var/lib/docker/containers/... |
| `timestamp` | Log timestamp | 2026-02-21T00:44:32.290Z |
| `body` | Log message content | Actual log text |

### Docker-Specific Fields

| Field | Description | Example |
|-------|-------------|---------|
| `log.stream` | stdout or stderr | stdout, stderr |
| `attributes.time` | Original Docker timestamp | 2026-02-21T00:44:32.290Z |

### Application-Specific Fields (via OTLP)

| Field | Description | Example |
|-------|-------------|---------|
| `service.name` | Application service name | customer, frontend |
| `service.version` | Service version | 0.0.1-SNAPSHOT |
| `process.pid` | Process ID | 219022 |
| `process.executable.path` | Executable path | /usr/lib/jvm/.../java |

## OpenSearch Indices

### Log Indices

| Index | Description | Documents |
|-------|-------------|-----------|
| `ss4o_logs-default-namespace` | Default logs from Data Prepper | 67+ |
| `otel-v1-logs-*` | OpenTelemetry logs (if enabled) | - |

### Viewing Logs in OpenSearch

```bash
# Count logs by type
curl -s "http://localhost:9200/ss4o_logs-default-namespace/_search?pretty" -H 'Content-Type: application/json' -d'
{
  "size": 0,
  "aggs": {
    "log_types": {
      "terms": {
        "field": "log_type"
      }
    }
  }
}'

# Get recent logs
curl -s "http://localhost:9200/ss4o_logs-default-namespace/_search?pretty&size=10&sort=@timestamp:desc"

# Filter by log type
curl -s "http://localhost:9200/ss4o_logs-default-namespace/_search?pretty" -H 'Content-Type: application/json' -d'
{
  "query": {
    "term": {
      "log_type": "docker"
    }
  }
}'
```

## Viewing Logs in OpenSearch Dashboards

1. **Access Dashboards**: http://localhost:5601
2. **Navigate**: Discover > Select Index Pattern
3. **Create Index Pattern** (if needed):
   - Pattern: `ss4o_logs-*`
   - Time field: `@timestamp`
4. **View Logs**: Filter by `log_type`, `service.name`, etc.

## Log Enrichment

All logs are automatically enriched with:

1. **Resource Detection**: Host, OS, platform metadata
2. **Custom Labels**: Cluster, datacenter, team, SLA level
3. **Container Metadata**: Container ID, name, image
4. **Application Context**: Service name, version, process info

## Example Queries

### OpenSearch Dashboards Queries (Lucene)

```lucene
# All Docker container logs
log_type: docker

# Logs from specific container
log.file.path: "*otel-collector*"

# Error logs
body: *error* OR body: *Error* OR body: *ERROR*

# Logs by service
service_name: customer

# Logs by timestamp range
@timestamp: [now-1h TO now]

# Combine filters
log_type: docker AND (body: *error* OR body: *Error*)
```

### OpenSearch SQL

```sql
-- Count logs by type
SELECT log_type, COUNT(*) as count 
FROM ss4o_logs-default-namespace 
GROUP BY log_type;

-- Recent logs with service info
SELECT @timestamp, service_name, body, log_type 
FROM ss4o_logs-default-namespace 
ORDER BY @timestamp DESC 
LIMIT 20;

-- Error logs analysis
SELECT service_name, COUNT(*) as error_count 
FROM ss4o_logs-default-namespace 
WHERE body LIKE '%error%' 
GROUP BY service_name 
ORDER BY error_count DESC;
```

## Troubleshooting

### Issue: No logs appearing

**Check file permissions:**
```bash
# Verify OTEL Collector can access log files
docker exec otel-collector ls -la /var/lib/docker/containers/
docker exec otel-collector ls -la /var/log/containers/
```

**Check OTEL Collector logs:**
```bash
docker logs otel-collector | grep -i "filelog"
```

**Verify logs exist:**
```bash
ls -la /var/lib/docker/containers/*/*.log
ls -la /var/log/containers/*.log
```

### Issue: Logs not reaching OpenSearch

**Check OpenSearch connection:**
```bash
docker exec otel-collector curl -s http://opensearch:9200/_cluster/health
```

**Verify pipeline is running:**
```bash
docker logs otel-collector | grep "pipeline.*logs"
```

**Check OpenSearch indices:**
```bash
curl -s "http://localhost:9200/_cat/indices?v"
```

### Issue: High CPU usage

**Adjust poll interval:**
```yaml
filelog/docker:
  poll_interval: 5s  # Increase from 1s to 5s
```

**Filter logs:**
```yaml
filelog/docker:
  exclude:
    - /var/lib/docker/containers/*/otel-collector*.log
```

## Performance Considerations

1. **Poll Interval**: Default is 1s. Increase for high-volume logging.
2. **Start Position**: `end` starts from current, `beginning` reads all history.
3. **File Rotation**: Automatically handled by filelog receiver.
4. **Batch Size**: Configured via `batch` processor.
5. **Network**: Logs sent to OpenSearch in batches.

## Next Steps

1. **Create Index Patterns**: In OpenSearch Dashboards
2. **Set Up Dashboards**: Create visualizations for log analysis
3. **Configure Alerts**: Set up alerts for error patterns
4. **Log Retention**: Configure ILM (Index Lifecycle Management)
5. **Optimize Parsing**: Add custom operators for specific log formats

## Configuration Files

- **OTEL Collector**: `/root/jaeger/docker-compose/monitor/otel-collector-connectors.yml`
- **Docker Compose**: `/root/jaeger/docker-compose/monitor/docker-compose-final.yml`
- **Documentation**: `/root/jaeger/docker-compose/monitor/CONTAINER_LOGS.md`

## References

- [OpenTelemetry Filelog Receiver](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/receiver/filelogreceiver)
- [OpenSearch Dashboards](https://opensearch.org/docs/latest/dashboards/index/)
- [Docker Logging](https://docs.docker.com/config/containers/logging/)
