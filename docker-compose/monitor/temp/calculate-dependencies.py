#!/usr/bin/env python3
"""
Simple Service Dependency Calculator for Jaeger Traces
Queries OpenSearch and calculates service dependencies
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
    print(f"Checking indices: {', '.join(indices)}")

    # Aggregation query to find unique parent-child relationships
    query = {
        "size": 0,
        "aggs": {
            "dependencies": {
                "composite": {
                    "size": 10000,
                    "sources": [
                        {"parent": {"terms": {"field": "process.serviceName.keyword"}}},
                        {"child": {"terms": {"field": "references.child.process.serviceName.keyword"}}}
                    ]
                }
            }
        }
    }

    dependencies = []

    for index in indices:
        # Check if index exists
        try:
            if not requests.head(f"{OPENSEARCH_URL}/{index}").ok:
                print(f"  Index {index} not found, skipping...")
                continue
        except:
            continue

        print(f"  Querying {index}...")

        try:
            response = requests.post(f"{OPENSEARCH_URL}/{index}/_search", json=query)
            response.raise_for_status()
            data = response.json()

            # Extract dependencies
            buckets = data.get("aggregations", {}).get("dependencies", {}).get("buckets", [])
            for bucket in buckets:
                parent = bucket.get("key", {}).get("parent", "unknown")
                child = bucket.get("key", {}).get("child", "unknown")

                if parent and child and parent != child:
                    dependencies.append({
                        "parent": parent,
                        "child": child,
                        "callCount": bucket.get("doc_count", 0)
                    })

        except Exception as e:
            print(f"  Error querying {index}: {e}")
            continue

    return dependencies

def save_dependencies(dependencies):
    """Save dependencies to OpenSearch"""
    if not dependencies:
        print("No dependencies found!")
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
        if not requests.head(f"{OPENSEARCH_URL}/{DEPS_INDEX}").ok:
            requests.put(f"{OPENSEARCH_URL}/{DEPS_INDEX}", json=index_mapping)
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
        response = requests.post(f"{OPENSEARCH_URL}/_bulk", data="\n".join(map(json.dumps, bulk_data)) + "\n",
                               headers={"Content-Type": "application/x-ndjson"})
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
        by_parent[dep["parent"]].append(dep["child"])

    print("\n=== Service Dependencies ===")
    for parent, children in sorted(by_parent.items()):
        unique_children = sorted(set(children))
        print(f"{parent} -> {', '.join(unique_children)}")

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
