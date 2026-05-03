# Java Profiling with async-profiler & OpenSearch

This system provides continuous Java profiling for server1 using async-profiler, with data stored in OpenSearch for analysis.

## Overview

```
┌─────────────────┐      ┌──────────────────┐      ┌─────────────┐
│   server1       │      │  Python          │      │  Fluent     │
│   (Java app)    │ ───▶ │  Converters      │ ───▶ │  Bit        │
│   async-profiler│      │  (enhanced.py)   │      │             │
└─────────────────┘      └──────────────────┘      └──────┬──────┘
                                                           │
                                                           ▼
                                                    ┌─────────────┐
                                                    │ OpenSearch  │
                                                    │             │
                                                    │ java-stack- │
                                                    │ traces      │
                                                    │ java-call-  │
                                                    │ trees       │
                                                    └─────────────┘
```

## Architecture

### Components

1. **async-profiler** - Java profiler agent (v4.1) attached to server1
2. **Python Converters** - Transform profiler output to enhanced JSON
3. **Fluent Bit** - Ships JSON data to OpenSearch
4. **OpenSearch** - Stores and indexes profiling data

### Data Flow

1. async-profiler captures stack samples every 10ms
2. Python scripts convert to JSON with enhanced metadata:
   - `thread_id`, `thread_name` - Thread identification
   - `method`, `class`, `package` - Java code details
   - `java_packages`, `java_classes` - Unique package/class lists
3. Fluent Bit reads JSONL files and sends to OpenSearch
4. OpenSearch indexes data for fast querying

## Indices

### java-stack-traces
Full individual stack traces with frame-by-frame details.

**Document structure:**
```json
{
  "timestamp": "2026-02-23T05:00:00Z",
  "service": "server1",
  "profiler": "async-profiler",
  "profiler_version": "4.1",
  "thread_id": 413535,
  "thread_name": "reactor-http-epoll-2",
  "sample_count": 1,
  "stack_depth": 45,
  "stack": [
    {
      "raw": "io.netty.channel.epoll.EpollEventLoop.run",
      "name": "EpollEventLoop.run",
      "method": "run",
      "class": "EpollEventLoop",
      "package": "io.netty.channel.epoll",
      "type": "java",
      "is_kernel": false
    }
  ],
  "frame_types": {
    "kernel": 5,
    "java": 40
  }
}
```

### java-call-trees
Aggregated hot paths and hierarchical call trees.

**Hot Path Entry:**
```json
{
  "profile_type": "hot_path",
  "path_name": "io.netty.channel.epoll.EpollEventLoop.run",
  "sample_count": 150,
  "percentage": 45.5,
  "thread_id": 413535,
  "thread_name": "reactor-http-epoll-2",
  "method": "run",
  "class": "EpollEventLoop",
  "package": "io.netty.channel.epoll"
}
```

**Call Tree Entry:**
```json
{
  "timestamp": "2026-02-23T12:31:58.512727Z",
  "service": "server1",
  "profiler": "async-profiler",
  "profiler_version": "4.1",
  "profile_type": "call_tree",
  "total_samples": 87,
  "total_traces": 31,
  "unique_packages": 69,
  "unique_classes": 197,
  "java_packages": [
    "io.netty.channel",
    "io.netty.channel.epoll",
    "io.netty.handler.codec",
    "org.springframework.web",
    "reactor.core.publisher"
  ],
  "java_classes": [
    "EpollEventLoop",
    "AbstractChannel",
    "HttpServerHandler",
    "DispatcherHandler",
    "MonoFlatMap"
  ],
  "call_tree": {
    "name": "root",
    "sample_count": 87,
    "percentage": 25.16,
    "children": [
      {
        "name": "io.netty.channel.epoll.EpollEventLoop.run",
        "sample_count": 63,
        "percentage": 39.6,
        "thread_id": 413535,
        "thread_name": "reactor-http-epoll-2",
        "children": []
      }
    ]
  }
}
```

## File Locations

### Profiling Scripts
```
/root/webflux-demo/server1/
├── run-with-detailed-profiling.sh    # Main profiling launcher
├── async-profiler-enhanced.py         # Stack trace converter
├── build-call-tree.py                 # Call tree builder
└── extract-java-hotpaths.py           # Hot path extractor

/root/async-profiler-4.1-linux-x64/
└── bin/asprof                         # async-profiler binary
```

### Output Files
```
/root/jaeger/docker-compose/monitor/profiles-java/
├── stack-traces.jsonl                 # Full stack traces
└── call-trees.jsonl                   # Hot paths + call trees
```

### Configuration
```
/root/jaeger/docker-compose/monitor/
├── fluent-bit-profiles-simple.conf   # Fluent Bit config
├── docker-compose-final.yml          # Service definitions
└── parsers.conf                       # JSON parser definition
```

## Usage

### Start Profiling

```bash
# Start server1 with profiling
cd /root/webflux-demo/server1
./run-with-detailed-profiling.sh

# Or specify PID
./run-with-detailed-profiling.sh <PID>
```

This will:
1. Attach async-profiler to server1
2. Capture data every 60 seconds
3. Convert to JSON with enhanced metadata
4. Write to stack-traces.jsonl and call-trees.jsonl

### Stop Profiling

Press `Ctrl+C` to stop the profiling script. It will automatically stop the profiler.

### Generate Load for Testing

```bash
# Generate traffic to server1 (port 8081)
for i in {1..100}; do
  curl -s "http://localhost:8081/api/data" &
done

# Continuous load
while true; do
  curl -s "http://localhost:8081/api/data"
  sleep 0.1
done
```

## Configuration

### Sampling Interval

Edit `run-with-detailed-profiling.sh`:
```bash
CPU_INTERVAL="10ms"  # Default: 10ms
DUMP_INTERVAL="60s"  # Default: 60s
```

### Call Tree Depth

Edit `build-call-tree.py`:
```python
def tree_to_list(node, path=None, max_depth=5):  # Default: 5
    ...
```

### Buffer Sizes

Edit `fluent-bit-profiles-simple.conf`:
```ini
Buffer_Chunk_Size 10MB    # Default: 5MB
Buffer_Max_Size   10MB    # Default: 10MB
```

## OpenSearch Queries

### Find hottest methods by CPU time

```json
GET /java-call-trees/_search
{
  "size": 10,
  "query": {
    "bool": {
      "must": [
        {"term": {"profile_type": "hot_path"}},
        {"range": {"sample_count": {"gte": 10}}}
      ]
    }
  },
  "sort": [{"sample_count": "desc"}]
}
```

### Find stack traces for specific thread

```json
GET /java-stack-traces/_search
{
  "size": 20,
  "query": {
    "term": {
      "thread_name": "reactor-http-epoll-2"
    }
  },
  "sort": [{"@timestamp": "desc"}]
}
```

### Find traces with specific Java class

```json
GET /java-stack-traces/_search
{
  "size": 50,
  "query": {
    "wildcard": {
      "stack.raw": "*EpollEventLoop*"
    }
  }
}
```

### Get top packages by CPU usage

```json
GET /java-call-trees/_search
{
  "size": 0,
  "aggs": {
    "top_packages": {
      "terms": {
        "field": "package.keyword",
        "size": 10
      }
    }
  }
}
```

### Find idle JVM threads

```json
GET /java-call-trees/_search
{
  "size": 20,
  "query": {
    "wildcard": {
      "thread_name": "*VM*"
    }
  }
}
```

### Find profiles with specific Java package

```json
GET /java-call-trees/_search
{
  "size": 10,
  "query": {
    "wildcard": {
      "java_packages": "*netty*"
    }
  },
  "sort": [{"timestamp": "desc"}]
}
```

### Aggregate hot paths by package

```json
GET /java-call-trees/_search
{
  "size": 0,
  "query": {"term": {"profile_type": "hot_path"}},
  "aggs": {
    "by_package": {
      "terms": {
        "field": "package.keyword",
        "size": 20
      }
    }
  }
}
```

### Find classes from specific package

```json
GET /java-call-trees/_search
{
  "size": 1,
  "query": {
    "wildcard": {
      "java_packages": "*reactor*"
    }
  }
}
```

### Get all unique packages for a time range

```json
GET /java-call-trees/_search
{
  "size": 1,
  "query": {
    "range": {
      "timestamp": {
        "gte": "now-1h"
      }
    }
  },
  "_source": false,
  "aggs": {
    "unique_packages": {
      "terms": {
        "field": "java_packages.keyword",
        "size": 100
      }
    }
  }
}
```

## Field Reference

### Common Fields (both indices)

| Field | Type | Description |
|-------|------|-------------|
| `timestamp` | string | ISO 8601 timestamp |
| `service` | string | Service name (server1) |
| `profiler` | string | Profiler name (async-profiler) |
| `profiler_version` | string | Version (4.1) |
| `thread_id` | integer | Native thread ID |
| `thread_name` | string | Thread name |

### Stack Trace Fields

| Field | Type | Description |
|-------|------|-------------|
| `stack` | array | Array of frame objects |
| `stack_depth` | integer | Number of frames |
| `sample_count` | integer | Number of samples |
| `frame_types` | object | Counts by type (kernel/java/native) |
| `has_kernel_frames` | boolean | Contains kernel frames |
| `has_java_frames` | boolean | Contains Java frames |

### Call Tree Fields

| Field | Type | Description |
|-------|------|-------------|
| `profile_type` | string | "call_tree" or "hot_path" |
| `total_samples` | integer | Total samples in this profile |
| `total_traces` | integer | Total unique call paths |
| `unique_packages` | integer | Count of unique Java packages |
| `unique_classes` | integer | Count of unique Java classes |
| `java_packages` | array | List of unique Java package names |
| `java_classes` | array | List of unique Java class names |
| `path_name` | string | Top function name (hot paths) |
| `sample_count` | integer | Samples for this path |
| `self_samples` | integer | Samples at leaf (active execution) |
| `percentage` | float | Percentage of total |
| `depth` | integer | Call depth |
| `path` | array | Call path array (no "root" included) |
| `call_tree` | object | Nested tree structure |

### Frame Object Fields

| Field | Type | Description |
|-------|------|-------------|
| `raw` | string | Original frame string |
| `name` | string | Frame name |
| `method` | string | Method name (Java frames) |
| `class` | string | Class name (Java frames) |
| `package` | string | Package name (Java frames) |
| `type` | string | "java", "kernel", "native" |
| `is_kernel` | boolean | Is kernel frame |

## Troubleshooting

### No Java code in hot paths

**Problem**: Hot paths show only kernel/idle functions like `__futex_abstimed_wait_cancelable64`.

**Solution**: Generate sustained load on the application:
```bash
# Continuous traffic
while true; do curl http://localhost:8081/api/data; sleep 0.1; done
```

### Documents show "log" field with garbage

**Problem**: OpenSearch documents have truncated JSON in `log` field.

**Solution**:
1. Increase buffer sizes in `fluent-bit-profiles-simple.conf`
2. Reduce call tree depth in `build-call-tree.py`
3. Delete corrupted documents:
```bash
curl -X POST "http://localhost:9200/java-call-trees/_delete_by_query" \
  -H 'Content-Type: application/json' \
  -d '{"query":{"bool":{"must":{"wildcard":{"log":"*"}}}}}'
```

### Fluent Bit not reading files

**Problem**: No new documents in OpenSearch.

**Solution**:
1. Check Fluent Bit is running:
```bash
docker ps | grep fluent-bit
```

2. Check Fluent Bit logs:
```bash
docker logs fluent-bit-profiles --tail 100
```

3. Verify file paths match between config and actual location.

### Profiler not capturing data

**Problem**: Output files not growing.

**Solution**:
1. Verify server1 is running:
```bash
jps -ml | grep server1
```

2. Check profiler is attached:
```bash
ps aux | grep asprof
```

3. Manually dump profiler data:
```bash
/root/async-profiler-4.1-linux-x64/bin/asprof dump -o collapsed -f /tmp/test.txt $(jps -ml | grep server1 | awk '{print $1}')
```

## Performance Impact

### Overhead

- **CPU**: ~1-3% overhead with 10ms sampling
- **Memory**: ~50-100MB for profiler buffers
- **Disk**: ~1-5MB/min per index under load

### Optimization Tips

1. **Increase sampling interval** for lower overhead:
   ```bash
   CPU_INTERVAL="50ms"  # Less frequent sampling
   ```

2. **Reduce dump frequency**:
   ```bash
   DUMP_INTERVAL="300s"  # Dump every 5 minutes
   ```

3. **Filter frames** to reduce document size

## Related Documentation

- [async-profiler GitHub](https://github.com/async-profiler/async-profiler)
- [Fluent Bit Documentation](https://docs.fluentbit.io/)
- [OpenSearch Documentation](https://opensearch.org/docs/)

## Support

For issues or questions:
1. Check this README first
2. Review logs in `/var/log/otel-collector/`
3. Check Fluent Bit logs: `docker logs fluent-bit-profiles`
4. Verify async-profiler output in `/tmp/java-profiling/`
