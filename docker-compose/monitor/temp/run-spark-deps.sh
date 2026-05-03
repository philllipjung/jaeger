#!/bin/bash
# Run spark-dependencies to calculate service dependencies

set -e

echo "=========================================="
echo "Running Spark Dependencies"
echo "=========================================="
echo ""

# Run spark-dependencies
docker run --rm --name spark-dependencies \
  --network host \
  spark-dependencies:opensearch \
  --es.http-host=localhost \
  --es.http-port=9200 \
  --es.tls.skip-verify=true \
  --es.index-date-separator=- \
  --span.index=jaeger-span \
  --dependencies.index=jaeger-dependencies \
  --days=7 \
  --verbose

echo ""
echo "Checking results..."

sleep 3

# Check if dependencies index was created
if curl -s "http://localhost:9200/jaeger-dependencies" > /dev/null 2>&1; then
    COUNT=$(curl -s "http://localhost:9200/jaeger-dependencies/_count" | jq -r '.count')
    echo "✓ Dependencies created: $COUNT records"

    echo ""
    echo "Sample dependencies:"
    curl -s "http://localhost:9200/jaeger-dependencies/_search?size=5&pretty" | jq '.hits.hits[]._source // empty'
else
    echo "✗ No dependencies index found"
fi

echo ""
echo "Done!"
echo ""
