# OpenSearch PPL (Pipe Processing Language)

## 개요

PPL(Pipe Processing Language)은 OpenSearch에서 제공하는 파이프라인 기반 쿼리 언어입니다. SQL과 유사하지만 더 직관적인 문법을 제공하며, 로그 분석과 데이터 탐색에 최적화되어 있습니다.

## ppl.py 스크립트

ppl.py는 OpenSearch에서 자연어 질문을 PPL 쿼리로 변환하는 ML 에이전트를 자동 설정하는 Python 스크립트입니다.

### 실행 방법

```bash
python3 /root/ppl.py
```

### 수행 작업

1. **기존 리소스 정리**: 이전에 생성된 ML 모델, 커넥터, 에이전트 삭제
2. **ML 에이전트 생성**: 자연어 → PPL 변환 에이전트
3. **챗봇 에이전트 구성**: 대화형 질의응답 시스템

### 생성되는 리소스

| 리소스 | ID | 설명 |
|--------|-----|------|
| Chat Agent | `xk-*` | 자연어를 PPL 쿼리로 변환 |
| Chatbot Agent | `x0-*` | 사용자 질문 처리 |
| LLM Model | `xE-*` | OpenAI 기반 PPL 생성 모델 |
| ML Connector | ML 커넥터 | 외부 LLM 연결 |
| Model Group | 모델 그룹 | ML 모델 관리 |

---

## PPL 기본 문법

### 1. 기본 구조

```ppl
source = index_name
| where condition
| stats aggregation
| sort field
| fields field1, field2
```

### 2. 데이터 소스 지정

```ppl
# 전체 검색
source = my-index

# 필드 선택
source = my-index | fields timestamp, level, message
```

### 3. 필터링 (WHERE)

```ppl
# 단일 조건
source = my-index | where status = 200

# 다중 조건
source = my-index | where status = 200 and method = "GET"

# 비교 연산자
source = my-index | where response_time > 1000

# 문자열 매칭
source = my-index | where message like "error"

# 범위 검색
source = my-index | where timestamp in ["2024-01-01", "2024-01-31"]
```

### 4. 집계 (STATS)

```ppl
# 개수 세기
source = my-index | stats count()

# 고유값 카운트
source = my-index | stats count(distinct user_id)

# 합계, 평균, 최대, 최소
source = my-index | stats sum(bytes), avg(response_time), max(duration)

# 그룹별 집계
source = my-index | stats count() by status

# 다중 집계
source = my-index | stats count() as total, avg(response_time) as avg_rt by service
```

### 5. 정렬 (SORT)

```ppl
# 오름차순
source = my-index | sort timestamp

# 내림차순
source = my-index | sort -response_time

# 다중 정렬
source = my-index | sort status, -timestamp
```

### 6. 필드 선택 및 제거

```ppl
# 특정 필드만 선택
source = my-index | fields timestamp, level, message, service

# 필드 제외
source = my-index | fields -message, -debug_info
```

### 7. 시계열 분석

```ppl
# 시간 간격별 집계
source = my-index | stats count() by bin(1h)

# 5분 단위
source = my-index | stats avg(response_time) by bin(5m)

# 1일 단위
source = my-index | stats sum(bytes) by bin(1d)
```

### 8. 상위 N개 (HEAD)

```ppl
# 상위 10개
source = my-index | head 10

# 집계 후 상위 5개
source = my-index | stats count() by service | head 5
```

### 9. 중복 제거 (DEDUP)

```ppl
# 중복 제거
source = my-index | dedup transaction_id

# 최신 레코드 유지
source = my-index | dedup user_id sort -timestamp
```

---

## 실전 예제

### 예제 1: 로그 레벨별 개수

```ppl
source = logs-* | stats count() by level
```

**결과**:
```
| level    | count() |
|----------|---------|
| ERROR    | 1523    |
| WARN     | 8921    |
| INFO     | 45621   |
| DEBUG    | 124532  |
```

### 예제 2: 느린 API 요청 찾기

```ppl
source = traces-* | where duration > 1000 | fields service_name, operation_name, duration | sort -duration | head 10
```

### 예제 3: 시간대별 에러 추이

```ppl
source = logs-* | where level = "ERROR" | stats count() by bin(1h) | sort timestamp
```

### 예제 4: 서비스별 평균 응답 시간

```ppl
source = jaeger-span-* | stats avg(duration) as avg_duration, count() as total by process.serviceName | sort -avg_duration
```

### 예제 5: 특정 사용자 활동 내역

```ppl
source = access-logs | where user_id = "user123" | fields timestamp, action, resource | sort -timestamp
```

### 예제 6: 에러율 계산

```ppl
source = api-logs | stats count() as total, sum(case(status >= 500, 1, 0)) as errors by service | eval error_rate = errors / total * 100 | fields service, error_rate
```

### 예제 7: 상위 에러 메시지

```ppl
source = logs-* | where level = "ERROR" | stats count() by message | sort -count() | head 20
```

---

## OpenSearch Dashboards에서 사용

### 1. Dev Tools에서 실행

```
POST /_plugins/_ppl/_execute
{
  "query": "source = my-index | stats count() by status"
}
```

### 2. ML Chatbot 사용

ppl.py 실행 후, OpenSearch Dashboards에서:

1. **Dev Tools** → **ML** 메뉴로 이동
2. **Chat Agent** 선택
3. 자연어로 질문

**예시 질문**:
```
"ERROR 로그를 보여줘"
"서비스별 평균 응답 시간을 알려줘"
"어떤 API가 가장 느려?"
"최근 1시간 동안의 트래픽 변화를 보여줘"
```

---

## Jaeger Trace와 함께 사용

### Trace 수 분석

```ppl
source = jaeger-span-2026-03-06 | stats sum(duration) as total_duration, count() as span_count by traceID | sort -total_duration | head 10
```

### 서비스 의존성 분석

```ppl
source = jaeger-span-2026-03-06 | fields traceID, process.serviceName | dedup traceID, process.serviceName | stats count() by process.serviceName
```

### 느린 Span 찾기

```ppl
source = jaeger-span-2026-03-06 | where duration > 1000000 | fields traceID, operationName, duration, process.serviceName | sort -duration | head 20
```

### Operation별 평균 시간

```ppl
source = jaeger-span-2026-03-06 | stats avg(duration) as avg_duration, count() as total, max(duration) as max_duration by operationName | sort -avg_duration
```

---

## PPL vs SQL 비교

| 작업 | PPL | SQL |
|------|-----|-----|
| 데이터 소스 | `source = index` | `SELECT * FROM index` |
| 필터링 | `\| where condition` | `WHERE condition` |
| 집계 | `\| stats count() by field` | `SELECT count(*) FROM index GROUP BY field` |
| 정렬 | `\| sort field` | `ORDER BY field` |
| 상위 N개 | `\| head 10` | `LIMIT 10` |

---

## 성능 최적화

### 1. 시간 범위 제한

```ppl
# 좋음
source = logs-2026-03-06 | where timestamp > "2026-03-06T00:00:00"

# 나쁨 (너무 넓은 범위)
source = logs-* | stats count()
```

### 2. 필드 선택 최적화

```ppl
# 좋음 (필요한 필드만)
source = logs-* | fields timestamp, level, message | where level = "ERROR"

# 나쁨 (모든 필드)
source = logs-* | where level = "ERROR"
```

### 3. 인덱스 패턴 지정

```ppl
# 좋음 (특정 인덱스)
source = logs-prod-2026-03-06

# 나쁨 (와일드카드)
source = logs-*
```

---

## API 사용

### HTTP API로 PPL 실행

```bash
curl -X POST "localhost:9200/_plugins/_ppl/_execute" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "source = my-index | stats count() by status"
  }'
```

### Python에서 사용

```python
import requests

query = """
source = logs-* | stats count() by level
"""

response = requests.post(
    "http://localhost:9200/_plugins/_ppl/_execute",
    json={"query": query},
    headers={"Content-Type": "application/json"}
)

result = response.json()
print(result)
```

---

## 문제 해결

### 1. 에이전트가 응답하지 않음

```bash
# 에이전트 상태 확인
curl -s "http://localhost:9200/_plugins/_ml/agents/_search?pretty" \
  -H "Content-Type: application/json" \
  -d '{"size": 10}'
```

### 2. ppl.py 실행 실패

```bash
# OpenSearch 상태 확인
curl -s http://localhost:9200/_cluster/health

# ML 플러그인 확인
curl -s "http://localhost:9200/_cat/plugins" | grep ml
```

### 3. PPL 쿼리 오류

```bash
# PPL 구문 검증
POST /_plugins/_ppl/_execute
{
  "query": "source = my-index"
}
```

---

## 관련 리소스

- **OpenSearch Dashboards**: http://localhost:5601
- **PPL 공식 문서**: https://opensearch.org/docs/latest/ppl/index.html
- **ML 공통 가이드**: https://opensearch.org/docs/latest/ml-commons/index.html

---

**생성일**: 2026-03-06
**OpenSearch 버전**: 2.18
**ppl.py 위치**: /root/ppl.py
