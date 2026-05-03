#!/bin/bash
# View Enhanced Java Profiles from OpenSearch

echo "=========================================="
echo "Java Profiles Viewer"
echo "=========================================="
echo ""

# Count total profiles with enhanced data
TOTAL=$(curl -s "localhost:9200/java-profiles/_count" | python3 -c "import sys, json; print(json.load(sys.stdin)['count'])" 2>/dev/null)

# Count profiles with profiler_version (enhanced format)
ENHANCED=$(curl -s "localhost:9200/java-profiles/_search?pretty" -H "Content-Type: application/json" -d '{
  "query": {"wildcard": {"log": "*profiler_version*"}},
  "size": 0
}' | grep -oP '"value":\s*\K\d+' | head -1)

echo "Total profiles: $TOTAL"
echo "Enhanced profiles (with detailed stack info): $ENHANCED"
echo ""

# Function to display profile
display_profile() {
    local log_json="$1"
    echo "--- Profile Details ---"
    echo "$log_json" | python3 -c '
import sys, json
d = json.load(sys.stdin)
print(f"  Timestamp: {d.get("timestamp", "N/A")}")
print(f"  Service: {d.get("service", "N/A")}")
print(f"  Profiler Version: {d.get("profiler_version", "N/A")}")
print(f"  Stack Depth: {d.get("stack_depth", "N/A")}")
print(f"  Sample Count: {d.get("sample_count", "N/A")}")
print(f"  Frame Types: {d.get("frame_types", {})}")
if d.get("java_packages"):
    print(f"  Java Packages ({len(d["java_packages"])}):")
    for pkg in d["java_packages"][:5]:
        print(f"    - {pkg}")
    if len(d["java_packages"]) > 5:
        print(f"    ... and {len(d["java_packages"]) - 5} more")
if d.get("java_classes"):
    print(f"  Java Classes ({len(d["java_classes"])}):")
    for cls in d["java_classes"][:5]:
        print(f"    - {cls}")
    if len(d["java_classes"]) > 5:
        print(f"    ... and {len(d["java_classes"]) - 5} more")
if d.get("stack"):
    print(f"  Stack Trace (first 5 frames):")
    for i, frame in enumerate(d["stack"][:5]):
        print(f"    {i+1}. {frame.get("name", frame.get("raw", "unknown"))}")
        if frame.get("method") and frame.get("class"):
            print(f"       → {frame.get("package", "")}.{frame.get("class", "")}.{frame.get("method", "")}()")
        print(f"       Type: {frame.get("type", "unknown")}")
    if len(d["stack"]) > 5:
        print(f"    ... {len(d["stack"]) - 5} more frames")
' 2>/dev/null
    echo ""
}

# Option 1: Show latest enhanced profile
echo "=== Latest Enhanced Profile ==="
LATEST_LOG=$(curl -s "localhost:9200/java-profiles/_search?pretty" -H "Content-Type: application/json" -d '{
  "query": {"wildcard": {"log": "*profiler_version*"}},
  "size": 1,
  "sort": [{"@timestamp": "desc"}],
  "_source": ["log"]
}' | python3 -c 'import sys, json; d=json.load(sys.stdin); print(d["hits"]["hits"][0]["_source"]["log"])' 2>/dev/null)

if [ -n "$LATEST_LOG" ]; then
    display_profile "$LATEST_LOG"
else
    echo "No enhanced profiles found"
fi

echo ""
echo "=========================================="
echo "Search Examples:"
echo "=========================================="
echo ""
echo "1. Search for specific Java package:"
echo '   curl -s "localhost:9200/java-profiles/_search?pretty" -H "Content-Type: application/json" -d '"'"'{
  "query": {"wildcard": {"log": "*netty*"}},
  "size": 5
}'"'"
echo ""
echo "2. Search for profiles with deep stacks (>30 frames):"
echo '   curl -s "localhost:9200/java-profiles/_search?pretty" -H "Content-Type: application/json" -d '"'"'{
  "query": {"wildcard": {"log": "*\"stack_depth\": 3*"}},
  "size": 5
}'"'"
echo ""
