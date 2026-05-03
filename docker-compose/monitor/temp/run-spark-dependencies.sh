#!/bin/bash
# Jaeger Spark Dependencies - Service Dependency Calculator
# Calculates dependency graph from Jaeger spans stored in OpenSearch

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

# Configuration
OPENSEARCH_HOST="localhost"
OPENSEARCH_PORT="9200"
SPARK_DEPS_VERSION="${SPARK_DEPS_VERSION:-0.7.2}"
SPARK_DEPS_JAR="/tmp/spark-dependencies-${SPARK_DEPS_VERSION}.jar"
SPARK_VERSION="3.5.0"

# Default: process last 7 days
DAYS=${1:-7}

echo ""
echo "========================================="
echo "Jaeger Spark Dependencies"
echo "========================================="
echo ""
log_info "Configuration:"
echo "  - OpenSearch: http://${OPENSEARCH_HOST}:${OPENSEARCH_PORT}"
echo "  - Days to process: ${DAYS}"
echo "  - Span Index: jaeger-span"
echo "  - Dependencies Index: jaeger-dependencies"
echo ""

# Check if OpenSearch is accessible
log_info "Checking OpenSearch connection..."
if ! curl -s "http://${OPENSEARCH_HOST}:${OPENSEARCH_PORT}/_cluster/health" > /dev/null 2>&1; then
    log_error "Cannot connect to OpenSearch at http://${OPENSEARCH_HOST}:${OPENSEARCH_PORT}"
    exit 1
fi
log_success "OpenSearch is accessible"

# Check span indices
log_info "Checking Jaeger span indices..."
SPAN_INDICES=$(curl -s "http://${OPENSEARCH_HOST}:${OPENSEARCH_PORT}/_cat/indices/jaeger-span*?h=index" | wc -l)
if [ "$SPAN_INDICES" -eq 0 ]; then
    log_error "No jaeger-span indices found"
    exit 1
fi
log_success "Found ${SPAN_INDICES} span indices"

# Download spark-dependencies jar if not exists
if [ ! -f "$SPARK_DEPS_JAR" ]; then
    log_info "Downloading spark-dependencies ${SPARK_DEPS_VERSION}..."

    # Try GitHub releases
    DOWNLOAD_URL="https://github.com/jaegertracing/spark-dependencies/releases/download/v${SPARK_DEPS_VERSION}/spark-dependencies.jar"

    if curl -L -o "$SPARK_DEPS_JAR" "$DOWNLOAD_URL"; then
        log_success "Downloaded spark-dependencies.jar"
    else
        log_error "Failed to download from GitHub releases"
        log_info "Building from source..."

        # Clone and build
        BUILD_DIR="/tmp/spark-dependencies-build"
        if [ -d "$BUILD_DIR" ]; then
            rm -rf "$BUILD_DIR"
        fi

        git clone --depth 1 --branch "v${SPARK_DEPS_VERSION}" \
            https://github.com/jaegertracing/spark-dependencies.git "$BUILD_DIR"

        cd "$BUILD_DIR"
        make build

        cp "docker/java/target/spark-dependencies-${SPARK_DEPS_VERSION}-jar-with-dependencies.jar" "$SPARK_DEPS_JAR"

        cd -
        rm -rf "$BUILD_DIR"

        log_success "Built spark-dependencies.jar"
    fi
else
    log_info "Using existing spark-dependencies.jar"
fi

# Check if Spark is installed
if ! command -v spark-submit &> /dev/null; then
    log_warning "Apache Spark not found locally"
    log_info "Running with Docker..."

    # Run with Docker
    docker run --rm --name spark-dependencies \
        --network host \
        -e ES_HTTP_HOST="${OPENSEARCH_HOST}" \
        -e ES_HTTP_PORT="${OPENSEARCH_PORT}" \
        -e ES_TLS_SKIP_VERIFY=true \
        -e ES_INDEX_DATE_SEPARATOR=- \
        -e SPAN_INDEX=jaeger-span \
        -e DEPENDENCIES_INDEX=jaeger-dependencies \
        jaegertracing/spark-dependencies:${SPARK_DEPS_VERSION} \
        --es.http-host="${OPENSEARCH_HOST}" \
        --es.http-port="${OPENSEARCH_PORT}" \
        --es.tls.skip-verify=true \
        --es.index-date-separator=- \
        --span.index=jaeger-span \
        --dependencies.index=jaeger-dependencies \
        --days="${DAYS}"

    exit $?
fi

# Run with local Spark
log_info "Running spark-dependencies with Apache Spark..."

spark-submit \
    --class io.jaegertracing.spark.dependencies.docker.Main \
    --master "local[*]" \
    --driver-memory 1g \
    --executor-memory 1g \
    "$SPARK_DEPS_JAR" \
    --es.http-host="${OPENSEARCH_HOST}" \
    --es.http-port="${OPENSEARCH_PORT}" \
    --es.tls.skip-verify=true \
    --es.index-date-separator=- \
    --span.index=jaeger-span \
    --dependencies.index=jaeger-dependencies \
    --days="${DAYS}"

log_success "Spark dependencies job completed"

# Verify results
log_info "Checking dependencies index..."
sleep 2

DEPS_COUNT=$(curl -s "http://${OPENSEARCH_HOST}:${OPENSEARCH_PORT}/jaeger-dependencies/_count" | jq -r '.count // 0')

if [ "$DEPS_COUNT" -gt 0 ]; then
    log_success "Created ${DEPS_COUNT} dependency records"

    echo ""
    log_info "Sample dependencies:"
    curl -s "http://${OPENSEARCH_HOST}:${OPENSEARCH_PORT}/jaeger-dependencies/_search?size=5&pretty" | jq '.hits.hits[]._source // empty'

    echo ""
    log_success "Dependency graph available at:"
    echo "  - Jaeger UI: http://localhost:16686"
    echo "  - OpenSearch Dashboards: http://localhost:5601"
    echo "  - Index: jaeger-dependencies"
else
    log_warning "No dependencies found. Check span data availability."
fi

echo ""
log_success "Done!"
echo ""
