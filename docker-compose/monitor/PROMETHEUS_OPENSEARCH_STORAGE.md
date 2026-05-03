# Prometheus + OpenSearch Hybrid Storage Configuration

This document describes the hybrid storage configuration using **Prometheus** for pre-aggregated metrics and **OpenSearch** for traces and on-demand metrics.

## Overview

This deployment uses a **hybrid architecture** combining:
- **Prometheus:** Pre-aggregated metrics from OpenTelemetry Collector (SpanMetrics, Service Graph)
- **OpenSearch:** Trace storage and on-demand SPM metrics (Option 2)
- **OpenTelemetry Collector:** Trace processing with connectors (SpanMetrics, Service Graph)

### Architecture

```
┌─────────────┐         OTLP         ┌──────────────┐      OTLP      ┌─────────┐
│  Apps       │ ────────────────────> │ OTEL         │ ─────────────> │ Jaeger  │
│ (server1/2) │                       │ Collector    │               │ (v2)    │
└─────────────┘                       │              │               └────┬────┘
                                       │ SpanMetrics  │                    │
                                       │ ServiceGraph │                    │
                                       └──────┬───────┘                    │
                                              │                            │
                   Metrics                   │                            │
                (Prometheus format)          │                            │
                                              ↓                            ↓
                                       ┌──────────────┐             ┌─────────────┐
                                       │ Prometheus   │             │ OpenSearch  │
                                       │ :9090        │             │ :9200       │
                                       └──────────────┘             └─────────────┘
                                              ↑                            │
                                              │                            │
                                              └───────────┬────────────────┘
                                                          │
                                                    ┌─────┴──────┐
                                                    │ Jaeger UI  │
                                                    │ :16686     │
                                                    └────────────┘
```

## Data Flow

### Trace Flow
1. Applications send traces to **OTEL Collector** (port 4318)
2. OTEL Collector processes traces through:
   - **SpanMetrics Connector:** Generates RED metrics per span
   - **ServiceGraph Connector:** Generates service dependency metrics
3. OTEL Collector forwards traces to **Jaeger** (OTLP gRPC port 4317)
4. Jaeger stores traces in **OpenSearch**

### Metrics Flow (Two Paths)

**Path 1: Pre-aggregated Metrics (Prometheus)**
1. OTEL Collector computes metrics from traces
2. Metrics exported to Prometheus endpoint (port 8889)
3. Prometheus scrapes metrics every 5 seconds
4. Available in Prometheus UI (port 9090)

**Path 2: On-Demand Metrics (OpenSearch)**
1. Jaeger computes metrics from OpenSearch when queried
2. Metrics computed on-the-fly via Jaeger UI Monitor tab
3. No pre-aggregation delay

## Prometheus Configuration

### Docker Service

**File:** `docker-compose-opensearch.yml`

```yaml
prometheus:
  networks:
    - backend
  image: prom/prometheus:v3.9.1@sha256:1f0f50f06acaceb0f5670d2c8a658a599affe7b0d8e78b898c1035653849a702
  volumes:
    - "./prometheus.yml:/etc/prometheus/prometheus.yml"
  ports:
    - "9090:9090"
```

### Scrape Configuration

**File:** `prometheus.yml`

```yaml
global:
  scrape_interval: 5s
  evaluation_interval: 5s

scrape_configs:
  # Jaeger Collector metrics (if using Jaeger spanmetrics)
  - job_name: aggregated-trace-metrics
    static_configs:
    - targets: ['spm_metrics_source:8888']

  # Jaeger internal metrics
  - job_name: jaeger-collector-metrics
    static_configs:
    - targets: ['spm_metrics_source:8888']

  # OTEL Collector metrics (SpanMetrics + ServiceGraph)
  - job_name: otel-collector
    static_configs:
    - targets: ['otel-collector:8889']
```

### Available Metrics

| Metric | Type | Labels | Description |
|--------|------|--------|-------------|
| **SpanMetrics** | | | |
| `traces_span_metrics_calls_total` | Counter | service_name, span_name, span_kind, status_code | Total span count |
| `traces_span_metrics_duration_milliseconds` | Histogram | service_name, span_name, span_kind | Span duration |
| **ServiceGraph** | | | |
| `traces_service_graph_request_total` | Counter | client, server, connection_type, failed, virtual_node | Total requests between services |
| `traces_service_graph_request_failed_total` | Counter | client, server, connection_type, failed | Failed requests |
| `traces_service_graph_request_server_seconds` | Histogram | client, server, connection_type, failed | Server-side latency |
| `traces_service_graph_request_client_seconds` | Histogram | client, server, connection_type, failed | Client-side latency |

### Connection Types

- **Unset:** Direct HTTP/gRPC calls between services
- `messaging_system`: Kafka messaging
- `virtual_node`: Uninstrumented services (databases, caches)

### Query Examples

**PromQL Queries:**

```promql
# All service graph edges
traces_service_graph_request_total

# Server1 to Server2 calls
traces_service_graph_request_total{client="server1", server="server2"}

# Request rate (5min window)
rate(traces_service_graph_request_total[5m])

# Error rate
rate(traces_service_graph_request_failed_total[5m]) / rate(traces_service_graph_request_total[5m])

# P95 latency (server-side)
histogram_quantile(0.95, rate(traces_service_graph_request_server_seconds_bucket[5m]))

# P95 latency by service pair
histogram_quantile(0.95, sum(rate(traces_service_graph_request_server_seconds_bucket[5m])) by (le, client, server))

# Span rate by service
sum(rate(traces_span_metrics_calls_total[5m])) by (service_name)

# Error spans
traces_span_metrics_calls_total{status_code="ERROR"}
```

## OpenTelemetry Collector Configuration

### Docker Service

```yaml
otel-collector:
  image: otel/opentelemetry-collector-contrib:0.119.0
  networks:
    - backend
  volumes:
    - "./otel-collector-config-connector.yml:/etc/otelcol-contrib/config.yaml"
  command: [--config=/etc/otelcol-contrib/config.yaml]
  ports:
    - "4318:4318" # OTLP HTTP
    - "4319:4319" # OTLP HTTP (alternative)
  depends_on:
    - jaeger
```

### Configuration

**File:** `otel-collector-config-connector.yml`

```yaml
receivers:
  otlp:
    protocols:
      grpc:
      http:
        endpoint: "0.0.0.0:4318"

exporters:
  prometheus:
    endpoint: "0.0.0.0:8889"

  otlp:
    endpoint: jaeger:4317
    tls:
      insecure: true

connectors:
  spanmetrics:
    metrics_flush_interval: 60s

  servicegraph:
    latency_histogram_buckets: [100ms, 250ms, 1s, 5s, 10s]
    store:
      ttl: 60s
      max_items: 10000
    virtual_node_peer_attributes:
      - peer.service
      - db.name
      - db.system
      - messaging.system
      - messaging.destination
    virtual_node_extra_label: true
    metrics_flush_interval: 60s

processors:
  batch:

service:
  telemetry:
    logs:
      level: debug
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [spanmetrics, servicegraph, otlp]

    metrics/spanmetrics:
      receivers: [spanmetrics]
      exporters: [prometheus]

    metrics/servicegraph:
      receivers: [servicegraph]
      exporters: [prometheus]
```

### Connector Settings

| Setting | Value | Purpose |
|---------|-------|---------|
| **metrics_flush_interval** | 60s | How often to emit metrics |
| **store.ttl** | 60s | Time to wait for paired spans |
| **store.max_items** | 10000 | Maximum unpaired spans to keep |
| **latency_histogram_buckets** | [100ms, 250ms, 1s, 5s, 10s] | Latency distribution buckets |

### Virtual Node Configuration

Uninstrumented services (databases, caches) appear as virtual nodes:

```yaml
virtual_node_peer_attributes:
  - peer.service      # Peer service name
  - db.name          # Database name
  - db.system        # Database type (mysql, redis, etc.)
  - messaging.system # Messaging system (kafka, rabbitmq, etc.)
  - messaging.destination # Queue/topic name
```

## Jaeger Configuration

### Docker Service

```yaml
jaeger:
  networks:
    backend:
      aliases: [ spm_metrics_source ]  # Alias for Prometheus scraping
  image: jaegertracing/jaeger:${JAEGER_VERSION:-latest}
  volumes:
    - "./jaeger-ui.json:/etc/jaeger/jaeger-ui.json"
    - "../../cmd/jaeger/config-spm-opensearch.yaml:/etc/jaeger/config.yml"
  command: ["--config", "/etc/jaeger/config.yml"]
  ports:
    - "16686:16686" # Jaeger UI
    - "4317:4317"   # OTLP gRPC (from OTEL Collector)
    - "8888:8888"   # Prometheus metrics endpoint
  depends_on:
    opensearch:
      condition: service_healthy
```

### Configuration

**File:** `config-spm-opensearch.yaml`

```yaml
service:
  extensions: [jaeger_storage, jaeger_query]
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [jaeger_storage_exporter]
  telemetry:
    resource:
      service.name: jaeger
    metrics:
      level: detailed
      readers:
        - pull:
            exporter:
              prometheus:
                host: 0.0.0.0
                port: 8888
    logs:
      level: DEBUG

extensions:
  jaeger_query:
    storage:
      traces: opensearch_trace_storage
      metrics: opensearch_metrics_storage
  jaeger_storage:
    backends:
      opensearch_trace_storage:
        opensearch:
          server_urls:
            - http://opensearch:9200
    metric_backends:
      opensearch_metrics_storage:
        opensearch:
          server_urls:
            - http://opensearch:9200

receivers:
  otlp:
    protocols:
      grpc:
        endpoint: "0.0.0.0:4317"
      http:
        endpoint: "0.0.0.0:4318"

processors:
  batch:

exporters:
  jaeger_storage_exporter:
    trace_storage: opensearch_trace_storage
```

## Port Summary

| Service | Port | Purpose |
|---------|------|---------|
| **Applications** | | |
| Server1 | 8081 | REST API |
| Server2 | 8082 | REST API |
| Server2 | 9094 | gRPC ML Classification |
| React Client | 5173 | Frontend |
| Kafka | 9092 | Message Broker |
| **Monitoring Stack** | | |
| OTEL Collector | 4318 | OTLP HTTP receiver |
| OTEL Collector | 4319 | OTLP HTTP (alternative) |
| OTEL Collector | 8889 | Prometheus metrics |
| Jaeger UI | 16686 | Web UI |
| Jaeger OTLP | 4317 | OTLP gRPC receiver |
| Jaeger Metrics | 8888 | Prometheus metrics |
| Prometheus | 9090 | Web UI |
| OpenSearch | 9200 | HTTP API |
| OpenSearch Dashboards | 5601 | Web UI |

## Comparison: Prometheus vs OpenSearch Metrics

| Aspect | Prometheus (Pre-aggregated) | OpenSearch (On-Demand) |
|--------|----------------------------|------------------------|
| **Computation** | Pre-computed by OTEL Collector | Computed on-the-fly |
| **Latency** | ~60s flush interval | ~5-10s (after trace indexing) |
| **Storage** | Prometheus TSDB | OpenSearch indices |
| **Query** | PromQL (Prometheus UI) | Jaeger API / UI |
| **Retention** | Configured in Prometheus | Same as traces |
| **Metrics** | SpanMetrics + ServiceGraph | RED metrics (SPM) |
| **Use Case** | Real-time alerting, dashboards | Ad-hoc analysis, trend analysis |

## Usage Examples

### Querying Prometheus Metrics

**Via Prometheus UI:**
1. Navigate to http://localhost:9090
2. Enter PromQL query
3. View results in table or graph

**Via HTTP API:**
```bash
# Query metric
curl -s 'http://localhost:9090/api/v1/query?query=traces_service_graph_request_total'

# Query range
curl -s 'http://localhost:9090/api/v1/query_range?query=rate(traces_service_graph_request_total[5m])&start=1739990400&end=1739994000&step=15'
```

### Querying OpenSearch Metrics (SPM)

**Via Jaeger UI:**
1. Navigate to http://localhost:16686
2. Click **Monitor** tab
3. Select services and operations
4. View RED metrics

**Via HTTP API:**
```bash
# Latency metrics
curl "http://localhost:16686/api/metrics/latencies?service=server1&quantile=0.95"

# Call metrics
curl "http://localhost:16686/api/metrics/calls?service=server1"

# Error metrics
curl "http://localhost:16686/api/metrics/errors?service=server1"
```

### Querying Traces

**Via Jaeger UI:**
1. Navigate to http://localhost:16686
2. Search by service, operation, tags
3. Click on trace to view timeline

**Via HTTP API:**
```bash
# Search traces
curl "http://localhost:16686/api/traces?service=server1&limit=20"

# Get specific trace
curl "http://localhost:16686/api/traces/{trace-id}"
```

## Generating Test Traces

### Using tracegen (via OTEL Collector)

```bash
docker run --network monitor_backend --rm \
  jaegertracing/jaeger-tracegen:latest \
  -trace-exporter otlp-http \
  -otel-exporter-otlp-endpoint http://otel-collector:4318/v1/traces \
  -traces 10
```

### Using tracegen (direct to Jaeger)

```bash
docker run --network monitor_backend --rm \
  jaegertracing/jaeger-tracegen:latest \
  -trace-exporter otlp-http \
  -otel-exporter-otlp-endpoint http://jaeger:4318/v1/traces \
  -duration 10s
```

### From Applications

Applications send traces to OTEL Collector:

```bash
# Set environment variable
export OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=http://localhost:4318/v1/traces

# Or for Java applications
java -javaagent:opentelemetry-javaagent.jar \
     -Dotel.exporter.otlp.endpoint=http://localhost:4318/v1/traces \
     -jar application.jar
```

## Troubleshooting

### Issue: Service Graph Metrics Not Appearing

**Symptoms:**
- `traces_service_graph_request_total` shows no data
- Service Graph connector logs show "edge completed" but no metrics

**Root Cause:**
Prometheus not scraping OTEL collector's metrics endpoint.

**Solution:**
Check Prometheus targets:
```bash
curl -s 'http://localhost:9090/api/v1/targets' | jq '.data.activeTargets[] | {scrapeUrl, health}'
```

Verify scrape configuration in `prometheus.yml` includes:
```yaml
- job_name: otel-collector
  static_configs:
  - targets: ['otel-collector:8889']
```

### Issue: Metrics Take 60 Seconds to Appear

**Symptoms:**
- Generate traces but metrics don't appear immediately in Prometheus

**Root Cause:**
Service Graph Connector has `metrics_flush_interval: 60s`.

**Solution:**
Wait at least 60 seconds after generating traces before querying Prometheus.

### Issue: No Traces in Jaeger UI

**Symptoms:**
- OTEL Collector receives traces
- Jaeger UI shows no traces

**Root Cause:**
OTEL Collector not forwarding traces to Jaeger.

**Solution:**
Check OTEL Collector logs:
```bash
docker logs monitor_otel-collector_1 | grep -i "exporting\|jaeger"
```

Verify connection to Jaeger:
```bash
docker exec monitor_otel-collector_1 nc -zv jaeger 4317
```

### Issue: Prometheus Scrape Failing

**Symptoms:**
- Prometheus target shows "down" status

**Root Cause:**
Port conflict or service not ready.

**Solution:**
Check service status:
```bash
docker ps --filter "name=monitor_" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

Check network connectivity:
```bash
docker exec monitor_prometheus_1 nc -zv otel-collector 8889
docker exec monitor_prometheus_1 nc -zv spm_metrics_source 8888
```

### Issue: Metrics Show NaN

**Symptoms:**
- SPM API returns `"doubleValue": "NaN"`

**Root Cause:**
Insufficient trace data in time range or no matching traces.

**Solution:**
1. Generate more traces
2. Increase lookback period
3. Verify traces are indexed:
   ```bash
   curl http://localhost:9200/_cat/indices?v | grep jaeger
   ```

## Performance Tuning

### OTEL Collector

**Batch Size:**
```yaml
processors:
  batch:
    timeout: 5s
    send_batch_size: 10000
    send_batch_max_size: 20000
```

**Memory:**
```yaml
otel-collector:
  environment:
    - GOMEMLIMIT=512MiB
  deploy:
    resources:
      limits:
        memory: 512M
```

### Prometheus

**Retention:**
```yaml
prometheus:
  command:
    - '--storage.tsdb.retention.time=30d'
```

**Scrape Interval:**
```yaml
global:
  scrape_interval: 15s  # Default: 15s (current: 5s for faster feedback)
```

### Jaeger

**Index Refresh Interval:**
```yaml
opensearch_trace_storage:
  opensearch:
    server_urls:
      - http://opensearch:9200
    refresh_interval: 30s  # Default: 1s
```

## Migration Guide

### From Option 1 (Prometheus Only) to Hybrid

**Current setup:**
- Prometheus for metrics
- OpenSearch for traces
- Jaeger with SpanMetrics connector

**To migrate:**

1. Add OTEL Collector to docker-compose:
   ```yaml
   otel-collector:
     image: otel/opentelemetry-collector-contrib:0.119.0
     # ... (see full config above)
   ```

2. Update application trace endpoints:
   ```bash
   # From: Jaeger directly
   OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=http://jaeger:4318/v1/traces

   # To: OTEL Collector
   OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=http://otel-collector:4318/v1/traces
   ```

3. Update Prometheus scrape config:
   ```yaml
   - job_name: otel-collector
     static_configs:
     - targets: ['otel-collector:8889']
   ```

### From Option 2 (OpenSearch Only) to Hybrid

**Current setup:**
- OpenSearch for traces and metrics
- Applications send traces directly to Jaeger

**To migrate:**

1. Add OTEL Collector and Prometheus to docker-compose

2. Add Prometheus scrape configuration

3. Update application trace endpoints to send to OTEL Collector

4. (Optional) Keep Jaeger's on-demand metrics for ad-hoc analysis

## Reference Links

- [Prometheus Documentation](https://prometheus.io/docs/)
- [OpenTelemetry Collector](https://opentelemetry.io/docs/collector/)
- [SpanMetrics Connector](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/connector/spanmetricsconnector)
- [ServiceGraph Connector](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/connector/servicegraphconnector)
- [Jaeger SPM](https://www.jaegertracing.io/docs/latest/spm/)
- [OpenSearch Storage](./OPENSEARCH_STORAGE.md)
