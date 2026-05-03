#!/usr/bin/env python3
"""
Simple Service Dependency Calculator for Jaeger Traces
Queries OpenSearch and calculates service dependencies using trace/span relationships
"""

import requests
import json
from datetime import datetime, timedelta
from collections import defaultdict

OPENSEARCH_URL = "http://localhost:9200"
SPAN_INDEX = "jaeger-span"
DEPS_INDEX = "jaeger-dependencies"

def get_span_indices(days=7):
    """Get span indices for the last N days"""
    indices = []
    for i in range(days):
        date = (datetime.now() - timedelta(days=i)).strftime("%Y-%m-%d")
        index = f"{SPAN_INDEX}-{date}"
        indices.append(index)
    return indices

def calculate_dependencies(days=7):
    """Calculate dependencies from spans"""
    print(f"Calculating dependencies for last {days} days...")

    # Get indices
    indices = get_span_indices(days)
    print(f"Checking indices: {', '.join(indices[:3])}...")

    # First, get all spans with their traceID and spanID
    # We need to find parent-child relationships within traces

    query = {
        "size": 10000,  # Maximum per request
        "_source": ["traceID", "spanID", "process.serviceName", "operationName"],
        "query": {
            "bool": {
                "must": [
                    {"exists": {"field": "traceID"}},
                    {"exists": {"field": "process.serviceName"}}
                ]
            }
        }
    }

    # Store span -> service mapping
    span_to_service = {}
    trace_spans = defaultdict(set)

    for index in indices:
        try:
            if not requests.head(f"{OPENSEARCH_URL}/{index}", timeout=5).ok:
                continue
        except:
            continue

        print(f"  Querying {index}...")

        try:
            # Search with pagination
            search_after = None
            while True:
                if search_after:
                    query["search_after"] = search_after

                response = requests.post(f"{OPENSEARCH_URL}/{index}/_search",
                                       json=query, timeout=30)
                response.raise_for_status()
                data = response.json()

                hits = data.get("hits", {}).get("hits", [])
                if not hits:
                    break

                for hit in hits:
                    source = hit.get("_source", {})
                    trace_id = source.get("traceID")
                    span_id = source.get("spanID")
                    service_name = source.get("process", {}).get("serviceName")

                    if trace_id and span_id and service_name:
                        span_to_service[span_id] = service_name
                        trace_spans[trace_id].add(span_id)

                # Check if we have more results
                if len(hits) < query["size"]:
                    break

                search_after = hits[-1].get("sort")

        except Exception as e:
            print(f"  Error querying {index}: {e}")
            continue

    # Now get spans with references to find parent-child relationships
    dependencies = defaultdict(lambda: defaultdict(set))

    for index in indices:
        try:
            if not requests.head(f"{OPENSEARCH_URL}/{index}", timeout=5).ok:
                continue
        except:
            continue

        try:
            # Query spans that have references (child spans)
            query_with_refs = {
                "size": 10000,
                "_source": ["traceID", "spanID", "process.serviceName", "references"],
                "query": {"exists": {"field": "references"}}
            }

            search_after = None
            while True:
                if search_after:
                    query_with_refs["search_after"] = search_after

                response = requests.post(f"{OPENSEARCH_URL}/{index}/_search",
                                       json=query_with_refs, timeout=30)
                response.raise_for_status()
                data = response.json()

                hits = data.get("hits", {}).get("hits", [])
                if not hits:
                    break

                for hit in hits:
                    source = hit.get("_source", {})
                    child_service = source.get("process", {}).get("serviceName")
                    refs = source.get("references", [])

                    if not child_service or not refs:
                        continue

                    for ref in refs:
                        parent_span_id = ref.get("spanID")
                        if parent_span_id and parent_span_id in span_to_service:
                            parent_service = span_to_service[parent_span_id]
                            if parent_service != child_service:
                                dependencies[parent_service][child_service].add(parent_span_id)

                if len(hits) < query_with_refs["size"]:
                    break

                search_after = hits[-1].get("sort")

        except Exception as e:
            print(f"  Error querying refs from {index}: {e}")
            continue

    # Convert to list format
    result = []
    for parent, children in dependencies.items():
        for child, parent_spans in children.items():
            result.append({
                "parent": parent,
                "child": child,
                "callCount": len(parent_spans)
            })

    return result

def save_dependencies(dependencies):
    """Save dependencies to OpenSearch"""
    if not dependencies:
        print("\nNo dependencies found!")
        return

    print(f"\nFound {len(dependencies)} dependency relationships")

    # Create index if not exists
    index_mapping = {
        "mappings": {
            "properties": {
                "parent": {"type": "keyword"},
                "child": {"type": "keyword"},
                "callCount": {"type": "long"},
                "timestamp": {"type": "date"}
            }
        }
    }

    try:
        if not requests.head(f"{OPENSEARCH_URL}/{DEPS_INDEX}", timeout=5).ok:
            requests.put(f"{OPENSEARCH_URL}/{DEPS_INDEX}", json=index_mapping, timeout=10)
            print(f"Created index: {DEPS_INDEX}")
    except Exception as e:
        print(f"Error creating index: {e}")

    # Bulk index dependencies
    bulk_data = []
    for dep in dependencies:
        bulk_data.append({"index": {"_index": DEPS_INDEX}})
        bulk_data.append({
            "parent": dep["parent"],
            "child": dep["child"],
            "callCount": dep["callCount"],
            "timestamp": datetime.now().isoformat()
        })

    try:
        bulk_body = "\n".join(map(json.dumps, bulk_data)) + "\n"
        response = requests.post(f"{OPENSEARCH_URL}/_bulk",
                               data=bulk_body,
                               headers={"Content-Type": "application/x-ndjson"},
                               timeout=60)
        response.raise_for_status()
        result = response.json()
        indexed_count = len(result.get('items', []))
        print(f"Indexed {indexed_count} dependency records")
    except Exception as e:
        print(f"Error indexing dependencies: {e}")

    # Print summary
    print("\n=== Dependency Summary ===")
    unique_services = set()
    for dep in dependencies:
        unique_services.add(dep["parent"])
        unique_services.add(dep["child"])

    print(f"Total services: {len(unique_services)}")
    print(f"Total dependencies: {len(dependencies)}")

    # Group by parent
    by_parent = defaultdict(list)
    for dep in dependencies:
        by_parent[dep["parent"]].append((dep["child"], dep["callCount"]))

    print("\n=== Service Dependencies ===")
    for parent, children in sorted(by_parent.items()):
        print(f"{parent}:")
        for child, count in sorted(children, key=lambda x: -x[1]):
            print(f"  -> {child} ({count} calls)")

if __name__ == "__main__":
    import sys

    days = int(sys.argv[1]) if len(sys.argv) > 1 else 7

    print("==========================================")
    print("Jaeger Service Dependency Calculator")
    print("==========================================")
    print()

    dependencies = calculate_dependencies(days)
    save_dependencies(dependencies)

    print()
    print("==========================================")
    print("Done! View dependencies at:")
    print(f"  - Jaeger UI: http://localhost:16686")
    print(f"  - OpenSearch Dashboards: http://localhost:5601")
    print(f"  - Index: {DEPS_INDEX}")
    print("==========================================")
