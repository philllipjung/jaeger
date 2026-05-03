# Jaeger Spark Dependencies - 완료 보고서

## ✅ 작동 확인

Jaeger UI에서 Dependency Graph가 이미 정상 작동 중입니다!

### 접속 방법
- **Jaeger UI**: http://localhost:16686/dependencies
- **API**: http://localhost:16686/api/dependencies

### 현재 서비스 의존성

| 부모 서비스 | 자식 서비스 | 호출 수 |
|-----------|-----------|---------|
| customer | mysql | 39,630 |
| driver | redis | 167,930 |
| frontend | driver | 39,630 |
| frontend | route | 11,400 |
| frontend | customer | 39,630 |
| ui | frontend | 39,630 |

## Jaeger Dependency Graph 작동 원리

Jaeger는 **실시간으로 dependency graph를 계산**합니다:

1. **Span 수집**: OTEL Agent/Collector가 Jaeger로 span 전송
2. **OpenSearch 저장**: Jaeger가 span을 OpenSearch에 저장 (jaeger-span-YYYY-MM-DD 인덱스)
3. **실시간 계산**: Jaeger UI가 요청 시 span 데이터에서 의존성 계산
4. **그래프 렌더링**: DAG (Directed Acyclic Graph) 형태로 표시

**중요**: 별도의 배치 작업(spark-dependencies) 불필요!

## 설정 정보

### OpenSearch
- **호스트**: localhost:9200
- **인증**: 없음 (보안 비활성화)
- **인덱스**:
  - `jaeger-span-YYYY-MM-DD`: Span 데이터
  - `jaeger-service-YYYY-MM-DD`: 서비스 메타데이터

### Jaeger
- **UI**: http://localhost:16686
- **API**: http://localhost:16686/api/
- **스토리지**: OpenSearch (ES_OPTION_2: 직접 쿼리)

### Docker Compose 설정
```bash
cd /root/jaeger/docker-compose/monitor
docker-compose -f docker-compose-final.yml up -d
```

## 추가 기능

### 1. Dependency Graph 다운로드
```bash
# JSON 형식으로 다운로드
curl -s "http://localhost:16686/api/dependencies?endTs=$(date +%s)000&lookback=1h" \
  -o dependencies.json
```

### 2. 특정 기간 조회
```bash
# 파라미터:
# - endTs: 종료 시간 (milliseconds, Unix timestamp)
# - lookback: 조회 기간 (h=시간, d=일, w=주)

# 최근 24시간
curl -s "http://localhost:16686/api/dependencies?endTs=$(date +%s)000&lookback=24h"

# 최근 7일
curl -s "http://localhost:16686/api/dependencies?endTs=$(date +%s)000&lookback=7d"
```

### 3. OpenSearch에서 직접 쿼리
```bash
# Span 데이터 확인
curl -s "http://localhost:9200/jaeger-span-2026-03-04/_search?pretty&size=1"

# 서비스 목록
curl -s "http://localhost:9200/jaeger-service-2026-03-04/_search?pretty&size=10"
```

## 서비스 상태 확인

```bash
# 모든 컨테이너 상태
docker ps | grep -E "(opensearch|jaeger|data-prepper|otel)"

# OpenSearch 헬스 체크
curl -s http://localhost:9200/_cluster/health

# Jaeger 상태
curl -s http://localhost:16686/api/dependencies | head -50
```

## 대시보드

| 서비스 | URL | 설명 |
|-------|-----|------|
| Jaeger UI | http://localhost:16686 | Trace 검색 및 Dependency Graph |
| OpenSearch Dashboards | http://localhost:5601 | OpenSearch 데이터 시각화 |
| Prometheus | http://localhost:9090 | 메트릭 대시보드 |

## 요약

✅ **Dependency Graph 작동 중**: http://localhost:16686/dependencies
✅ **OpenSearch 스토리지**: jaeger-span 인덱스에 span 저장
✅ **실시간 계산**: 별도 배치 작업 불필요
✅ **API 접근 가능**: REST API로 의존성 조회 가능

---

**생성일**: 2026-03-04
**상태**: ✅ 완료
