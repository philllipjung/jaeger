#!/bin/bash
# OpenSearch vm.max_map_count 수정 스크립트

set -e

echo "=========================================="
echo "OpenSearch vm.max_map_count 수정"
echo "=========================================="
echo ""

# 현재 값 확인
CURRENT_VALUE=$(sysctl vm.max_map_count | grep -o '[0-9]*$')
echo "현재 vm.max_map_count: $CURRENT_VALUE"

if [ "$CURRENT_VALUE" -lt 262144 ]; then
    echo ""
    echo "vm.max_map_count가 너무 낮습니다. 262144로 변경합니다..."

    # 일시적 변경
    sysctl -w vm.max_map_count=262144

    # 영구적 설정 (/etc/sysctl.conf)
    if ! grep -q "vm.max_map_count=262144" /etc/sysctl.conf; then
        echo ""
        echo "영구적 설정 추가..."
        echo "vm.max_map_count=262144" >> /etc/sysctl.conf
        echo "추가 완료: /etc/sysctl.conf"
    else
        echo "이미 /etc/sysctl.conf에 설정되어 있습니다."
    fi

    echo ""
    echo "✓ 변경 완료!"
    sysctl vm.max_map_count
else
    echo ""
    echo "✓ 이미 충분한 값입니다: $CURRENT_VALUE"
fi

echo ""
echo "=========================================="
echo "OpenSearch 재시작"
echo "=========================================="

# OpenSearch 컨테이너 찾기
OPENSEARCH_CONTAINERS=$(docker ps -a --filter "name=opensearch" --format "{{.Names}}")

if [ -z "$OPENSEARCH_CONTAINERS" ]; then
    echo "OpenSearch 컨테이너를 찾을 수 없습니다."
    echo "docker-compose로 시작해주세요:"
    echo "  cd /root/jaeger/docker-compose/monitor"
    echo "  docker-compose up -d"
    exit 1
fi

echo "찾은 OpenSearch 컨테이너:"
echo "$OPENSEARCH_CONTAINERS"
echo ""

# 컨테이너 재시작
for CONTAINER in $OPENSEARCH_CONTAINERS; do
    echo "재시작: $CONTAINER"
    docker restart "$CONTAINER"
done

echo ""
echo "5초 대기..."
sleep 5

# 상태 확인
echo ""
echo "=========================================="
echo "상태 확인"
echo "=========================================="

docker ps | grep opensearch

echo ""
echo "OpenSearch 헬스 체크:"
sleep 3
curl -s http://localhost:9200/_cluster/health 2>/dev/null || echo "연결 실패 - 컨테이너가 아직 시작 중입니다"

echo ""
echo "완료!"
