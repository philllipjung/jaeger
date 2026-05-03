# OpenSearch Search Queries for Java Profiles

## Quick Reference

### 1. Basic Count Queries

```bash
# Total number of profiles
curl -s "localhost:9200/java-profiles/_count?pretty"

# Count by profile type
curl -s "localhost:9200/java-profiles/_search?pretty" -H "Content-Type: application/json" -d '{
  "size": 0,
  "aggs": {
    "by_type": {
      "terms": {
        "field": "profile_type.keyword"
      }
    }
  }
}'
```

### 2. Search by Profile Type

```bash
# Find all 'flat' profiles (method-level statistics)
curl -s "localhost:9200/java-profiles/_search?pretty" -H "Content-Type: application/json" -d '{
  "query": {
    "term": {
      "profile_type.keyword": "flat"
    }
  },
  "size": 5
}'

# Find all 'collapsed' profiles (stack traces)
curl -s "localhost:9200/java-profiles/_search?pretty" -H "Content-Type: application/json" -d '{
  "query": {
    "term": {
      "profile_type.keyword": "collapsed"
    }
  },
  "size": 5
}'
```

### 3. Time Range Queries

```bash
# Profiles from last 1 hour
curl -s "localhost:9200/java-profiles/_search?pretty" -H "Content-Type: application/json" -d '{
  "query": {
    "range": {
      "@timestamp": {
        "gte": "now-1h"
      }
    }
  },
  "size": 10
}'

# Profiles from specific time range
curl -s "localhost:9200/java-profiles/_search?pretty" -H "Content-Type: application/json" -d '{
  "query": {
    "range": {
      "@timestamp": {
        "gte": "2026-02-23T03:00:00",
        "lte": "2026-02-23T04:00:00"
      }
    }
  },
  "size": 10
}'
```

### 4. Full Text Search

```bash
# Search for specific method name
curl -s "localhost:9200/java-profiles/_search?pretty" -H "Content-Type: application/json" -d '{
  "query": {
    "match": {
      "method": "EpollEventLoop"
    }
  },
  "size": 5
}'

# Search in log field
curl -s "localhost:9200/java-profiles/_search?pretty" -H "Content-Type: application/json" -d '{
  "query": {
    "match": {
      "log": "okhttp"
    }
  },
  "size": 5
}'
```

### 5. Range Queries

```bash
# Profiles with sample count > 5
curl -s "localhost:9200/java-profiles/_search?pretty" -H "Content-Type: application/json" -d '{
  "query": {
    "range": {
      "total_samples": {
        "gt": 5
      }
    }
  },
  "size": 10
}'

# Profiles with stack depth > 20
curl -s "localhost:9200/java-profiles/_search?pretty" -H "Content-Type: application/json" -d '{
  "query": {
    "range": {
      "stack_depth": {
        "gte": 20
      }
    }
  },
  "size": 5
}'
```

### 6. Aggregation Queries

```bash
# Top 10 methods by occurrence
curl -s "localhost:9200/java-profiles/_search?pretty" -H "Content-Type: application/json" -d '{
  "size": 0,
  "aggs": {
    "top_methods": {
      "terms": {
        "field": "method.keyword",
        "size": 10
      }
    }
  }
}'

# Profile type distribution
curl -s "localhost:9200/java-profiles/_search?pretty" -H "Content-Type: application/json" -d '{
  "size": 0,
  "aggs": {
    "by_type": {
      "terms": {
        "field": "profile_type.keyword"
      }
    }
  }
}'

# Average stack depth
curl -s "localhost:9200/java-profiles/_search?pretty" -H "Content-Type: application/json" -d '{
  "size": 0,
  "aggs": {
    "avg_depth": {
      "avg": {
        "field": "stack_depth"
      }
    }
  }
}'
```

### 7. Boolean Queries (AND/OR/NOT)

```bash
# Profiles with stack_depth > 30 AND profile_type = collapsed
curl -s "localhost:9200/java-profiles/_search?pretty" -H "Content-Type: application/json" -d '{
  "query": {
    "bool": {
      "must": [
        {"range": {"stack_depth": {"gte": 30}}},
        {"term": {"profile_type.keyword": "collapsed"}}
      ]
    }
  },
  "size": 5
}'

# Profiles with method A OR method B
curl -s "localhost:9200/java-profiles/_search?pretty" -H "Content-Type: application/json" -d '{
  "query": {
    "bool": {
      "should": [
        {"match": {"method": "okhttp"}},
        {"match": {"method": "netty"}}
      ]
    }
  },
  "size": 5
}'
```

### 8. Retrieve Specific Fields

```bash
# Get only timestamp, method, and samples
curl -s "localhost:9200/java-profiles/_search?pretty" -H "Content-Type: application/json" -d '{
  "query": {"match_all": {}},
  "size": 5,
  "_source": ["@timestamp", "method", "total_samples", "stack_depth"]
}'
```

### 9. Pagination

```bash
# Get results 11-20
curl -s "localhost:9200/java-profiles/_search?pretty" -H "Content-Type: application/json" -d '{
  "query": {"match_all": {}},
  "from": 10,
  "size": 10
}'
```

### 10. Sort Results

```bash
# Sort by timestamp descending
curl -s "localhost:9200/java-profiles/_search?pretty" -H "Content-Type: application/json" -d '{
  "query": {"match_all": {}},
  "size": 10,
  "sort": [
    {"@timestamp": "desc"}
  ]
}'

# Sort by sample count descending
curl -s "localhost:9200/java-profiles/_search?pretty" -H "Content-Type: application/json" -d '{
  "query": {"match_all": {}},
  "size": 10,
  "sort": [
    {"total_samples": "desc"}
  ]
}'
```

---

## OpenSearch Dashboards UI

1. **Open Dashboards**: http://localhost:5601
2. **Go to Discover**
3. **Select Index Pattern**: `java-profiles*`
4. **Build Queries**:
   - Simple text search: type in the search bar
   - Field filters: Click "Add filter" → select field → operator → value
   - KQL (Kibana Query Language):
     ```
     profile_type: "flat"
     total_samples > 5
     method: "EpollEventLoop"
     @timestamp > now-1h
     ```

### KQL Examples

```javascript
// Single field
profile_type: "collapsed"

// Range
stack_depth: [20 TO 50]
total_samples >= 10

// Boolean
profile_type: "flat" AND total_samples > 5
method: "okhttp" OR method: "netty"

// Wildcard
method: *Thread*

// Exists
_exists_: stack_depth
```

## Common Use Cases

### Find hot spots (most sampled methods)
```bash
curl -s "localhost:9200/java-profiles/_search?pretty" -H "Content-Type: application/json" -d '{
  "size": 0,
  "query": {"exists": {"field": "total_samples"}},
  "aggs": {
    "top_methods": {
      "terms": {
        "field": "method.keyword",
        "size": 20
      }
    }
  }
}'
```

### Find deepest stack traces
```bash
curl -s "localhost:9200/java-profiles/_search?pretty" -H "Content-Type: application/json" -d '{
  "query": {"match_all": {}},
  "size": 10,
  "sort": [{"stack_depth": "desc"}],
  "_source": ["@timestamp", "stack_depth", "sample_count"]
}'
```

### Timeline of profiling activity
```bash
curl -s "localhost:9200/java-profiles/_search?pretty" -H "Content-Type: application/json" -d '{
  "size": 0,
  "aggs": {
    "timeline": {
      "date_histogram": {
        "field": "@timestamp",
        "fixed_interval": "1m"
      }
    }
  }
}'
```
