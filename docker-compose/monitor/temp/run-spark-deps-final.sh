#!/bin/bash
# Run spark-dependencies with Docker and proper logging

set -e

echo "=========================================="
echo "Spark Dependencies - Service Dependency Calculator"
echo "=========================================="
echo ""

# Run with Docker and capture output
docker run --rm --name spark-dependencies \
  --network host \
  spark-dependencies:opensearch \
  --es.http-host=localhost \
  --es.http-port=9200 \
  --es.tls.skip-verify=true \
  --es.index-date-separator=- \
  --span.index=jaeger-span \
  --dependencies.index=jaeger-dependencies \
  --days=7

EXIT_CODE=$?

echo ""
echo "Exit code: $EXIT_CODE"
echo ""

# Wait for OpenSearch to index
sleep 5

# Check results
echo "=========================================="
echo "Checking Results"
echo "=========================================="

if curl -s "http://localhost:9200/jaeger-dependencies" > /dev/null 2>&1; then
    DEPS_COUNT=$(curl -s "http://localhost:9200/jaeger-dependencies/_count" | grep -o '"count":[0-9]*' | cut -d: -f2)

    echo "✓ Dependencies index created!"
    echo "  Total records: $DEPS_COUNT"
    echo ""

    echo "Sample dependency data:"
    curl -s "http://localhost:9200/jaeger-dependencies/_search?size=3&pretty" 2>/dev/null | grep -A 20 "\"_source\""

    echo ""
    echo "=========================================="
    echo "Access the dependency graph:"
    echo "  - Jaeger UI: http://localhost:16686"
    echo "  - OpenSearch Dashboards: http://localhost:5601"
    echo "  - Index: jaeger-dependencies"
    echo "=========================================="
else
    echo "✗ Dependencies index not found"
    echo ""
    echo "Checking span indices..."
    curl -s "http://localhost:9200/_cat/indices/jaeger-span*?v"
fi

echo ""
