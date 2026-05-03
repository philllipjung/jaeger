# Complete Labels Summary - All Resource Attributes

## Executive Summary

Your monitoring stack now has **100+ labels** across all metrics!

| Metric Type | Total Labels | Unique Label Names |
|-------------|--------------|-------------------|
| **SpanMetrics** | 38 per metric | 64 unique |
| **ServiceGraph** | 32 per metric | 32 unique |
| **Node Exporter** | 36 per metric | 40+ unique |

---

## Labels by Category

### 1. Static Labels (const_labels in Prometheus Exporter)

These are added to ALL metrics:

| Label | Value | Purpose |
|-------|-------|---------|
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

### 2. Resource Processor Labels

Added via `resource/add_custom_labels` processor:

| Label | Value | Purpose |
|-------|-------|---------|
| `cluster` | monitoring-stack | Cluster identifier |
| `datacenter` | us-west-1 | Data center location |
| `region` | us-west | Geographic region |
| `team` | platform | Team ownership |
| `cost_center` | engineering | Cost allocation |
| `department` | engineering | Department |
| `organization` | observability | Organization |
| `monitoring_tier` | production | Monitoring tier |
| `infrastructure` | docker | Infrastructure type |
| `platform_type` | linux | Platform type |

### 3. System Detector Labels

From `system` detector:

| Label | Example | Purpose |
|-------|---------|---------|
| `host_name` | e3b7139ca07a | Host/container identifier |
| `os_type` | linux | Operating system |
| `host_arch` | amd64 | System architecture |
| `os_description` | Linux 6.8.0-90-generic | Full OS description |

### 4. Application/Process Labels

From applications via OTLP:

| Label | Example | Purpose |
|-------|---------|---------|
| `service_name` | customer | Service identifier |
| `service_instance` | customer-0 | Service instance |
| `service_instance_id` | 6a792c78-b87e-4f8a-b524-31c9d8dba1af | Unique instance ID |
| `service_version` | 0.0.1-SNAPSHOT | Service version |
| `telemetry_sdk_name` | opentelemetry | Telemetry SDK |
| `telemetry_sdk_language` | java | Programming language |
| `telemetry_sdk_version` | 1.39.0 | SDK version |
| `telemetry_distro_name` | opentelemetry-java-instrumentation | Distribution |
| `telemetry_distro_version` | 2.5.0 | Distribution version |
| `process_pid` | 219022 | Process ID |
| `process_executable_path` | /usr/lib/jvm/java-21-openjdk-amd64/bin/java | Executable path |
| `process_command_args` | [Full command line] | Command arguments |
| `process_runtime_name` | OpenJDK Runtime Environment | Runtime name |
| `process_runtime_version` | 21.0.10+7-Ubuntu-122.04 | Runtime version |
| `process_runtime_description` | Ubuntu OpenJDK 64-Bit Server VM | Runtime description |

### 5. SpanMetrics Connector Dimensions

**64 total unique labels** including:

#### HTTP Attributes
| Label | Description |
|-------|-------------|
| `http_method` | HTTP method (GET, POST, etc.) |
| `http_scheme` | HTTP scheme (http, https) |
| `http_status_code` | HTTP status code |
| `http_route` | HTTP route pattern |
| `http.target` | HTTP target path |
| `http.host` | HTTP host header |
| `http.user_agent` | User agent string |
| `http.client_ip` | Client IP address |
| `http.request_content_length` | Request size |
| `http.response_content_length` | Response size |
| `http.flavor` | HTTP protocol version |

#### Network Attributes
| Label | Description |
|-------|-------------|
| `net.host.name` | Remote host name |
| `net.host.port` | Remote host port |
| `net.peer.name` | Peer name |
| `net.peer.port` | Peer port |
| `net.transport` | Transport protocol (tcp, udp) |
| `net.sock.peer.addr` | Peer socket address |
| `net.sock.peer.port` | Peer socket port |
| `net.sock.host.addr` | Local socket address |
| `net.sock.host.port` | Local socket port |

#### Database Attributes
| Label | Description |
|-------|-------------|
| `db.name` | Database name |
| `db.system` | Database system (mysql, postgres, etc.) |
| `db.statement` | Database statement |
| `db.operation` | Database operation |

#### RPC Attributes
| Label | Description |
|-------|-------------|
| `rpc.system` | RPC system (grpc, etc.) |
| `rpc.service` | RPC service name |
| `rpc.method` | RPC method name |

#### Messaging Attributes
| Label | Description |
|-------|-------------|
| `messaging.system` | Messaging system (kafka, etc.) |
| `messaging.destination` | Messaging destination |
| `messaging.destination_kind` | Destination kind (topic, queue) |

#### Code Attributes
| Label | Description |
|-------|-------------|
| `code.namespace` | Code namespace |
| `code.function` | Code function |
| `code.filepath` | File path |
| `thread.id` | Thread ID |
| `thread.name` | Thread name |

#### Peer Attributes
| Label | Description |
|-------|-------------|
| `peer.service` | Peer service name |

#### FaaS/Cloud Attributes
| Label | Description |
|-------|-------------|
| `faas.execution` | FaaS execution ID |
| `faas.id` | FaaS function ID |
| `faas.trigger` | FaaS trigger type |
| `aws.lambda.invoked_arn` | Lambda function ARN |
| `cloud.account.id` | Cloud account ID |
| `cloud.region` | Cloud region |
| `cloud.zone` | Cloud availability zone |

#### End User Attributes
| Label | Description |
|-------|-------------|
| `enduser.id` | End user ID |
| `enduser.role` | End user role |
| `enduser.scope` | End user scope |

#### Container Attributes
| Label | Description |
|-------|-------------|
| `container.id` | Container ID |
| `container.name` | Container name |

#### Kubernetes Attributes
| Label | Description |
|-------|-------------|
| `k8s.pod.name` | Pod name |
| `k8s.namespace.name` | Namespace name |
| `k8s.node.name` | Node name |
| `k8s.deployment.name` | Deployment name |
| `k8s.statefulset.name` | StatefulSet name |
| `k8s.daemonset.name` | DaemonSet name |
| `k8s.job.name` | Job name |
| `k8s.cronjob.name` | CronJob name |

### 6. ServiceGraph Connector Labels

**32 total unique labels**:

| Label | Description | Example |
|-------|-------------|---------|
| `client` | Client service name | customer |
| `server` | Server service name | mysql |
| `connection_type` | Connection type | messaging, virtual_node |
| `failed` | Request failed status | true, false |
| `virtual_node` | Virtual node indicator | |

Plus all static and resource processor labels.

### 7. OpenTelemetry Internal Labels

| Label | Description |
|-------|-------------|
| `otel_scope_name` | OTEL component name |
| `otel_scope_schema_url` | Schema URL |
| `otel_scope_version` | Component version |

### 8. Prometheus Receiver Labels

| Label | Description | Example |
|-------|-------------|---------|
| `job` | Scrape job name | node-exporter |
| `instance` | Target address | node-exporter:9100 |
| `server_address` | Server address | node-exporter |
| `server_port` | Server port | 9100 |
| `url_scheme` | URL scheme | http |

---

## Label Distribution

### Per-Metric Label Count

```
SpanMetrics:      38 labels per metric
ServiceGraph:     32 labels per metric
Node Exporter:    36+ labels per metric
```

### Unique Label Names Across All Metrics

```
SpanMetrics:      64 unique label names
ServiceGraph:     32 unique label names
All Metrics:      100+ unique label names
```

---

## Example: Complete SpanMetrics Metric

```promql
traces_span_metrics_calls_total{
  business_line="observability",
  business_unit="platform",
  cluster="monitoring-stack",
  code_function="handle",
  code_namespace="com.example.controller",
  continent="north-america",
  cost_center="engineering",
  country="us",
  data_lake="opensearch",
  datacenter="us-west-1",
  department="engineering",
  deployment_stage="production",
  grafana_tenant="default",
  host_arch="amd64",
  host_name="e3b7139ca07a",
  http_method="GET",
  http_route="/customer",
  http_scheme="http",
  http_status_code="200",
  infrastructure="docker",
  instance="customer-0",
  job="customer",
  messaging_system="kafka",
  monitoring_enabled="true",
  monitoring_tier="production",
  net_transport="tcp",
  organization="observability",
  os_description="Linux 6.8.0-90-generic",
  os_type="linux",
  otel_scope_name="spanmetricsconnector",
  platform_type="linux",
  process_command_args="[...]",
  process_executable_path="/usr/lib/jvm/java-21-openjdk-amd64/bin/java",
  process_pid="219022",
  process_runtime_description="Ubuntu OpenJDK 64-Bit Server VM",
  process_runtime_name="OpenJDK Runtime Environment",
  process_runtime_version="21.0.10+7-Ubuntu-122.04",
  provider="on-premise",
  region="us-west",
  runtime="collector",
  service_instance="customer-0",
  service_instance_id="6a792c78-b87e-4f8a-b524-31c9d8dba1af",
  service_name="customer",
  service_version="0.0.1-SNAPSHOT",
  sla_level="gold",
  span_kind="SPAN_KIND_SERVER",
  span_name="HTTP GET /customer",
  status_code="STATUS_CODE_UNSET",
  team="platform",
  telemetry_distro_name="opentelemetry-java-instrumentation",
  telemetry_distro_version="2.5.0",
  telemetry_sdk_language="java",
  telemetry_sdk_name="opentelemetry",
  telemetry_sdk_version="1.39.0",
  telemetry_type="prometheus",
  thread_id="42",
  thread_name="pool-1-thread-1"
}
```

---

## Querying Examples

### Business Queries

```promql
# All costs by cost center
sum by (cost_center, department) (rate(traces_span_metrics_calls_total[5m]))

# SLA compliance
{sla_level="gold", monitoring_tier="production"}

# Team ownership
sum by (team, business_unit) (node_cpu_seconds_total)

# Geographic distribution
count by (region, datacenter) (up{job="node-exporter"})
```

### Technical Queries

```promql
# Service dependencies
traces_service_graph_request_total{client="frontend", server="customer"}

# Error rate by service
sum by (service_name) (rate(traces_span_metrics_calls_total{status_code="STATUS_CODE_ERROR"}[5m]))

# Database call analysis
traces_span_metrics_calls_total{db_system="mysql"}

# P95 latency by service
histogram_quantile(0.95, sum(rate(traces_span_metrics_duration_milliseconds_bucket[5m])) by (le, service_name))
```

### Platform Queries

```promql
# Container metrics
{container_name=~".*"}

# Kubernetes workloads
{k8s_deployment_name=~".*"}

# Cloud provider analysis
sum by (cloud_provider, cloud_region) (rate(traces_span_metrics_calls_total[5m]))
```

---

## Benefits

1. **Cost Allocation**: Track by `cost_center`, `department`, `business_unit`
2. **Geographic Analysis**: Filter by `continent`, `country`, `region`, `datacenter`
3. **Service Ownership**: Identify by `team`, `organization`
4. **SLA Tracking**: Monitor by `sla_level`, `monitoring_tier`
5. **Multi-tenant**: Isolate by `grafana_tenant`
6. **Full Observability**: Detailed code, process, and network context
7. **Cloud Native**: AWS Lambda, Kubernetes, container support
8. **Business Alignment**: Direct mapping to business structure

---

## Configuration Files

- **OTEL Collector**: `/root/jaeger/docker-compose/monitor/otel-collector-connectors.yml`
- **Documentation**: `/root/jaeger/docker-compose/monitor/LABELS_COMPLETE_SUMMARY.md`

