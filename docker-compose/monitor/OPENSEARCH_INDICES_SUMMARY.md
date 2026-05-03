# OpenSearch Indices - Complete Overview

## All Indices Summary

Total indices: 15
Total documents: ~8.6 million
Total storage: ~630 MB

### Index Categories

#### 1. **ss4o Custom Indices** (Your Custom Namespace)
| Index | Documents | Size | Health | Purpose |
|-------|-----------|------|--------|---------|
| `ss4o_metric-default-namespace` | 1,352 | 414.2 KB | yellow | Host metrics, container metrics, application metrics |
| `ss4o_trace-default-namespace` | 274,036 | 146.1 MB | yellow | Trace spans (from Data Prepper) |
| `ss4o_logs-default-namespace` | 297 | 365.1 KB | yellow | Container logs, application logs |

**Total ss4o**: 275,685 documents | 146.9 MB

#### 2. **Jaeger Indices** (Direct Storage)
| Index | Documents | Size | Health | Purpose |
|-------|-----------|------|--------|---------|
| `jaeger-span-2026-02-20` | 6,218,554 | 183.9 MB | yellow | Trace spans (yesterday) |
| `jaeger-span-2026-02-21` | 1,461,538 | 42.8 MB | yellow | Trace spans (today) |
| `jaeger-service-2026-02-20` | 29 | 64.5 KB | yellow | Service metadata |

**Total Jaeger**: 7,680,121 documents | 226.7 MB

#### 3. **OpenTelemetry Indices** (Data Prepper)
| Index | Documents | Size | Health | Purpose |
|-------|-----------|------|--------|---------|
| `otel-v1-apm-span-000001` | 361,367 | 137.3 MB | yellow | Trace spans (APM format) |
| `otel-v1-apm-service-map` | 48 | 24.7 KB | yellow | Service dependency graph |
| `otel_metrics` | 55,596 | 9.8 MB | yellow | Host metrics, application metrics |

**Total OTEL**: 417,011 documents | 147.1 MB

#### 4. **OpenSearch System Indices**
| Index | Documents | Size | Health | Purpose |
|-------|-----------|------|--------|---------|
| `.kibana_1` | 4 | 15.8 KB | green | Kibana/Dashboards settings |
| `.opendistro-job-scheduler-lock` | 1 | 74.6 KB | green | Job scheduler lock |
| `.plugins-ml-config` | 1 | 4 KB | green | Machine learning config |
| `.ql-datasources` | 0 | 208 B | green | Query language datasources |

#### 5. **Other Indices**
| Index | Documents | Size | Health | Purpose |
|-------|-----------|------|--------|---------|
| `top_queries-2026.02.20-95582` | 77 | 83.2 KB | green | Query history |
| `top_queries-2026.02.21-95583` | 17 | 172.6 KB | green | Query history |
| `webflux-demo-logs` | 4 | 11.9 KB | yellow | Demo application logs |

---

## Detailed Index Analysis

### ss4o_metric-default-namespace

**Purpose**: Custom metrics index with full label enrichment

**Document Count**: 1,352
**Size**: 414.2 KB
**Health**: Yellow (1 replica not assigned)

**Sample Fields**:
```json
{
  "name": "container.blockio.io_service_bytes_recursive",
  "kind": "SUM",
  "value": 483328.0,
  "unit": "By",
  "time": "2026-02-21T00:51:40.610601988Z",
  "metric.attributes.operation": "read",
  "metric.attributes.device_major": "8",
  "resource.attributes.cluster": "monitoring-stack",
  "resource.attributes.datacenter": "us-west-1",
  "resource.attributes.region": "us-west",
  "resource.attributes.team": "platform",
  "resource.attributes.cost_center": "engineering",
  "resource.attributes.container.name": "jaeger"
}
```

**Metric Types**:
- Container metrics: CPU, memory, block I/O, network
- Host metrics: Disk, filesystem, load, network
- Application metrics: OTLP from applications

### ss4o_trace-default-namespace

**Purpose**: Custom trace index via Data Prepper

**Document Count**: 274,036
**Size**: 146.1 MB
**Health**: Yellow (1 replica not assigned)

**Sample Fields**:
```json
{
  "traceId": "abc123...",
  "spanId": "def456...",
  "parentSpanId": "ghi789...",
  "spanName": "HTTP GET /customer",
  "serviceName": "customer",
  "serviceInstance": "customer-0",
  "startTime": 1234567890,
  "duration": 1500000,
  "spanKind": "SERVER",
  "statusCode": "UNSET"
}
```

### ss4o_logs-default-namespace

**Purpose**: Custom logs index

**Document Count**: 297
**Size**: 365.1 KB
**Health**: Yellow (1 replica not assigned)

**Sample Fields**:
```json
{
  "body": "Started watching file",
  "log.file.path": "/var/lib/docker/containers/.../...-json.log",
  "log_type": "docker",
  "timestamp": "2026-02-21T00:51:40.610Z",
  "resource.attributes.cluster": "monitoring-stack",
  "resource.attributes.team": "platform"
}
```

### jaeger-span-* (Daily Indices)

**Purpose**: Direct Jaeger span storage with SPM

**Total Documents**: 7,680,121
**Total Size**: 226.7 MB

**Index Pattern**: `jaeger-span-YYYY-MM-DD`
**Retention**: Daily rollover

**Sample Fields**:
```json
{
  "traceID": "abc123...",
  "spanID": "def456...",
  "operationName": "/customer",
  "serviceName": "customer",
  "startTime": 1234567890000000,
  "duration": 1500000,
  "tags": [
    {"key": "http.method", "value": "GET"},
    {"key": "http.status_code", "value": "200"}
  ]
}
```

### otel-v1-apm-span-000001

**Purpose**: APM-formatted traces from Data Prepper

**Document Count**: 361,367
**Size**: 137.3 MB
**Health**: Yellow

**Features**:
- APM span format
- Service map compatibility
- Trace Analytics support

### otel_metrics

**Purpose**: Host and application metrics via Data Prepper

**Document Count**: 55,596
**Size**: 9.8 MB
**Health**: Yellow

**Sample Metrics**:
- `system.cpu.usage`
- `system.memory.usage`
- `system.disk.io`
- `system.network.io`
- `process.cpu.total`
- `process.memory.usage`

---

## Index Health Status

| Health | Count | Indices |
|--------|-------|---------|
| **Green** | 7 | `.kibana_1`, `.opendistro-job-scheduler-lock`, `.plugins-ml-config`, `.ql-datasources`, `top_queries-2026.02.20-95582`, `top_queries-2026.02.21-95583` |
| **Yellow** | 8 | `jaeger-*`, `otel-*`, `ss4o_*`, `webflux-demo-logs` |

**Note**: Yellow status indicates replica shards are not assigned. This is normal for single-node clusters.

---

## Index Patterns

| Pattern | Indices | Description |
|---------|---------|-------------|
| `jaeger-span-*` | Daily time-series | Trace spans |
| `ss4o_*-default-namespace` | 3 indices | Custom observability data |
| `otel-v1-apm-*` | Rollup | APM traces and service map |
| `otel_metrics` | Single | Metrics (no rollover configured) |

---

## Data Flow Verification

### Traces
```
Application → OTEL Collector (4317/4318)
    ↓
[Jaeger (4317)] → jaeger-span-* (7.68M docs)
    ↓
[Data Prepper (21890)] → otel-v1-apm-span-* (361K docs)
                        → ss4o_trace-default-namespace (274K docs)
```

### Metrics
```
[Host Metrics] → OTEL Collector → Data Prepper (21891)
[Docker Stats] → OTEL Collector → Data Prepper (21891)
[Node Exporter] → OTEL Collector → Prometheus
[OTLP Metrics] → OTEL Collector → Data Prepper (21891)
                                      ↓
                                otel_metrics (55K docs)
                                ss4o_metric-default-namespace (1.3K docs)
                                Prometheus (real-time scraping)
```

### Logs
```
[Container Logs] → OTEL Collector (filelog)
[OTLP Logs] → OTEL Collector (otlp)
                    ↓
              ss4o_logs-default-namespace (297 docs)
```

---

## Query Examples

### Count all documents by index pattern
```bash
# ss4o indices
curl -s "http://localhost:9200/ss4o_*/_count?pretty"

# Jaeger spans
curl -s "http://localhost:9200/jaeger-span-*/_count?pretty"

# All indices
curl -s "http://localhost:9200/_cat/indices?v"
```

### Search specific index
```bash
# ss4o traces
curl -s "http://localhost:9200/ss4o_trace-default-namespace/_search?pretty&size=1"

# ss4o metrics
curl -s "http://localhost:9200/ss4o_metric-default-namespace/_search?pretty&size=1"

# ss4o logs
curl -s "http://localhost:9200/ss4o_logs-default-namespace/_search?pretty&size=1"
```

### Aggregate by index
```bash
curl -s "http://localhost:9200/_cat/indices?v&h=index,docs.count,store.size" | sort -k2 -rn
```

---

## Storage Summary

| Category | Documents | Size | Percentage |
|----------|-----------|------|------------|
| **Jaeger Traces** | 7,680,121 | 226.7 MB | 36% |
| **OTel Traces** | 361,367 | 137.3 MB | 22% |
| **ss4o Traces** | 274,036 | 146.1 MB | 23% |
| **OTel Metrics** | 55,596 | 9.8 MB | 2% |
| **ss4o Metrics** | 1,352 | 414.2 KB | <1% |
| **ss4o Logs** | 297 | 365.1 KB | <1% |
| **Other** | 180 | 108 KB | <1% |

**Total**: 8,672,949 documents | ~630 MB

---

## Verification Commands

```bash
# All indices with details
curl -s "http://localhost:9200/_cat/indices?v"

# Index health
curl -s "http://localhost:9200/_cat/indices?v&h=index,health,docs.count,store.size"

# Cluster health
curl -s "http://localhost:9200/_cluster/health?pretty"

# Nodes
curl -s "http://localhost:9200/_cat/nodes?v"

# Aliases
curl -s "http://localhost:9200/_cat/aliases?v"

# Shards
curl -s "http://localhost:9200/_cat/shards?v"
```

---

## Summary

✅ **All indices operational**
✅ **8.67M total documents** indexed
✅ **ss4o custom namespace** working for traces, metrics, and logs
✅ **Dual storage** for traces (Jaeger + ss4o)
✅ **Dual storage** for metrics (otel_metrics + ss4o_metric)
✅ **Real-time collection** from containers, hosts, and applications
