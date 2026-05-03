# Labels Summary - Comprehensive Resource Attributes

This document lists all labels applied to telemetry data in the monitoring stack.

## Label Categories

### 1. Static Labels (const_labels in Prometheus Exporter)

| Label | Value | Description |
|-------|-------|-------------|
| `continent` | north-america | Geographic continent |
| `country` | us | Country code |
| `provider` | on-premise | Infrastructure provider |
| `runtime` | collector | Runtime environment |
| `telemetry_type` | prometheus | Telemetry backend type |
| `deployment_stage` | production | Deployment stage |
| `monitoring_enabled` | true | Monitoring status flag |
| `data_lake` | opensearch | Data storage backend |
| `grafana_tenant` | default | Grafana tenant ID |
| `sla_level` | gold | Service level agreement tier |
| `business_unit` | platform | Business organization unit |
| `business_line` | observability | Business product line |

### 2. Resource Detection Labels (via resource processor)

| Label | Source | Example |
|-------|--------|---------|
| `cluster` | Resource Processor | monitoring-stack |
| `datacenter` | Resource Processor | us-west-1 |
| `region` | Resource Processor | us-west |
| `team` | Resource Processor | platform |
| `cost_center` | Resource Processor | engineering |
| `department` | Resource Processor | engineering |
| `organization` | Resource Processor | observability |
| `monitoring_tier` | Resource Processor | production |
| `infrastructure` | Resource Processor | docker |
| `platform_type` | Resource Processor | linux |

### 3. System Detector Labels

| Label | Source | Example |
|-------|--------|---------|
| `host_name` | System Detector | e3b7139ca07a (container ID) |
| `os_type` | System Detector | linux |
| `host_arch` | System Detector | amd64 |

### 4. Docker Detector Labels

| Label | Source | Description |
|-------|--------|-------------|
| `container.id` | Docker Detector | Container ID |
| `container.name` | Docker Detector | Container name |
| `container.image.name` | Docker Detector | Image name |
| `container.image.tag` | Docker Detector | Image tag |

### 5. Application/Process Labels (from OTLP)

| Label | Source | Example |
|-------|--------|---------|
| `service_name` | Application | customer, driver, frontend |
| `service_instance` | Application | customer-0 |
| `service_version` | Application | 0.0.1-SNAPSHOT |
| `telemetry_sdk_name` | Application | opentelemetry |
| `telemetry_sdk_language` | Application | java |
| `telemetry_sdk_version` | Application | 1.39.0 |
| `telemetry_distro_name` | Application | opentelemetry-java-instrumentation |
| `telemetry_distro_version` | Application | 2.5.0 |
| `process_pid` | Application | 219022 |
| `process_executable_path` | Application | /usr/lib/jvm/java-21-openjdk-amd64/bin/java |
| `process_command_args` | Application | [Full command line] |
| `process_runtime_name` | Application | OpenJDK Runtime Environment |
| `process_runtime_version` | Application | 21.0.10+7-Ubuntu-122.04 |
| `process_runtime_description` | Application | Ubuntu OpenJDK 64-Bit Server VM |

### 6. SpanMetrics Connector Dimensions

| Label | Description |
|-------|-------------|
| `http_method` | HTTP method (GET, POST, etc.) |
| `http_scheme` | HTTP scheme (http, https) |
| `http_status_code` | HTTP status code |
| `http_route` | HTTP route pattern |
| `http.host` | HTTP host header |
| `http.target` | HTTP target path |
| `net.host.name` | Remote host name |
| `net.host.port` | Remote host port |
| `net.peer.name` | Peer name |
| `net.peer.port` | Peer port |
| `net.transport` | Transport protocol (tcp, udp) |
| `net.sock.peer.addr` | Peer socket address |
| `net.sock.peer.port` | Peer socket port |
| `span_kind` | Span kind (client, server, internal, etc.) |
| `span_name` | Span name |
| `status_code` | Span status code |
| `db.name` | Database name |
| `db.system` | Database system (mysql, postgres, etc.) |
| `db.operation` | Database operation |
| `rpc.system` | RPC system (grpc, etc.) |
| `rpc.service` | RPC service name |
| `rpc.method` | RPC method name |
| `messaging.system` | Messaging system (kafka, etc.) |
| `messaging.destination` | Messaging destination |
| `peer.service` | Peer service name |
| `code.namespace` | Code namespace |
| `code.function` | Code function |
| `thread.id` | Thread ID |
| `thread.name` | Thread name |

### 7. ServiceGraph Connector Labels

| Label | Description |
|-------|-------------|
| `client` | Client service name |
| `server` | Server service name |
| `connection_type` | Connection type (messaging, virtual_node) |
| `failed` | Request failed status (true/false) |
| `virtual_node` | Virtual node indicator |

### 8. OpenTelemetry Internal Labels

| Label | Description |
|-------|-------------|
| `otel_scope_name` | OTEL component name |
| `otel_scope_schema_url` | Schema URL |
| `otel_scope_version` | Component version |

### 9. Prometheus Receiver Labels

| Label | Description | Example |
|-------|-------------|---------|
| `job` | Scrape job name | node-exporter |
| `instance` | Target address | node-exporter:9100 |
| `server_address` | Server address | node-exporter |
| `server_port` | Server port | 9100 |
| `url_scheme` | URL scheme | http |
| `service_instance_id` | Service instance ID | node-exporter:9100 |
| `service_name` | Service name | node-exporter |

## Total Label Count

By label source:
- **Static labels**: 12
- **Resource processor labels**: 10
- **System detector labels**: 3
- **Docker detector labels**: 4
- **Application/Process labels**: 14+
- **Span dimensions**: 30+
- **ServiceGraph labels**: 5
- **OTEL internal labels**: 3
- **Prometheus receiver labels**: 7

**Total**: 88+ labels available across all metrics!

## Example Metrics with All Labels

### SpanMetrics Example
```promql
traces_span_metrics_calls_total{
  business_line="observability",
  business_unit="platform",
  cluster="monitoring-stack",
  continent="north-america",
  cost_center="engineering",
  country="us",
  data_lake="opensearch",
  datacenter="us-west-1",
  department="engineering",
  deployment_stage="production",
  grafana_tenant="default",
  host_name="e3b7139ca07a",
  http_method="unknown",
  http_scheme="http",
  http_status_code="",
  infrastructure="docker",
  job="customer",
  monitoring_enabled="true",
  monitoring_tier="production",
  net_transport="tcp",
  organization="observability",
  os_type="linux",
  otel_scope_name="spanmetricsconnector",
  platform_type="linux",
  provider="on-premise",
  region="us-west",
  runtime="collector",
  service_instance="customer-0",
  service_name="customer",
  sla_level="gold",
  span_kind="SPAN_KIND_CLIENT",
  span_name="HTTP GET",
  status_code="STATUS_CODE_UNSET",
  team="platform",
  telemetry_sdk_name="opentelemetry",
  telemetry_type="prometheus"
}
```

### ServiceGraph Example
```promql
traces_service_graph_request_total{
  business_line="observability",
  business_unit="platform",
  client="customer",
  cluster="monitoring-stack",
  connection_type="",
  continent="north-america",
  cost_center="engineering",
  country="us",
  data_lake="opensearch",
  datacenter="us-west-1",
  department="engineering",
  deployment_stage="production",
  failed="false",
  grafana_tenant="default",
  host_name="e3b7139ca07a",
  infrastructure="docker",
  monitoring_enabled="true",
  monitoring_tier="production",
  organization="observability",
  os_type="linux",
  otel_scope_name="traces_service_graph",
  platform_type="linux",
  provider="on-premise",
  region="us-west",
  runtime="collector",
  server="mysql",
  sla_level="gold",
  team="platform",
  telemetry_type="prometheus",
  virtual_node=""
}
```

### Node Exporter Example
```promql
node_cpu_seconds_total{
  business_line="observability",
  business_unit="platform",
  cluster="monitoring-stack",
  continent="north-america",
  cost_center="engineering",
  country="us",
  cpu="0",
  data_lake="opensearch",
  datacenter="us-west-1",
  department="engineering",
  deployment_stage="production",
  grafana_tenant="default",
  host_name="e3b7139ca07a",
  infrastructure="docker",
  instance="node-exporter:9100",
  job="node-exporter",
  mode="idle",
  monitoring_enabled="true",
  monitoring_tier="production",
  organization="observability",
  os_type="linux",
  otel_scope_name="github.com/.../prometheusreceiver",
  otel_scope_version="0.131.0",
  platform_type="linux",
  provider="on-premise",
  region="us-west",
  runtime="collector",
  server_address="node-exporter",
  server_port="9100",
  service_instance_id="node-exporter:9100",
  service_name="node-exporter",
  sla_level="gold",
  team="platform",
  telemetry_type="prometheus",
  url_scheme="http"
}
```

## Benefits of Comprehensive Labeling

1. **Multi-dimensional Filtering**: Query by any combination of labels
2. **Cost Allocation**: Track by `cost_center`, `department`, `business_unit`
3. **Geographic Analysis**: Filter by `continent`, `country`, `region`, `datacenter`
4. **Service Ownership**: Identify by `team`, `organization`
5. **SLA Tracking**: Monitor by `sla_level`, `monitoring_tier`
6. **Environment Correlation**: Group by `cluster`, `infrastructure`, `platform_type`
7. **Performance Analysis**: Detailed span attributes for latency analysis
8. **Dependency Mapping**: Service graph with `client`/`server` labels

## Querying Examples

```promql
# All metrics for a specific team
{team="platform"}

# Metrics by datacenter
sum by (datacenter) (rate(traces_span_metrics_calls_total[5m]))

# Cost center analysis
sum by (cost_center, department) (node_cpu_seconds_total)

# SLA monitoring
{sla_level="gold", monitoring_tier="production"}

# Geographic distribution
count by (region, datacenter) (up{job="node-exporter"})

# Service dependencies
traces_service_graph_request_total{client="frontend"}

# Error rate by team
sum by (team) (rate(traces_span_metrics_calls_total{status_code="STATUS_CODE_ERROR"}[5m]))
```
