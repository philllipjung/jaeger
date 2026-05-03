# Jaeger SPM + OpenSearch + OTEL Collector + Data Prepper + Prometheus

Complete monitoring stack with Jaeger v2 Service Performance Monitoring (SPM), OpenTelemetry connectors (SpanMetrics, ServiceGraph), and hybrid storage (Prometheus + OpenSearch).

## Architecture

```
┌─────────────┐     ┌──────────────┐     ┌──────────┐     ┌────────────┐
│  Apps /     │────▶│   OTEL       │────▶│  Jaeger  │────▶│ OpenSearch │
│  Services   │     │   Collector  │     │   v2     │     │            │
└─────────────┘     └──────┬───────┘     └──────────┘     └────────────┘
                           │                                      │
              ┌────────────┼────────────┐                        │
              ↓            ↓             ↓                        │
        SpanMetrics   ServiceGraph   HostMetrics                  │
              │            │             │                        │
              └────────────┴─────────────┘                        │
                           │                                      ↓
                    ┌──────┴──────┐                         ┌──────────┐
                    │  Prometheus │                         │ Jaeger   │
                    │ (pre-aggr)  │                         │   UI     │
                    └─────────────┘                         └──────────┘
```

### Data Flow

| Signal      | Source            | Destination          | Purpose                                      |
|-------------|-------------------|----------------------|----------------------------------------------|
| **Traces**  | Applications      | OTEL Collector       | OTLP ingestion                               |
|            | OTEL Collector    | Jaeger               | Trace storage                                |
|            | OTEL Collector    | SpanMetrics/ServiceGraph | Pre-aggregated metrics                  |
|            | Jaeger            | OpenSearch           | Trace storage + SPM computation              |
| **Metrics** | Host/System       | OTEL Collector       | hostmetrics receiver                         |
|            | Docker containers | OTEL Collector       | docker_stats receiver                        |
|            | Applications      | OTEL Collector       | OTLP ingestion                               |
|            | OTEL Collector    | Data Prepper         | Host metrics → OpenSearch                    |
|            | SpanMetrics       | Prometheus           | RED metrics (pre-aggregated)                  |
|            | ServiceGraph      | Prometheus           | Service dependency metrics                    |
| **Logs**   | Applications      | OTEL Collector       | OTLP ingestion                               |
|            | OTEL Collector    | OpenSearch           | Log storage                                  |

## Components

| Component       | Version   | Ports              | Purpose                                      |
|-----------------|-----------|--------------------|----------------------------------------------|
| **OpenSearch**  | 3.5.0     | 9200, 9600         | Trace & metrics storage                      |
| **OpenSearch Dashboards** | 3.5.0 | 5601 | Visualization |
| **Jaeger v2**   | latest    | 16686, 8888        | Trace storage + SPM with OpenSearch backend  |
| **Data Prepper**| latest    | 21890, 21891, 4900 | OpenTelemetry metrics pipeline               |
| **OTEL Collector** | 0.131.0 | 4317, 4318, 8889  | Host metrics, SpanMetrics, ServiceGraph      |
| **Prometheus**  | v3.9.1    | 9090               | Pre-aggregated trace metrics                  |
| **Microsim**    | v0.6.0    | -                  | Optional trace simulator for testing         |

## Configuration Files

| File                    | Description                                          |
|-------------------------|-----------------------------------------------------|
| `docker-compose-final.yml` | Main compose file                                  |
| `otel-collector-connectors.yml` | OTEL Collector with SpanMetrics + ServiceGraph |
| `prometheus-connectors.yml` | Prometheus scrape configuration                   |
| `config-spm-opensearch.yaml` | Jaeger v2 config (Option 2)                      |
| `data-prepper-pipelines-simple.yaml` | Metrics & traces pipeline        |
| `data-prepper-config-simple.yaml` | Data Prepper server config               |
| `jaeger-ui.json`         | Jaeger UI configuration (enables Monitor tab)     |

## Quick Start

### 1. Start all services

```bash
cd /root/jaeger/docker-compose/monitor
docker-compose -f docker-compose-final.yml up -d
```

### 2. Check service health

```bash
# Check all containers are running
docker-compose -f docker-compose-final.yml ps

# Check OTEL Collector health
curl http://localhost:13133/healthz

# Check OpenSearch
curl http://localhost:9200/_cluster/health

# Check Jaeger UI
curl http://localhost:16686
```

### 3. View services

- **Jaeger UI**: http://localhost:16686
  - Search tab: Query traces
  - Monitor tab: View SPM metrics (computed from OpenSearch)
- **Prometheus**: http://localhost:9090
  - Query pre-aggregated SpanMetrics and ServiceGraph metrics
- **OpenSearch Dashboards**: http://localhost:5601

## Sending Traces & Metrics

### Application Configuration

Send traces and metrics to the OTEL Collector:

```bash
# Traces (gRPC)
export OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=http://localhost:4317

# Traces (HTTP)
export OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=http://localhost:4318/v1/traces

# Metrics (HTTP)
export OTEL_EXPORTER_OTLP_METRICS_ENDPOINT=http://localhost:4318/v1/metrics
```

### Host Metrics

The OTEL Collector automatically collects:
- **CPU**: Usage, percentage, throttling
- **Memory**: Available, used, cached, buffers
- **Disk**: I/O, usage, throughput
- **Network**: Bytes, packets, errors, drops
- **Load**: System load averages (1min, 5min, 15min)
- **Filesystem**: Mount points, usage, inodes

### Docker Container Metrics

The docker_stats receiver collects per-container:
- CPU usage
- Memory usage
- Network I/O
- Block I/O
- Container states

## SpanMetrics + ServiceGraph Connectors

### SpanMetrics Connector

Generates RED (Rate, Errors, Duration) metrics from trace spans:

| Metric | Type | Labels | Description |
|--------|------|--------|-------------|
| `traces_span_metrics_calls_total` | Counter | service_name, span_name, span_kind, status_code, http.method, http.status_code | Total span count |
| `traces_span_metrics_duration_milliseconds` | Histogram | service_name, span_name, span_kind | Span duration distribution |

### ServiceGraph Connector

Generates service dependency metrics:

| Metric | Type | Labels | Description |
|--------|------|--------|-------------|
| `traces_service_graph_request_total` | Counter | client, server, connection_type, failed | Total requests between services |
| `traces_service_graph_request_failed_total` | Counter | client, server, connection_type | Failed requests |
| `traces_service_graph_request_server_seconds` | Histogram | client, server, connection_type | Server-side latency |
| `traces_service_graph_request_client_seconds` | Histogram | client, server, connection_type | Client-side latency |

### Connection Types

- **Unset**: Direct HTTP/gRPC calls between services
- `messaging_system`: Kafka messaging
- `virtual_node`: Uninstrumented services (databases, caches, redis, mysql)

### Example PromQL Queries

```promql
# All service graph edges
traces_service_graph_request_total

# Service-to-service calls (frontend → customer)
traces_service_graph_request_total{client="frontend", server="customer"}

# Request rate (per second)
rate(traces_service_graph_request_total[5m])

# P95 latency (server-side)
histogram_quantile(0.95, rate(traces_service_graph_request_server_seconds_bucket[5m]))

# P95 latency by service pair
histogram_quantile(0.95, sum(rate(traces_service_graph_request_server_seconds_bucket[5m])) by (le, client, server))

# Error rate
rate(traces_service_graph_request_failed_total[5m]) / rate(traces_service_graph_request_total[5m])

# Span rate by service
sum(rate(traces_span_metrics_calls_total[5m])) by (service_name)

# Error spans
traces_span_metrics_calls_total{status_code="STATUS_CODE_ERROR"}

# P95 span duration by service
histogram_quantile(0.95, rate(traces_span_metrics_duration_milliseconds_bucket[5m])) by (le, service_name)
```

## OpenSearch Index Patterns

### Trace Indices (Jaeger)
- `jaeger-span-*`: Raw span data
- `jaeger-service-*`: Service metadata

### Metrics Indices (Data Prepper)
- `otel_metrics`: Host metrics, application metrics
- `otel_metrics_*`: Time-series metrics (if rollup enabled)

### Service Map (Data Prepper)
- `trace-analytics-service-map`: Service dependency graph

## Hybrid Storage: Prometheus vs OpenSearch

| Aspect | Prometheus (Pre-aggregated) | OpenSearch (On-Demand) |
|--------|----------------------------|------------------------|
| **Computation** | Pre-computed by OTEL Collector | Computed on-the-fly |
| **Latency** | ~15s flush interval | ~5-10s (after trace indexing) |
| **Storage** | Prometheus TSDB | OpenSearch indices |
| **Query** | PromQL (Prometheus UI) | Jaeger API / UI |
| **Metrics** | SpanMetrics + ServiceGraph | RED metrics (SPM) |
| **Use Case** | Real-time alerting, dashboards | Ad-hoc analysis, trend analysis |

### When to Use Each

**Use Prometheus for:**
- Real-time dashboards (Grafana, Prometheus UI)
- Alerting on specific service metrics
- High-rate metric queries
- Service dependency analysis

**Use OpenSearch SPM for:**
- Ad-hoc performance analysis
- Historical trend analysis
- Trace-to-metrics correlation
- Long-term retention

## Troubleshooting

### Issue: SpanMetrics/ServiceGraph not appearing in Prometheus

**Symptoms:**
- `traces_span_metrics_calls_total` shows no data
- `traces_service_graph_request_total` shows no data

**Solution:**
1. Verify OTEL Collector is running:
   ```bash
   docker logs otel-collector | grep -i "spanmetrics\|servicegraph"
   ```

2. Check metrics are being exposed:
   ```bash
   curl http://localhost:8889/metrics | grep traces_span_metrics
   curl http://localhost:8889/metrics | grep traces_service_graph
   ```

3. Verify Prometheus is scraping:
   ```bash
   curl http://localhost:9090/api/v1/targets
   ```

### Issue: Metrics take 15 seconds to appear

**Root Cause:**
SpanMetrics and ServiceGraph connectors have `metrics_flush_interval: 15s`.

**Solution:**
Wait at least 15 seconds after generating traces before querying Prometheus.

### Issue: No traces in Jaeger UI

**Solution:**
1. Check Jaeger logs:
   ```bash
   docker logs jaeger | grep "Wrote span"
   ```

2. Check OTEL Collector logs:
   ```bash
   docker logs otel-collector | grep jaeger
   ```

3. Verify traces exist in OpenSearch:
   ```bash
   curl http://localhost:9200/jaeger-span-*/_search?pretty
   ```

## Stopping Services

```bash
docker-compose -f docker-compose-final.yml down
```

To remove all data (including OpenSearch indices):

```bash
docker-compose -f docker-compose-final.yml down -v
```

## References

- [Jaeger SPM Documentation](https://www.jaegertracing.io/docs/2.15/architecture/spm/)
- [OpenTelemetry Collector](https://opentelemetry.io/docs/collector/)
- [SpanMetrics Connector](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/connector/spanmetricsconnector)
- [ServiceGraph Connector](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/connector/servicegraphconnector)
- [Data Prepper](https://opensearch.org/docs/latest/data-prepper/)
