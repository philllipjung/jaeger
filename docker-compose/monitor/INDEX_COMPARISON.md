# Complete Index Comparison - OpenSearch Monitoring Stack

## Executive Summary

| Category | Index | Docs | Size | Purpose | Format |
|----------|-------|------|------|---------|--------|
| **Traces** | jaeger-span-* | 8.2M | 244 MB | Jaeger SPM | Jaeger JSON |
| **Traces** | otel-v1-apm-span-* | 430K | 217 MB | Trace Analytics | APM span |
| **Traces** | ss4o_trace-default-namespace | 323K | 139 MB | Custom traces | Data Prepper |
| **Metrics** | otel_metrics | 55K | 10 MB | Host metrics | OTEL metric |
| **Metrics** | ss4o_metric-default-namespace | 6K | 1.4 MB | Custom metrics | OTEL metric |
| **Logs** | ss4o_logs-default-namespace | 2.3K | 679 KB | Container logs | Log record |

---

## 1. TRACE INDICES COMPARISON

### Overview

| Index | Docs | Size | Source | Schema | Shards | Use Case |
|-------|------|------|--------|--------|--------|----------|
| `jaeger-span-2026-02-20` | 6,218,554 | 184 MB | Jaeger | Jaeger Span | 5 | Historical traces |
| `jaeger-span-2026-02-21` | 2,006,786 | 60 MB | Jaeger | Jaeger Span | 5 | Current traces |
| `otel-v1-apm-span-000001` | 430,429 | 217 MB | Data Prepper | APM Span | 1 | Trace Analytics |
| `ss4o_trace-default-namespace` | 323,657 | 140 MB | Data Prepper | APM Span | 1 | Custom traces |

**Total Traces**: 8,979,426 documents | 601 MB

### Data Schema Comparison

#### Jaeger Span Schema (jaeger-span-*)
```json
{
  "traceID": "abc123...",
  "spanID": "def456...",
  "operationName": "/customer",
  "serviceName": "customer",
  "startTime": 1234567890000000,
  "duration": 1500000,
  "tags": [
    {"key": "http.method", "type": "string", "value": "GET"},
    {"key": "http.status_code", "type": "string", "value": "200"}
  ],
  "logs": [
    {
      "timestamp": 1234567890000000,
      "fields": [
        {"key": "message", "value": "Processing request"}
      ]
    }
  ],
  "process": {
    "serviceName": "customer",
    "tags": [
      {"key": "hostname", "value": "server-01"}
    ]
  }
}
```

#### APM Span Schema (otel-v1-apm-span-*, ss4o_trace-default-namespace)
```json
{
  "traceId": "abc123...",
  "spanId": "def456...",
  "parentSpanId": "ghi789...",
  "transactionId": "txn123...",
  "spanName": "HTTP GET /customer",
  "serviceName": "customer",
  "serviceInstance": "customer-0",
  "serviceType": "unknown",
  "startTime": 1234567890,
  "duration": 1500000,
  "outcome": "success",
  "spanKind": "SERVER",
  "statusCode": "UNSET",
  "attributes": {
    "http.method": "GET",
    "http.status_code": 200,
    "http.route": "/customer"
  },
  "resource": {
    "host.name": "server-01",
    "service.name": "customer"
  }
}
```

### Key Differences

| Aspect | Jaeger | APM (OTEL) |
|--------|--------|------------|
| **Schema** | Jaeger JSON | OpenTelemetry APM |
| **Timestamp** | Nanoseconds (Unix) | Milliseconds (Unix) |
| **Tags** | Array of key-value | Nested attributes object |
| **Logs** | Array with timestamp | Not present |
| **Process** | Separate process object | Embedded in resource |
| **Parent** | References array | parentSpanId field |
| **Sharding** | 5 primary shards | 1 primary shard |
| **Retention** | Daily indices | Rollup index |

### Why Duplicate Traces?

| Purpose | Recommended Index | Reason |
|---------|------------------|--------|
| **SPM (Service Performance Monitoring)** | `jaeger-span-*` | Jaeger UI SPM tab queries directly |
| **Trace Analytics UI** | `otel-v1-apm-span-*` | Optimized for service map visualizations |
| **Custom Analysis** | `ss4o_trace-default-namespace` | Your custom namespace with labels |
| **Long-term Storage** | `jaeger-span-*` | Daily indices for easy retention policies |

### Query Performance

| Index Type | Best For | Query Speed | Storage Efficiency |
|------------|----------|-------------|-------------------|
| `jaeger-span-*` | Jaeger UI | Fast | High (5 shards) |
| `otel-v1-apm-span-*` | Dashboards APM | Medium | Medium |
| `ss4o_trace-default-namespace` | Custom queries | Fast | High (compact schema) |

---

## 2. METRICS INDICES COMPARISON

### Overview

| Index | Docs | Size | Source | Type | Update Freq |
|-------|------|------|--------|------|-------------|
| `otel_metrics` | 55,596 | 10 MB | Data Prepper | Host/Container | Real-time |
| `ss4o_metric-default-namespace` | 6,163 | 1.4 MB | Data Prepper | All metrics | Real-time |

**Total Metrics**: 61,759 documents | 11.4 MB

### Data Schema Comparison

Both indices use OpenTelemetry metric schema:

```json
{
  "name": "system.cpu.usage",
  "kind": "GAUGE",
  "value": 75.5,
  "unit": "1",
  "time": "2026-02-21T00:51:40.610Z",
  "attributes": {
    "state": "user"
  },
  "resource": {
    "host.name": "server-01",
    "os.type": "linux",
    "cluster": "monitoring-stack",
    "datacenter": "us-west-1",
    "team": "platform"
  }
}
```

### Metric Types in Each Index

| Metric Type | `otel_metrics` | `ss4o_metric` |
|-------------|----------------|---------------|
| Host metrics (CPU, memory, disk) | ✅ | ✅ |
| Container metrics (docker stats) | ✅ | ✅ |
| Application metrics (OTLP) | ✅ | ✅ |
| Custom labels (cluster, team, etc.) | ❌ | ✅ |
| Resource enrichment | ❌ | ✅ |

### Key Differences

| Aspect | `otel_metrics` | `ss4o_metric-default-namespace` |
|--------|----------------|--------------------------------|
| **Custom Labels** | None | Full enrichment |
| **Cluster** | Not present | monitoring-stack |
| **Datacenter** | Not present | us-west-1 |
| **Region** | Not present | us-west |
| **Team** | Not present | platform |
| **Cost Center** | Not present | engineering |
| **SLA Level** | Not present | gold |

### Storage Comparison

| Metric | `otel_metrics` | `ss4o_metric` |
|--------|----------------|--------------|
| **Avg doc size** | ~190 bytes | ~240 bytes |
| **Total size** | 10 MB | 1.4 MB |
| **Docs/MB** | ~5,559 | ~4,400 |
| **Overhead** | Lower (no labels) | Higher (more labels) |

### Why Duplicate Metrics?

| Use Case | Recommended Index | Reason |
|----------|------------------|--------|
| **Basic monitoring** | `otel_metrics` | Lower storage, faster aggregation |
| **Team allocation** | `ss4o_metric` | Has `team`, `cost_center` labels |
| **Multi-datacenter** | `ss4o_metric` | Has `datacenter`, `region` labels |
| **SLA tracking** | `ss4o_metric` | Has `sla_level`, `monitoring_tier` |
| **Cost analysis** | `ss4o_metric` | Has `business_unit`, `department` |

---

## 3. LOGS INDICES COMPARISON

### Overview

| Index | Docs | Size | Source | Type | Format |
|-------|------|------|--------|------|--------|
| `ss4o_logs-default-namespace` | 2,316 | 679 KB | OTEL Collector | Container/App | Structured |

### Log Schema

```json
{
  "body": "Started watching file",
  "timestamp": "2026-02-21T00:51:40.610Z",
  "log.file.path": "/var/lib/docker/containers/.../...-json.log",
  "log_type": "docker",
  "severity": "info",
  "severityNumber": 9,
  "resource": {
    "host.name": "e3b7139ca07a",
    "container.id": "bf47de0ffe4a",
    "container.name": "jaeger",
    "cluster": "monitoring-stack",
    "team": "platform"
  }
}
```

### Log Sources

| Source | Log Type | Example |
|--------|----------|---------|
| Docker container stdout/stderr | `docker` | Jaeger, Data Prepper logs |
| Container logs (K8s format) | `container` | Application container logs |
| OTLP applications | `otlp` | Application logs via SDK |
| System journal | `journal` | System logs (if enabled) |

---

## 4. DATA FLOW COMPARISON

### Trace Flow

```
┌─────────────┐
│ Application │
└──────┬──────┘
       │ OTLP (4317/4318)
       ▼
┌─────────────────┐
│ OTEL Collector  │
└──────┬──────────┘
       │
       ├─────────────────────┬──────────────────────┐
       ▼                     ▼                      ▼
┌──────────────┐    ┌──────────────┐     ┌──────────────┐
│   Jaeger     │    │Data Prepper  │     │Data Prepper  │
│  (4317)      │    │  (21890)     │     │  (21890)     │
└──────┬───────┘    └──────┬───────┘     └──────┬───────┘
       │                   │                    │
       ▼                   ▼                    ▼
┌─────────────────┐ ┌─────────────┐   ┌─────────────┐
│jaeger-span-*   │ │otel-v1-apm  │   │ss4o_trace   │
│(8.2M docs)     │ │(430K docs)   │   │(323K docs)  │
└─────────────────┘ └─────────────┘   └─────────────┘
       ↓                   ↓                    ↓
  Jaeger UI SPM    Trace Analytics    Custom queries
```

### Metric Flow

```
┌─────────────┐
│ Host/System │
│ Docker      │
│ Application │
└──────┬──────┘
       │
       ▼
┌─────────────────┐
│ OTEL Collector  │
└──────┬──────────┘
       │ OTLP (21891)
       ▼
┌──────────────────┐
│  Data Prepper    │
└──────┬───────────┘
       │
       ├────────────────┬──────────────────┐
       ▼                ▼                  ▼
┌──────────────┐ ┌─────────────┐  ┌──────────────┐
│otel_metrics  │ │ss4o_metric  │  │  Prometheus  │
│(55K docs)    │ │(6K docs)    │  │(real-time)   │
└──────────────┘ └─────────────┘  └──────────────┘
       ↓                ↓                  ↓
  Basic metrics   Labeled metrics    Grafana/Alerts
```

### Log Flow

```
┌─────────────────┐
│ Docker Logs     │
│ /var/log/...    │
│ Applications    │
└──────┬──────────┘
       │ filelog receiver
       ▼
┌─────────────────┐
│ OTEL Collector  │
└──────┬──────────┘
       │
       ▼
┌─────────────────┐
│ Data Prepper    │ (optional, direct to OpenSearch)
└──────┬──────────┘
       │
       ▼
┌──────────────────┐
│ss4o_logs-        │
│default-namespace │
│(2.3K docs)       │
└──────────────────┘
```

---

## 5. STORAGE EFFICIENCY COMPARISON

### Document Size Analysis

| Index | Avg Doc Size | Total Size | Docs/MB | Efficiency |
|-------|--------------|------------|---------|------------|
| `jaeger-span-*` | ~30 bytes | 244 MB | ~33,667 | **Highest** |
| `otel-v1-apm-span-*` | ~520 bytes | 217 MB | ~1,983 | Medium |
| `ss4o_trace-default-namespace` | ~450 bytes | 140 MB | ~2,312 | High |
| `otel_metrics` | ~190 bytes | 10 MB | ~5,559 | **High** |
| `ss4o_metric-default-namespace` | ~240 bytes | 1.4 MB | ~4,400 | Medium |
| `ss4o_logs-default-namespace` | ~300 bytes | 679 KB | ~3,408 | Medium |

**Note**: Lower docs/MB = larger documents = more storage per document

### Storage Distribution

```
jaeger-span-*:    244 MB  ████████████████████████  40%
otel-v1-apm-span: 217 MB  ██████████████████████   36%
ss4o_trace:        140 MB  ████████████████         23%
otel_metrics:       10 MB  █                     2%
ss4o_metric:       1.4 MB  ▐                    <1%
ss4o_logs:         679 KB  ▐                    <1%

Total: 613 MB for main telemetry indices
```

### Shard Efficiency

| Index | Primary Shards | Replicas | Docs/Shard | Size/Shard |
|-------|---------------|----------|------------|------------|
| `jaeger-span-*` | 5 | 1 | ~1.6M | 48 MB |
| `otel-v1-apm-span-*` | 1 | 1 | 430K | 217 MB |
| `ss4o_trace-default-namespace` | 1 | 1 | 323K | 140 MB |
| `otel_metrics` | 1 | 1 | 55K | 10 MB |
| `ss4o_metric-default-namespace` | 1 | 1 | 6K | 1.4 MB |
| `ss4o_logs-default-namespace` | 1 | 1 | 2.3K | 679 KB |

---

## 6. QUERY CAPABILITIES COMPARISON

### Jaeger Span Queries

```bash
# Find trace by ID
curl -s "http://localhost:9200/jaeger-span-*/_search?q=traceID:abc123"

# Find all spans for a service
curl -s "http://localhost:9200/jaeger-span-*/_search?q=serviceName:customer"

# Find slow traces (>1s)
curl -s "http://localhost:9200/jaeger-span-*/_search?q=duration:[1000000 TO *]"

# Find error traces
curl -s "http://localhost:9200/jaeger-span-*/_search?q=tags.key:error"
```

### APM Span Queries

```bash
# Find traces by service name
curl -s "http://localhost:9200/otel-v1-apm-span-*/_search?q=serviceName:customer"

# Find traces with errors
curl -s "http://localhost:9200/otel-v1-apm-span-*/_search?q=statusCode:ERROR"

# Find traces by duration
curl -s "http://localhost:9200/otel-v1-apm-span-*/_search?q=duration:[1000000 TO *]"

# Aggregate by service
curl -s "http://localhost:9200/otel-v1-apm-span-*/_search" -H 'Content-Type: application/json' -d'
{
  "size": 0,
  "aggs": {
    "services": {
      "terms": {
        "field": "serviceName",
        "size": 10
      }
    }
  }
}'
```

### ss4o Trace Queries (with Custom Labels)

```bash
# Find traces by team
curl -s "http://localhost:9200/ss4o_trace-default-namespace/_search?q=resource.attributes.team:platform"

# Find traces by datacenter
curl -s "http://localhost:9200/ss4o_trace-default-namespace/_search?q=resource.attributes.datacenter:us-west-1"

# Find traces by SLA level
curl -s "http://localhost:9200/ss4o_trace-default-namespace/_search?q=resource.attributes.sla_level:gold"

# Multi-filter query
curl -s "http://localhost:9200/ss4o_trace-default-namespace/_search" -H 'Content-Type: application/json' -d'
{
  "query": {
    "bool": {
      "must": [
        {"term": {"resource.attributes.team": "platform"}},
        {"term": {"resource.attributes.monitoring_tier": "production"}}
      ]
    }
  }
}'
```

### Metric Queries

```bash
# otel_metrics (basic)
curl -s "http://localhost:9200/otel_metrics/_search?q=name:system.cpu.usage"

# ss4o_metric (with labels)
curl -s "http://localhost:9200/ss4o_metric-default-namespace/_search?q=name:system.cpu.usage"

# Metrics by team
curl -s "http://localhost:9200/ss4o_metric-default-namespace/_search?q=resource.attributes.team:platform"

# Cost allocation query
curl -s "http://localhost:9200/ss4o_metric-default-namespace/_search" -H 'Content-Type: application/json' -d'
{
  "size": 0,
  "aggs": {
    "by_cost_center": {
      "terms": {
        "field": "resource.attributes.cost_center",
        "size": 10
      }
    }
  }
}'
```

### Log Queries

```bash
# All docker logs
curl -s "http://localhost:9200/ss4o_logs-default-namespace/_search?q=log_type:docker"

# Error logs
curl -s "http://localhost:9200/ss4o_logs-default-namespace/_search?q=body:*error*"

# Logs by container
curl -s "http://localhost:9200/ss4o_logs-default-namespace/_search?q=log.file.path:*jaeger*"

# Logs by team
curl -s "http://localhost:9200/ss4o_logs-default-namespace/_search?q=resource.attributes.team:platform"
```

---

## 7. REDUNDANCY vs UNIQUENESS

### Duplicate Data

| Data Type | Duplicates | Storage Overhead | Benefit |
|-----------|------------|------------------|---------|
| Traces | 3x (Jaeger, APM, ss4o) | ~400 MB | Multiple UI support, different schemas |
| Metrics | 2x (otel, ss4o) | ~1.4 MB | Labeled vs unlabeled metrics |
| Logs | 1x (ss4o) | None | Single source of truth |

### Unique Data per Index

| Index | Unique Fields | Purpose |
|-------|---------------|---------|
| `jaeger-span-*` | `process`, `references` | Jaeger UI compatibility |
| `otel-v1-apm-span-*` | `transactionId`, `serviceType` | Trace Analytics UI |
| `ss4o_trace-default-namespace` | Custom resource labels | Business context |
| `otel_metrics` | Basic metrics | Storage efficiency |
| `ss4o_metric-default-namespace` | 100+ labels | Cost allocation, filtering |
| `ss4o_logs-default-namespace` | `log_type`, container metadata | Centralized logging |

---

## 8. PERFORMANCE CHARACTERISTICS

### Write Performance

| Index | Write Rate | Batch Size | Latency |
|-------|------------|------------|---------|
| `jaeger-span-*` | High | Large (traces) | Medium |
| `otel-v1-apm-span-*` | High | Large (traces) | Medium |
| `ss4o_trace-default-namespace` | High | Medium | Low |
| `otel_metrics` | Medium | Small (metrics) | Low |
| `ss4o_metric-default-namespace` | Medium | Small (metrics) | Low |
| `ss4o_logs-default-namespace` | Low | Small (logs) | Low |

### Read Performance

| Index Type | Avg Query Time | Best Queries | Worst Queries |
|-------------|----------------|--------------|---------------|
| `jaeger-span-*` | Fast | Trace ID | Full text search |
| `otel-v1-apm-span-*` | Medium | Service name | Wildcard searches |
| `ss4o_trace-default-namespace` | Fast | Filtered queries | Range queries |
| `otel_metrics` | Fast | Metric name | Aggregations |
| `ss4o_metric-default-namespace` | Medium | Label filters | High cardinality |
| `ss4o_logs-default-namespace` | Medium | Full text | Wildcard searches |

---

## 9. RECOMMENDATIONS

### For Jaeger UI Users

**Use**: `jaeger-span-*`
- Fastest for trace search
- Native Jaeger schema
- Optimized for Jaeger UI
- SPM tab queries directly

### For Trace Analytics Users

**Use**: `otel-v1-apm-span-*`
- Optimized for service map
- Better for visualizations
- APM-specific schema

### For Custom Analysis

**Use**: `ss4o_trace-default-namespace`
- Full label enrichment
- Business context (team, cost center, SLA)
- Custom queries and dashboards
- Multi-dimensional filtering

### For Basic Monitoring

**Use**: `otel_metrics`
- Lower storage overhead
- Faster aggregations
- Sufficient for basic metrics

### For Business Analysis

**Use**: `ss4o_metric-default-namespace`
- Cost allocation by team/department
- SLA tracking
- Multi-datacenter analysis
- Business unit reporting

### For Logging

**Use**: `ss4o_logs-default-namespace`
- All logs in one place
- Full label enrichment
- Container metadata
- Business context

---

## 10. MAINTENANCE CONSIDERATIONS

### Index Retention

| Index Pattern | Retention Strategy | ILM Policy |
|---------------|-------------------|------------|
| `jaeger-span-*` | Daily, keep 7-30 days | Delete after 30 days |
| `otel-v1-apm-span-*` | Rollup, keep 30 days | Rollup + delete |
| `ss4o_trace-default-namespace` | Single, keep 30 days | Delete after 30 days |
| `otel_metrics` | Single, keep 7 days | Delete after 7 days |
| `ss4o_metric-default-namespace` | Single, keep 30 days | Delete after 30 days |
| `ss4o_logs-default-namespace` | Single, keep 7 days | Delete after 7 days |

### Storage Optimization

```bash
# Force merge indices (optimize read performance)
curl -X POST "http://localhost:9200/jaeger-span-*/_forcemerge?max_num_segments=1"

# Delete old indices (retention)
curl -X DELETE "http://localhost:9200/jaeger-span-2026-02-01"

# Close old indices (free memory)
curl -X POST "http://localhost:9200/jaeger-span-2026-02-01/_close"
```

---

## SUMMARY

| Aspect | Best Index | Alternative |
|--------|-----------|-------------|
| **Jaeger UI** | `jaeger-span-*` | - |
| **Trace Analytics** | `otel-v1-apm-span-*` | - |
| **Custom Traces** | `ss4o_trace-default-namespace` | - |
| **Basic Metrics** | `otel_metrics` | Prometheus (real-time) |
| **Business Metrics** | `ss4o_metric-default-namespace` | - |
| **Logging** | `ss4o_logs-default-namespace` | - |
| **Real-time Alerts** | Prometheus | - |
| **Historical Analysis** | `otel_metrics` | `ss4o_*` |
| **Cost Allocation** | `ss4o_metric-default-namespace` | - |

All indices serve specific purposes. Choose based on your use case!
