#!/bin/bash
# Spark Dependencies 실행 스크립트
# 진행 상황을 모니터링하고 결과를 확인합니다

set -e

echo "=========================================="
echo "Jaeger Spark Dependencies 실행"
echo "=========================================="
echo ""

# 설정
OPENSEARCH_HOST="localhost"
OPENSEARCH_PORT="9200"
SPAN_INDEX="jaeger-span"
DEPS_INDEX="jaeger-dependencies"
DAYS=${1:-7}  # 기본 7일

JAR_PATH="/tmp/spark-deps-build/spark-dependencies/jaeger-spark-dependencies-opensearch/target/jaeger-spark-dependencies-opensearch-0.0.1-SNAPSHOT.jar"

echo "설정:"
echo "  - OpenSearch: $OPENSEARCH_HOST:$OPENSEARCH_PORT"
echo "  - Span Index: $SPAN_INDEX"
echo "  - Dependencies Index: $DEPS_INDEX"
echo "  - 기간: 최근 $DAYS 일"
echo ""

# 인덱스 확인
echo "인덱스 확인 중..."
FOUND_INDICES=0
for i in $(seq 0 $((DAYS-1))); do
    DATE=$(date -d "$i days ago" +%Y-%m-%d)
    INDEX="$SPAN_INDEX-$DATE"

    if curl -s "http://${OPENSEARCH_HOST}:${OPENSEARCH_PORT}/${INDEX}" > /dev/null 2>&1; then
        COUNT=$(curl -s "http://${OPENSEARCH_HOST}:${OPENSEARCH_PORT}/${INDEX}/_count" | grep -o '"count":[0-9]*' | cut -d: -f2)
        echo "  ✓ $INDEX: $COUNT spans"
        FOUND_INDICES=$((FOUND_INDICES + 1))
    fi
done

if [ $FOUND_INDICES -eq 0 ]; then
    echo "❌ span 인덱스를 찾을 수 없습니다!"
    exit 1
fi

echo ""
echo "=========================================="
echo "Spark Dependencies 시작"
echo "=========================================="
echo ""

# Spark 실행
START_TIME=$(date +%s)

java \
  --add-opens=java.base/java.lang=ALL-UNNAMED \
  --add-opens=java.base/java.lang.invoke=ALL-UNNAMED \
  --add-opens=java.base/java.lang.reflect=ALL-UNNAMED \
  --add-opens=java.base/java.io=ALL-UNNAMED \
  --add-opens=java.base/java.net=ALL-UNNAMED \
  --add-opens=java.base/java.nio=ALL-UNNAMED \
  --add-opens=java.base/java.util=ALL-UNNAMED \
  --add-opens=java.base/java.util.concurrent=ALL-UNNAMED \
  --add-opens=java.base/sun.nio.ch=ALL-UNNAMED \
  -Djdk.reflect.useDirectMethodHandle=false \
  -Dorg.apache.logging.log4j.simplelog.StatusLogger.level=OFF \
  -Dorg.apache.logging.log4j.simplelog.ShowDateTime=true \
  -jar "$JAR_PATH" \
  --es.http-host="$OPENSEARCH_HOST" \
  --es.http-port="$OPENSEARCH_PORT" \
  --es.tls.skip-verify=true \
  --es.index-date-separator=- \
  --span.index="$SPAN_INDEX" \
  --dependencies.index="$DEPS_INDEX" \
  --days="$DAYS" \
  2>&1 | grep -v "^ERROR StatusLogger" || true

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo ""
echo "=========================================="
echo "실행 완료! (소요 시간: ${DURATION}초)"
echo "=========================================="
echo ""

# 결과 확인
sleep 3

# 오늘 날짜의 dependencies 인덱스 확인
TODAY=$(date +%Y-%m-%d)
DEPS_INDEX_DATE="$DEPS_INDEX-$TODAY"

if curl -s "http://${OPENSEARCH_HOST}:${OPENSEARCH_PORT}/${DEPS_INDEX_DATE}" > /dev/null 2>&1; then
    DEPS_COUNT=$(curl -s "http://${OPENSEARCH_HOST}:${OPENSEARCH_PORT}/${DEPS_INDEX_DATE}/_count" | grep -o '"count":[0-9]*' | cut -d: -f2)

    echo "✓ 의존성 인덱스 생성 완료!"
    echo "  인덱스: $DEPS_INDEX_DATE"
    echo "  문서 수: $DEPS_COUNT"
    echo ""

    # 의존성 데이터 조회 (JSON 파싱 없이)
    echo "=========================================="
    echo "서비스 의존성 목록"
    echo "=========================================="

    # JSON에서 dependencies 배열 추출
    curl -s "http://${OPENSEARCH_HOST}:${OPENSEARCH_PORT}/${DEPS_INDEX_DATE}/_search?size=1" | \
        grep -o '"parent":"[^"]*","child":"[^"]*","callCount":[0-9]*' | \
        sed 's/"parent":"//g' | sed 's/","child":"/ -> /g' | sed 's/","callCount":"/ (calls: /g' | sed 's/"$//)/'

    echo ""
    echo "=========================================="
    echo "의존성 그래프 확인"
    echo "=========================================="
    echo "  - Jaeger UI: http://localhost:16686/dependencies"
    echo "  - OpenSearch Dashboards: http://localhost:5601"
    echo "  - API: http://localhost:16686/api/dependencies"
    echo ""

else
    echo "⚠ 의존성 인덱스를 찾을 수 없습니다"
    echo "  예상 인덱스: $DEPS_INDEX_DATE"
    echo ""
    echo "생성된 인덱스 목록:"
    curl -s "http://${OPENSEARCH_HOST}:${OPENSEARCH_PORT}/_cat/indices/$DEPS_INDEX*?v"
    echo ""
fi

echo "=========================================="
