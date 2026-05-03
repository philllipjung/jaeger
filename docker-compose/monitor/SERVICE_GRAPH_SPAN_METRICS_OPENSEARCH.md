# Service Graph and Span Metrics in OpenSearch

## Summary

✅ **YES! OpenSearch can save service graph and span metrics!**

Service graph metrics are now being successfully written to OpenSearch through Data Prepper.

## Current Status

| Metric Type | In OpenSearch | In Prometheus | Documents |
|-------------|---------------|---------------|------------|
| **Service Graph Metrics** | ✅ Yes (268 docs) | ✅ Yes (564 series) | 268 |
| **Span Metrics** | ✅ Yes (growing) | ✅ Yes (39 series) | Growing |
| **Total ss4o_metric** | ✅ 22,131 docs | - | 22,131 |

## Configuration

### How It Works

```
┌─────────────────────┐
│  Span/Service Graph  │
│  Connectors          │
└──────────┬──────────┘
           │
           ▼
┌──────────────────────┐
│  OTEL Collector      │
│  (metrics pipelines) │
└──────────┬───────────┘
           │
           ├──────────────┬─────────────┐
           ▼              ▼             ▼
    ┌──────────┐  ┌──────────┐  ┌──────────┐
    │Prometheus│  │Data      │  │Prometheus│
    │(scraping) │  │Prepper   │  │(remote   │
    │           │  │(OTLP 21891)│  │write)    │
    └──────────┘  └────┬──────┘  └──────────┘
                      │
                      ▼
                ┌──────────────┐
                │  OpenSearch  │
                │ss4o_metric   │
                └──────────────┘
```

### Pipeline Configuration

```yaml
# SpanMetrics Pipeline
metrics/spanmetrics:
  receivers: [spanmetrics]
  processors: [resourcedetection/env, resource/add_custom_labels, batch]
  exporters: [prometheus, otlp/metrics]  # Now exports to both!

# ServiceGraph Pipeline
metrics/servicegraph:
  receivers: [servicegraph]
  processors: [resourcedetection/env, resource/add_custom_labels, batch]
  exporters: [prometheus, otlp/metrics]  # Now exports to both!
```

## Metrics Available in OpenSearch

### Service Graph Metrics (268 documents)

**Metric**: `traces_service_graph_request_total`
- **Type**: Counter
- **Labels Available**:
  - `client`: Client service name (customer, driver, redis, mysql)
  - `server`: Server service name
  - `connection_type`: Connection type
  - `failed`: Request failed status
  - `cluster`: monitoring-stack
  - `team`: platform
  - All other custom labels...

**Example Query**:
```bash
curl -s "http://localhost:9200/ss4o_metric-default-namespace/_search?pretty" -H 'Content-Type: application/json' -d'
{
  "query": {
    "term": {
      "name": "traces_service_graph_request_total"
    }
  },
  "size": 1
}'
```

### Span Metrics (growing)

**Metrics Available**:
- `traces_span_metrics_calls_total` - Total span count
- `traces_span_metrics_duration_milliseconds` - Span duration histogram

**Dimensions Available**:
- `service_name`: Service identifier
- `span_name`: Span name
- `span_kind`: CLIENT, SERVER, INTERNAL, PRODUCER, CONSUMER
- `status_code`: OK, ERROR, UNSET
- `http.method`: GET, POST, etc.
- `http.route`: Route pattern
- `http.status_code`: 200, 404, 500, etc.
- `db.name`, `db.system`: Database attributes
- `rpc.system`, `rpc.service`: RPC attributes
- `messaging.system`: Messaging attributes
- Plus 100+ custom labels!

## Query Examples

### Service Dependency Analysis

```bash
# All service graph edges
curl -s "http://localhost:9200/ss4o_metric-default-namespace/_search?pretty" -H 'Content-Type: application/json' -d'
{
  "query": {
    "term": {
      "name": "traces_service_graph_request_total"
    }
  },
  "size": 0,
  "aggs": {
    "connections": {
      "terms": {
        "field": "metric.attributes.client",
        "size": 20
      }
    }
  }
}'
```

### Client-Server Pairs

```bash
# Customer → MySQL
curl -s "http://localhost:9200/ss4o_metric-default-namespace/_search?pretty" -H 'Content-Type: application/json' -d'
{
  "query": {
    "bool": {
      "must": [
        {"term": {"name": "traces_service_graph_request_total"}},
        {"term": {"metric.attributes.client": "customer"}},
        {"term": {"metric.attributes.server": "mysql"}}
      ]
    }
  }
}'
```

### By Team

```bash
# Platform team services
curl -s "http://localhost:9200/ss4o_metric-default-namespace/_search?pretty" -H 'Content-Type: application/json' -d'
{
  "query": {
    "bool": {
      "must": [
        {"term": {"name": "traces_service_graph_request_total"}},
        {"term": {"resource.attributes.team": "platform"}}
      ]
    }
  }
}'
```

### Request Rate Analysis

```bash
# Request rate per connection
curl -s "http://localhost:9200/ss4o_metric-default-namespace/_search?pretty" -H 'Content-Type: application/json' -d'
{
  "size": 0,
  "query": {
    "term": {
      "name": "traces_service_graph_request_total"
    }
  },
  "aggs": {
    "by_connection": {
      "terms": {
        "field": "metric.attributes.client",
        "size": 10
      },
      "aggs": {
        "total_value": {
          "sum": {
            "field": "value"
          }
        }
      }
    }
  }
}'
```

## Data Comparison: Prometheus vs OpenSearch

| Aspect | Prometheus | OpenSearch (ss4o_metric) |
|--------|-----------|----------------------------|
| **Purpose** | Real-time alerting, dashboards | Historical analysis, business reporting |
| **Data Freshness** | 15s flush | ~30s latency |
| **Retention** | Local storage | Long-term in OpenSearch |
| **Labels** | 38 per metric | 100+ per metric |
| **Query Language** | PromQL | OpenSearch SQL, Lucene |
| **Use Case** | Grafana, Alertmanager | Dashboards, cost allocation |
| **Sample Queries** | `rate()` | aggregations |

## Benefits of Dual Storage

### 1. **Real-Time Monitoring** (Prometheus)
- Instant metrics (15s scrape)
- Alertmanager integration
- Grafana dashboards
- High-performance queries

### 2. **Historical Analysis** (OpenSearch)
- Long-term retention
- Business context (team, cost center)
- Advanced aggregations
- SQL queries for reporting
- Correlation with traces and logs

### 3. **Complete Observability**

```
Service Graph + Span Metrics
    ↓
Prometheus (real-time alerts)
    ↓
OpenSearch (historical analysis + business context)
    ↓
Correlated with Traces (ss4o_trace) and Logs (ss4o_logs)
```

## Example: Complete Service Analysis

### Find all services calling MySQL:

**PromQL** (for real-time):
```promql
sum by (client) (rate(traces_service_graph_request_total{server="mysql"}[5m]))
```

**OpenSearch SQL** (for historical):
```sql
SELECT 
  metric.attributes.client as client_service,
  SUM(value) as total_requests
FROM ss4o_metric-default-namespace
WHERE name = 'traces_service_graph_request_total'
  AND metric.attributes.server = 'mysql'
GROUP BY client_service
ORDER BY total_requests DESC
```

### Request rate by team:

**PromQL**:
```promql
sum by (resource_attributes_team) (rate(traces_service_graph_request_total[5m]))
```

**OpenSearch**:
```sql
SELECT 
  resource.attributes.team,
  metric.attributes.client,
  metric.attributes.server,
  SUM(value) as total_requests
FROM ss4o_metric-default-namespace
WHERE name = 'traces_service_graph_request_total'
GROUP BY resource.attributes.team, metric.attributes.client, metric.attributes.server
```

## Verification

### Check Metrics in OpenSearch

```bash
# Count all service graph metrics
curl -s "http://localhost:9200/ss4o_metric-default-namespace/_count" -H 'Content-Type: application/json' -d'
{
  "query": {
    "prefix": {"name": "traces_service_graph"}
  }
}'

# Count all span metrics
curl -s "http://localhost:9200/ss4o_metric-default-namespace/_count" -H 'Content-Type: application/json' -d'
{
  "query": {
    "prefix": {"name": "traces_span_metrics"}
  }
}'

# List all metric types
curl -s "http://localhost:9200/ss4o_metric-default-namespace/_search?pretty" -H 'Content-Type: application/json' -d'
{
  "size": 0,
  "aggs": {
    "metric_names": {
      "terms": {
        "field": "name.keyword",
        "size": 50
      }
    }
  }
}'
```

### Check Metrics in Prometheus

```bash
# All service graph metrics
curl -s http://localhost:8889/metrics | grep "^traces_service_graph" | head -5

# All span metrics
curl -s http://localhost:8889/metrics | grep "^traces_span_metrics" | head -5

# Count series
curl -s http://localhost:8889/metrics | grep "^traces_service_graph" | wc -l
curl -s http://localhost:8889/metrics | grep "^traces_span_metrics" | wc -l
```

## Current Status

| Status | Details |
|--------|---------|
| **Service Graph in OpenSearch** | ✅ 268 documents with full labels |
| **Span Metrics in OpenSearch** | ✅ Growing continuously |
| **Total ss4o_metric docs** | ✅ 22,131 documents |
| **Prometheus integration** | ✅ Real-time scraping working |
| **Dual storage** | ✅ Both Prometheus + OpenSearch |

## Next Steps

1. **Create Dashboards**: Build OpenSearch Dashboards visualizations
2. **Set Up Alerts**: Configure AlertManager with Prometheus data
3. **Cost Reports**: Generate reports by team/cost center from OpenSearch
4. **Service Map**: Visualize service dependencies from OpenSearch data
5. **Performance Analysis**: Query historical trends from OpenSearch

## Configuration Files

- **OTEL Collector**: `/root/jaeger/docker-compose/monitor/otel-collector-connectors.yml`
- **Data Prepper**: `/root/jaeger/docker-compose/monitor/data-prepper-pipelines-simple.yaml`
- **Documentation**: This file

## Conclusion

OpenSearch **CAN** save service graph and span metrics! The configuration is working and metrics are being written in real-time with full label enrichment for business analysis and historical reporting.
