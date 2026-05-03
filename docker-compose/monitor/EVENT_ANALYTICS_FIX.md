# Event Analytics 문제 해결

## 문제 상황

OpenSearch Dashboards Event Analytics에서 다음 오류 발생:
```
parseStringDataSource error
Cannot query in Event Analytics
```

## 원인 분석

### 1. PPL/SQL 플러그인 미설치

OpenSearch 2.x에서 PPL(Pipe Processing Language)은 별도 플러그인입니다.

**확인**:
```bash
curl -s "http://localhost:9200/_cat/plugins?v" | grep -E "(ppl|sql)"
```

**결과**: PPL/SQL 플러그인이 설치되어 있지 않음

### 2. 현재 설치된 플러그인

```
opensearch-ml (설치됨)
opensearch-observability (설치됨)
opensearch-sql (설치됨)
```

하지만 PPL 실행 엔드포인트가 없음.

## 해결 방법

### 옵션 1: OpenSearch Dashboards에서 직접 쿼리

**Dev Tools 사용**:
1. OpenSearch Dashboards → Dev Tools
2. Console 탭에서 일반 쿼리 실행

```json
GET /opensearch_dashboards_sample_data_logs/_search
{
  "size": 10,
  "aggs": {
    "by_response": {
      "terms": {
        "field": "response"
      }
    }
  }
}
```

### 옵션 2: ML Chatbot 사용 (ppl.py로 생성)

ppl.py가 이미 ML 에이전트를 생성했습니다:

1. **OpenSearch Dashboards → Dev Tools → ML**
2. **Chat Agent** 선택
3. 자연어 질문

**예시**:
```
"각 응답 코드별 로그 수를 보여줘"
"200 응답을 받은 요청을 보여줘"
"가장 많은 트래픽을 보내는 클라이언트 IP는?"
```

### 옵션 3: Discover 사용

1. **OpenSearch Dashboards → Discover**
2. 인덱스 패턴 선택: `opensearch_dashboards_sample_data_logs`
3. 필터 및 집계 사용

### 옵션 4: PPL 플러그인 설치 (Docker)

Docker Compose를 사용 중인 경우 PPL 플러그인을 추가:

```yaml
# docker-compose.yml 수정
opensearch:
  image: opensearchproject/opensearch:2.18.0
  environment:
    - "OPENSEARCH_PLUGIN_LIST=ml,sql,ppl"
```

또는 컨테이너 내에서 설치:
```bash
docker exec -it opensearch-node1 bash
/usr/share/opensearch/bin/opensearch-plugin install https://github.com/opensearch-project/sql-opensearch-plugin/releases/download/2.18.0.0/sql-opensearch-plugin-2.18.0.0.zip
docker restart opensearch-node1
```

## 현재 사용 가능한 기능

### 1. ML Chatbot (ppl.py로 생성됨)

**에이전트 ID**: `xk-Ow5wBaRIfWXZ5RZDr`

**사용법**:
```bash
# OpenSearch Dashboards ML API
curl -X POST "http://localhost:9200/_plugins/_ml/agents/xk-Ow5wBaRIfWXZ5RZDr/_execute" \
  -H "Content-Type: application/json" \
  -d '{
    "parameters": {
      "question": "각 응답 코드별 로그 개수를 보여줘",
      "index": "opensearch_dashboards_sample_data_logs"
    }
  }'
```

### 2. OpenSearch Query DSL

```json
POST /opensearch_dashboards_sample_data_logs/_search
{
  "size": 0,
  "aggs": {
    "response_codes": {
      "terms": {
        "field": "response",
        "size": 10
      }
    }
  }
}
```

### 3. Sample Data 확인

**인덱스**: `opensearch_dashboards_sample_data_logs`
**문서 수**: 10,000개 이상
**시간 필드**: `@timestamp`

## 권장 사항

1. **Discover 사용**: 로그 탐색에는 Discover가 가장 안정적
2. **ML Chatbot**: 자연어 쿼리 필요 시 ppl.py로 생성된 에이전트 사용
3. **Query DSL**: 복잡한 집계에는 직접 Query DSL 사용

## Event Analytics 대안

| 작업 | 대안 | 위치 |
|------|------|------|
| 로그 검색 | Discover | Dashboards 메뉴 |
| 집계 쿼리 | Dev Tools | Query DSL 사용 |
| 자연어 쿼리 | ML Chatbot | Dev Tools → ML |
| 대시보드 | Dashboard | Dashboards 메뉴 |
| 알림 | Alerting | Dashboards 메뉴 |

---

**참고**: `/root/jaeger/docker-compose/monitor/PPL_README.md`
