# Service Performance Monitoring (SPM) - Service Graph Setup

This document describes the Service Graph monitoring setup for the WebFlux + Kafka + Spark ML demo application.

## Quickstart

### Start Monitoring Stack with OpenSearch & Service Graph

```bash
cd /root/jaeger/docker-compose/monitor
docker-compose -f docker-compose-opensearch-with-prometheus.yml up -d
```

**Access Points:**
- **Jaeger UI:** http://localhost:16686
- **Prometheus:** http://localhost:9090
- **OpenSearch Dashboards:** http://localhost:5601
- **OTEL Collector Metrics:** http://localhost:8889/metrics

## Application Ports

| Service | Port | Protocol | Description |
|---------|------|----------|-------------|
| **React Client** | 5173 | HTTP | Frontend UI |
| **Server1** | 8081 | HTTP | REST API Gateway |
| **Server2** | 8082 | HTTP | REST API + Kafka Consumer |
| **Server2** | 9094 | gRPC | ML Classification Service ⚠️ |
| **Kafka** | 9092 | TCP | Message Broker |

⚠️ **Important:** Server2's gRPC port changed from 9090 to 9094 due to port conflicts with Prometheus.

## Monitoring Stack Ports

| Component | Port | Description |
|-----------|------|-------------|
| **OTEL Collector** | 4318 | HTTP OTLP Receiver (traces) |
| **OTEL Collector** | 8889 | Prometheus Metrics Export |
| **Jaeger UI** | 16686 | Web UI for trace visualization |
| **Prometheus** | 9090 | Metrics scraping and query |
| **OpenSearch** | 9200 | Search engine for trace storage |
| **OpenSearch Dashboards** | 5601 | Data visualization UI |

## Service Graph Metrics

The Service Graph Connector analyzes traces and generates metrics showing relationships between services.

### Available Metrics

| Metric | Type | Labels | Description |
|--------|------|--------|-------------|
| `traces_service_graph_request_total` | Counter | client, server, connection_type, failed | Total request count between services |
| `traces_service_graph_request_failed_total` | Counter | client, server, connection_type, failed | Failed request count |
| `traces_service_graph_request_server_seconds` | Histogram | client, server, connection_type, failed | Server-side latency |
| `traces_service_graph_request_client_seconds` | Histogram | client, server, connection_type, failed | Client-side latency |

### Connection Types

- **Unset:** Direct HTTP/gRPC calls between services
- `messaging_system`: Kafka messaging
- `virtual_node`: Uninstrumented services (e.g., external databases)

### Current Service Graph Edges

```
user → server1 (virtual_node: client)
server1 → server2 (HTTP REST)
server2 → server2 (messaging_system: Kafka)
java-client → server1
customer → mysql (virtual_node)
driver → redis (virtual_node)
```

### Query Examples

```promql
# All service graph edges
traces_service_graph_request_total

# Server1 to Server2 calls
traces_service_graph_request_total{client="server1", server="server2"}

# Failed requests
traces_service_graph_request_total{failed="true"}

# Request rate (5min window)
rate(traces_service_graph_request_total[5m])

# P95 latency
histogram_quantile(0.95, rate(traces_service_graph_request_server_seconds_bucket[5m]))
```

## Configuration Files

| File | Description |
|------|-------------|
| `docker-compose-opensearch-with-prometheus.yml` | Full monitoring stack with OpenSearch |
| `otel-collector-config-connector.yml` | OTEL Collector with Service Graph Connector |
| `prometheus.yml` | Prometheus scrape targets |
| `jaeger-ui.json` | Jaeger UI configuration |

### Docker Compose File

**File:** `docker-compose-opensearch-with-prometheus.yml`

```yaml
services:
  opensearch:
    image: opensearchproject/opensearch:3.5.0@sha256:2f2244c7c0ad3a4a0d09977c2b519977b77bacc92e1eaf995c080c1d22f517b6
    networks:
      - backend
    environment:
      - discovery.type=single-node
      - plugins.security.disabled=true
      - http.host=0.0.0.0
      - transport.host=127.0.0.1
      - OPENSEARCH_INITIAL_ADMIN_PASSWORD=passRT%^#234
    ports:
      - "9200:9200"
    healthcheck:
      test: [ "CMD-SHELL", "curl -f http://localhost:9200 || exit 1" ]
      interval: 10s
      timeout: 10s
      retries: 30

  opensearch-dashboards:
    image: opensearchproject/opensearch-dashboards:3.5.0
    networks:
      - backend
    environment:
      - OPENSEARCH_HOSTS=["http://opensearch:9200"]
      - DISABLE_SECURITY_DASHBOARDS_PLUGIN=true
    ports:
      - "5601:5601"
    depends_on:
      opensearch:
        condition: service_healthy
    healthcheck:
      test: [ "CMD-SHELL", "curl -f http://localhost:5601/api/status || exit 1" ]
      interval: 10s
      timeout: 10s
      retries: 30

  jaeger:
    networks:
      backend:
        # This is the host name used in Prometheus scrape configuration.
        aliases: [ spm_metrics_source ]
    image: jaegertracing/jaeger:${JAEGER_VERSION:-latest}
    volumes:
      - "./jaeger-ui.json:/etc/jaeger/jaeger-ui.json"
      - "../../cmd/jaeger/config-spm-opensearch.yaml:/etc/jaeger/config.yml"
    command: ["--config", "/etc/jaeger/config.yml"]
    environment:
      - SPANMETRICS_FLUSH_INTERVAL=${SPANMETRICS_FLUSH_INTERVAL:-60s}
    ports:
      - "16686:16686" # Jaeger UI http://localhost:16686
      - "8888:8888"
      - "8889:8889"
    depends_on:
      opensearch:
        condition: service_healthy

  prometheus:
    networks:
      - backend
    image: prom/prometheus:v3.9.1@sha256:1f0f50f06acaceb0f5670d2c8a658a599affe7b0d8e78b898c1035653849a702
    volumes:
      - "./prometheus.yml:/etc/prometheus/prometheus.yml"
    ports:
      - "9090:9090"

  microsim:
    networks:
      - backend
    image: yurishkuro/microsim:v0.6.0@sha256:fd75a9b3dd1bb4d7d305a562edeac60051a7fec784b898ff7ab834eacc73f41e
    command: "-d 24h -s 500ms"
    environment:
      - OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=http://otel-collector:4318/v1/traces
    depends_on:
      - otel-collector

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

  # NOTE: Jaeger Dependencies (spark-dependencies) is not compatible with OpenSearch 3.5.0
  # It only supports Elasticsearch up to version 7.x
  # To enable jaeger-dependency-* metrics, use Elasticsearch 7.x instead of OpenSearch

networks:
  backend:

volumes:
  esdata:
    driver: local
```

**Services Summary:**

| Service | Image | Ports | Description |
|---------|-------|-------|-------------|
| opensearch | opensearchproject/opensearch:3.5.0 | 9200 | Trace storage |
| opensearch-dashboards | opensearchproject/opensearch-dashboards:3.5.0 | 5601 | Visualization UI |
| jaeger | jaegertracing/jaeger:latest | 16686, 8888-8889 | Trace processing & UI |
| prometheus | prom/prometheus:v3.9.1 | 9090 | Metrics aggregation |
| microsim | yurishkuro/microsim:v0.6.0 | - | Trace simulator |
| otel-collector | otel/opentelemetry-collector-contrib:0.119.0 | 4318-4319 | Trace/metrics processing with Service Graph |

## Known Issues and Solutions

### Issue 1: Server2 gRPC Calls Failing

**Symptoms:**
- `ml.MLJobService/SubmitClassificationJob` spans have ERROR status
- HTTP 500 errors on `/api/ml/classification`

**Root Cause:**
gRPC port mismatch. Server1's `MLClassificationClient.java` was configured to use port 9090, but:
- Port 9090 is used by Prometheus
- Server2's gRPC server runs on port 9094

**Solution:**
Updated `MLClassificationClient.java`:
```java
private static final int GRPC_SERVER_PORT = 9094;  // Changed from 9090
```

### Issue 2: Service Graph Metrics Not Appearing

**Symptoms:**
- `traces_service_graph_request_total` metrics are empty
- Service Graph connector logs show "edge completed" but no metrics in Prometheus

**Root Cause:**
Prometheus was not configured to scrape the OTEL Collector's metrics endpoint.

**Solution:**
Added OTEL Collector as a Prometheus scrape target in `prometheus.yml`:
```yaml
- job_name: otel-collector
  static_configs:
  - targets: ['otel-collector:8889']
```

### Issue 3: Metrics Take 60 Seconds to Appear

**Symptoms:**
- Generate traces but metrics don't appear in Prometheus immediately

**Root Cause:**
Service Graph Connector has a `metrics_flush_interval: 60s`.

**Solution:**
Wait at least 60 seconds after generating traces before querying Prometheus.

### Issue 4: jaeger-dependency-* Metrics Not Available

**Symptoms:**
- `jaeger-dependency-*` metrics don't exist

**Root Cause:**
Spark-dependencies tool is not compatible with OpenSearch 3.5.0 (only supports Elasticsearch up to 7.x).

**Solution:**
Use Service Graph Connector instead. It provides the same functionality:
- `traces_service_graph_request_total` replaces `jaeger-dependency-*`
- Works with OpenSearch 3.5.0

## Testing Service Graph

### Generate Test Traces

1. **HTTP REST calls:**
```bash
curl http://localhost:8081/api/hello
```

2. **gRPC calls:**
```bash
curl -X POST http://localhost:8081/api/ml/classification \
  -H "Content-Type: application/json" \
  -d '{"job_id":"test-123"}'
```

3. **Generate multiple requests:**
```bash
for i in {1..10}; do
  curl http://localhost:8081/api/hello
  curl -X POST http://localhost:8081/api/ml/classification \
    -H "Content-Type: application/json" \
    -d "{\"job_id\":\"test-$i\"}"
  sleep 0.5
done
```

### Verify in Service Graph

Wait 60 seconds for metrics flush, then query:
```bash
curl -s 'http://localhost:9090/api/v1/query?query=traces_service_graph_request_total'
```

## Debug Service Graph

### Enable Debug Logging

Edit `otel-collector-config-connector.yml`:
```yaml
service:
  telemetry:
    logs:
      level: debug
```

Restart collector:
```bash
docker-compose -f docker-compose-opensearch-with-prometheus.yml restart otel-collector
```

### Check Service Graph Activity

```bash
docker logs monitor_otel-collector_1 | grep "edge completed"
```

Expected output:
```
edge completed client_service="server1" server_service="server2"
```

### View Metrics in Real-Time

```bash
# OTEL Collector metrics endpoint
curl -s http://localhost:8889/metrics | grep service_graph

# Prometheus query
curl -s 'http://localhost:9090/api/v1/query?query=traces_service_graph_request_total'
```

## Service Graph Connector Configuration

**File:** `otel-collector-config-connector.yml`

Key settings:
- **Store TTL:** 60s (time to wait for paired spans)
- **Max Items:** 10000 (maximum unpaired spans to keep)
- **Metrics Flush Interval:** 60s (how often to emit metrics)
- **Latency Buckets:** [100ms, 250ms, 1s, 5s, 10s]

## Visualization

### Jaeger UI
**URL:** http://localhost:16686

- View individual traces
- See service dependencies
- Filter by service, operation, tags

### Prometheus
**URL:** http://localhost:9090

**Recommended Queries:**

```promql
# Service graph overview
traces_service_graph_request_total

# Request rate by service pair
rate(traces_service_graph_request_total[5m])

# Error rate
rate(traces_service_graph_request_failed_total[5m]) / rate(traces_service_graph_request_total[5m])

# P95 latency (server-side)
histogram_quantile(0.95, rate(traces_service_graph_request_server_seconds_bucket[5m]))

# P95 latency (client-side)
histogram_quantile(0.95, rate(traces_service_graph_request_client_seconds_bucket[5m]))
```

### OpenSearch Dashboards
**URL:** http://localhost:5601

- Index patterns: `jaeger-*`
- Visualize trace data
- Create custom dashboards

## HTTP API Specification

## Query Metrics

`/api/metrics/{metric_type}?{query}`

Where (Backus-Naur form):

```
metric_type = 'latencies' | 'calls' | 'errors'

query = services , [ '&' optionalParams ]

optionalParams = param | param '&' optionalParams

param = groupByOperation | quantile | endTs | lookback | step | ratePer | spanKinds

services = service | service '&' services
service = 'service=' strValue
  - The list of services to include in the metrics selection filter, which are logically 'OR'ed.
  - Mandatory.

quantile = 'quantile=' floatValue
  - The quantile to compute the latency 'P' value. Valid range (0,1].
  - Mandatory for 'latencies' type.

groupByOperation = 'groupByOperation=' boolValue
boolValue = '1' | 't' | 'T' | 'true' | 'TRUE' | 'True' | 0 | 'f' | 'F' | 'false' | 'FALSE' | 'False'
  - A boolean value which will determine if the metrics query will also group by operation.
  - Optional with default: false

endTs = 'endTs=' intValue
  - The posix milliseconds timestamp of the end time range of the metrics query.
  - Optional with default: now

lookback = 'lookback=' intValue
  - The duration, in milliseconds, from endTs to look back on for metrics data points.
  - For example, if set to `3600000` (1 hour), the query would span from `endTs - 1 hour` to `endTs`.
  - Optional with default: 3600000 (1 hour).

step = 'step=' intValue
  - The duration, in milliseconds, between data points of the query results.
  - For example, if set to 5s, the results would produce a data point every 5 seconds from the `endTs - lookback` to `endTs`.
  - Optional with default: 5000 (5 seconds).

ratePer = 'ratePer=' intValue
  - The duration, in milliseconds, in which the per-second rate of change is calculated for a cumulative counter metric.
  - Optional with default: 600000 (10 minutes).

spanKinds = spanKind | spanKind '&' spanKinds
spanKind = 'spanKind=' spanKindType
spanKindType = 'unspecified' | 'internal' | 'server' | 'client' | 'producer' | 'consumer'
  - The list of spanKinds to include in the metrics selection filter, which are logically 'OR'ed.
  - Optional with default: 'server'
```

## Important Notes

1. **Metrics Flush Interval:** Service graph metrics are emitted every 60 seconds. You must wait at least 60 seconds after generating traces before they appear in Prometheus.

2. **Trace Context Propagation:** Service graph edges require both CLIENT and SERVER spans from the same trace (same trace ID) with proper parent-child relationship.

3. **Virtual Nodes:** Uninstrumented services (databases, caches) appear with `virtual_node` label.

4. **TTL Setting:** The service graph connector has a 60-second TTL. If CLIENT and SERVER spans arrive more than 60 seconds apart, they won't be paired.

## Building from Source

### Build jaeger-v2 docker image

```shell
cd /root/jaeger
make build
```

### Bring up the dev environment

```bash
make dev
```

## Sending Traces

We will use [tracegen](https://github.com/jaegertracing/jaeger/tree/main/cmd/tracegen)
to emit traces to the OpenTelemetry Collector which, in turn, will aggregate the trace data into metrics.

Start the local stack needed for SPM, if not already done:

```shell
docker-compose -f docker-compose-opensearch-with-prometheus.yml up
```

Generate a specific number of traces with:

```shell
docker run --env OTEL_EXPORTER_OTLP_TRACES_ENDPOINT="http://otel-collector:4318/v1/traces" \
  --network monitor_backend \
  --rm \
  jaegertracing/jaeger-tracegen:latest \
    -trace-exporter otlp-http \
    -traces 1
```

Or, emit traces over a period of time with:

```shell
docker run --env OTEL_EXPORTER_OTLP_TRACES_ENDPOINT="http://otel-collector:4318/v1/traces" \
  --network monitor_backend \
  --rm \
  jaegertracing/jaeger-tracegen:latest \
    -trace-exporter otlp-http \
    -duration 5s
```

Navigate to Jaeger UI at http://localhost:16686/ and you should be able to see traces from this demo application
under the `tracegen` service.

Then navigate to the Monitor tab at http://localhost:16686/monitor to view the RED metrics.

## Additional Resources

[Service Performance Monitoring (SPM)](https://www.jaegertracing.io/docs/latest/spm/)

[OpenTelemetry Service Graph Connector](https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/main/connector/servicegraphconnector/README.md)

[Jaeger HTTP API](https://www.jaegertracing.io/docs/latest/apis/)
