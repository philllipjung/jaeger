# Jaeger Spark Dependencies - 설정 완료

## 📋 HOW TO CONFIG - 처음부터 설정하기

이 섹션에서는 처음부터 Jaeger Spark Dependencies를 설정하는 전체 과정을 안내합니다.

### Step 1: 사전 요구사항

```bash
# 필요한 도구 설치
apt-get update
apt-get install -y docker-compose docker.io java21-jdk maven git curl

# 버전 확인
docker --version
java -version
mvn -version
```

### Step 2: Docker Compose로 OpenSearch + Jaeger 실행

```bash
# 프로젝트 디렉토리 생성
mkdir -p /root/jaeger/docker-compose/monitor
cd /root/jaeger/docker-compose/monitor

# docker-compose-final.yml 다운로드 또는 작성
# (이미 파일이 있는 경우 생략)

# 서비스 시작
docker-compose -f docker-compose-final.yml up -d

# 상태 확인
docker ps | grep -E "(opensearch|jaeger)"
```

**예상 결과**:
```
opensearch          Up    9200->9200/tcp
jaeger              Up    16686->16686/tcp
data-prepper        Up    2021->2021/tcp
otel-collector      Up    4317->4317/tcp, 4318->4318/tcp
```

### Step 3: OpenSearch 연결 확인

```bash
# OpenSearch 헬스 체크
curl -s http://localhost:9200/_cluster/health

# 예상 응답:
# {"cluster_name":"docker-cluster","status":"yellow",...}
```

### Step 4: Spark Dependencies 소스 코드 다운로드 및 빌드

```bash
# 빌드 디렉토리
mkdir -p /tmp/spark-deps-build
cd /tmp/spark-deps-build

# 소스 코드 클론
git clone --depth 1 https://github.com/jaegertracing/spark-dependencies.git
cd spark-dependencies

# OpenSearch 모듈 빌드 (테스트 건너뜀)
export MAVEN_OPTS="-Xmx512m"
./mvnw clean package -DskipTests -Dvariant=opensearch \
    -pl jaeger-spark-dependencies-opensearch -am
```

**예상 빌드 시간**: 1-2분

**빌드 결과**:
```
jaeger-spark-dependencies-opensearch/target/
  └── jaeger-spark-dependencies-opensearch-0.0.1-SNAPSHOT.jar (247MB)
```

### Step 5: 실행 스크립트 설치

```bash
# 실행 스크립트 복사
cp /root/jaeger/docker-compose/monitor/run-spark-deps-v2.sh \
   /root/jaeger/docker-compose/monitor/run-spark-deps-v2.sh

# 실행 권한 부여
chmod +x /root/jaeger/docker-compose/monitor/run-spark-deps-v2.sh
```

**실행 스크립트 내용** (`run-spark-deps-v2.sh`):

```bash
#!/bin/bash
# Spark Dependencies 실행 스크립트
# 진행 상황을 모니터링하고 결과를 확인합니다

set -e

# 설정
OPENSEARCH_HOST="localhost"
OPENSEARCH_PORT="9200"
SPAN_INDEX="jaeger-span"
DEPS_INDEX="jaeger-dependencies"
DAYS=${1:-7}

JAR_PATH="/tmp/spark-deps-build/spark-dependencies/jaeger-spark-dependencies-opensearch/target/jaeger-spark-dependencies-opensearch-0.0.1-SNAPSHOT.jar"

# ... (스크립트 내용은 이미 파일에 있음)
```

### Step 6: Trace 데이터 생성 (테스트용)

```bash
# 애플리케이션에서 Trace 데이터 생성 필요
# OpenTelemetry Agent를 사용하여 애플리케이션 계측

# 예: Java 애플리케이션
java -javaagent:opentelemetry-javaagent.jar \
     -Dotel.service.name=my-service \
     -Dotel.exporter.otlp.endpoint=http://localhost:4317 \
     -jar my-app.jar
```

**또는 microsim으로 테스트 데이터 생성**:
```bash
# docker-compose-final.yml에 microsim이 이미 포함되어 있음
# 자동으로 테스트 trace 생성됨
```

### Step 7: Spark Dependencies 실행 테스트

```bash
# 최근 1일 데이터로 테스트
/root/jaeger/docker-compose/monitor/run-spark-deps-v2.sh 1
```

**예상 출력**:
```
==========================================
Jaeger Spark Dependencies 실행
==========================================

설정:
  - OpenSearch: localhost:9200
  - Span Index: jaeger-span
  - Dependencies Index: jaeger-dependencies
  - 기간: 최근 1 일

인덱스 확인 중...
  ✓ jaeger-span-2026-03-04: 79604 spans

==========================================
Spark Dependencies 시작
==========================================

WARNING: Runtime environment does not support multi-release JARs...
Using Spark's default log4j profile...

==========================================
실행 완료! (소요 시간: 21초)
==========================================

✓ 의존성 인덱스 생성 완료!
  문서 수: 13
```

### Step 8: 결과 확인

```bash
# 1. Jaeger UI 확인
# 브라우저에서: http://localhost:16686/dependencies

# 2. OpenSearch API 확인
curl -s "http://localhost:9200/jaeger-dependencies-$(date +%Y-%m-%d)/_search?pretty&size=1"

# 3. Jaeger API 확인
curl -s "http://localhost:16686/api/dependencies"
```

### Step 9: 자동화 설정 (Cron)

```bash
# 로그 파일 생성
touch /var/log/spark-deps.log
chmod 644 /var/log/spark-deps.log

# Cron 등록 (매일 새벽 2시 실행)
echo "0 2 * * * /root/jaeger/docker-compose/monitor/run-spark-deps-v2.sh 7 >> /var/log/spark-deps.log 2>&1" | crontab -

# Cron 확인
crontab -l
```

### Step 10: 전체 아키텍처

```
┌─────────────────┐
│  애플리케이션     │
│  (OTel Agent)   │
└────────┬────────┘
         │ OTLP
         ▼
┌─────────────────┐
│ OTEL Collector  │
│  (port 4317)    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│     Jaeger      │
│  (port 16686)   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   OpenSearch    │
│  (port 9200)    │
└────────┬────────┘
         │
    ┌────┴────┐
    │         │
    ▼         ▼
┌──────┐  ┌─────────────┐
│ Jaeger│  │  Spark Deps │
│  UI   │  │  (일일 배치) │
└──────┘  └─────────────┘
```

### 빠른 시작 체크리스트

- [ ] Docker 설치
- [ ] Java 21+ 설치
- [ ] Maven 설치
- [ ] OpenSearch 컨테이너 실행 중 (`docker ps | grep opensearch`)
- [ ] Jaeger 컨테이너 실행 중 (`docker ps | grep jaeger`)
- [ ] Spark Dependencies JAR 빌드 완료
- [ ] 실행 스크립트 실행 가능 (`chmod +x run-spark-deps-v2.sh`)
- [ ] 테스트 실행 성공 (`run-spark-deps-v2.sh 1`)
- [ ] Jaeger UI에서 dependency graph 확인
- [ ] Cron 등록 완료

---

## ✅ 작동 확인

Spark Dependencies가 정상 작동 중입니다!

### 실행 방법

```bash
# 최근 1일 데이터 처리
/root/jaeger/docker-compose/monitor/run-spark-deps-v2.sh 1

# 최근 7일 데이터 처리
/root/jaeger/docker-compose/monitor/run-spark-deps-v2.sh 7

# 최근 30일 데이터 처리
/root/jaeger/docker-compose/monitor/run-spark-deps-v2.sh 30
```

### 실행 예시

```
==========================================
Jaeger Spark Dependencies 실행
==========================================

설정:
  - OpenSearch: localhost:9200
  - Span Index: jaeger-span
  - Dependencies Index: jaeger-dependencies
  - 기간: 최근 1 일

인덱스 확인 중...
  ✓ jaeger-span-2026-03-04: 79604 spans

==========================================
Spark Dependencies 시작
==========================================

[Spark 실행...]

==========================================
실행 완료! (소요 시간: 21초)
==========================================

✓ 의존성 인덱스 생성 완료!
  인덱스: jaeger-dependencies-2026-03-04
  문서 수: 13

==========================================
서비스 의존성 목록
==========================================
frontend -> frontend (calls: 9066)
frontend -> driver (calls: 3963)
frontend -> route (calls: 1140)
driver -> driver (calls: 16793)
frontend -> customer (calls: 3963)
test-executor -> test-executor (calls: 3963)
ui -> ui (calls: 3963)
ui -> frontend (calls: 3963)
customer -> mysql (calls: 3963)
customer -> customer (calls: 3963)
test-executor -> ui (calls: 3963)
driver -> redis (calls: 16793)
```

## 자동화 설정 (Cron)

### 1. Cron 등록

```bash
# 매일 새벽 2시에 실행 (최근 7일 처리)
crontab -e

# 추가할 내용:
0 2 * * * /root/jaeger/docker-compose/monitor/run-spark-deps-v2.sh 7 >> /var/log/spark-deps.log 2>&1
```

### 2. 로그 파일 생성

```bash
sudo touch /var/log/spark-deps.log
sudo chmod 644 /var/log/spark-deps.log
```

### 3. Cron 등록 명령어

```bash
(crontab -l 2>/dev/null; echo "0 2 * * * /root/jaeger/docker-compose/monitor/run-spark-deps-v2.sh 7 >> /var/log/spark-deps.log 2>&1") | crontab -
```

## 데이터 확인

### 1. Jaeger UI
- **URL**: http://localhost:16686/dependencies
- **기능**: 서비스 의존성 그래프 시각화

### 2. OpenSearch API

```bash
# 오늘의 의존성 데이터 조회
curl -s "http://localhost:9200/jaeger-dependencies-$(date +%Y-%m-%d)/_search?pretty&size=1"

# 인덱스 목록
curl -s "http://localhost:9200/_cat/indices/jaeger-dependencies*?v"

# 문서 수 확인
curl -s "http://localhost:9200/jaeger-dependencies-$(date +%Y-%m-%d)/_count"
```

### 3. Jaeger API

```bash
# 의존성 데이터 가져오기
curl -s "http://localhost:16686/api/dependencies"
```

## 스토리지 구조

### OpenSearch 인덱스

| 인덱스 패턴 | 내용 | 보존 기간 |
|------------|------|----------|
| `jaeger-span-YYYY-MM-DD` | Trace Span 데이터 | 일반적 7-30일 |
| `jaeger-dependencies-YYYY-MM-DD` | 서비스 의존성 데이터 | 일별 생성 |
| `jaeger-service-YYYY-MM-DD` | 서비스 메타데이터 | 일별 생성 |

### 의존성 데이터 구조

```json
{
  "dependencies": [
    {
      "parent": "frontend",
      "child": "driver",
      "callCount": 3963,
      "source": "jaeger"
    }
  ],
  "timestamp": "2026-03-04T00:00:00Z"
}
```

## 구성 요소

### 1. OpenSearch
- **역할**: Trace 데이터 저장소
- **포트**: 9200
- **인증**: 없음
- **클러스터**: docker-cluster

### 2. Jaeger
- **역할**: Trace 수집 및 UI
- **포트**: 16686 (UI)
- **스토리지**: OpenSearch 직접 쿼리

### 3. Spark Dependencies
- **역할**: 배치 작업으로 서비스 의존성 계산
- **언어**: Java (Apache Spark)
- **입력**: OpenSearch jaeger-span 인덱스
- **출력**: OpenSearch jaeger-dependencies 인덱스

## 실행 파일

| 파일 | 위치 | 설명 |
|------|------|------|
| **run-spark-deps-v2.sh** | /root/jaeger/docker-compose/monitor/ | Spark Dependencies 실행 스크립트 |
| **jar** | /tmp/spark-deps-build/spark-dependencies/ | OpenSearch용 Spark Dependencies JAR |

## 성능

- **1일 데이터**: ~21초 (79,604 spans)
- **7일 데이터**: ~1-2분 (예상)
- **30일 데이터**: ~5-10분 (예상)

## 문제 해결

### 실행 시 로그가 너무 많이 나올 때

```bash
# 로그를 파일로 저장
/root/jaeger/docker-compose/monitor/run-spark-deps-v2.sh 7 > /tmp/spark-deps-output.log 2>&1
```

### 인덱스를 찾을 수 없을 때

```bash
# span 인덱스 확인
curl -s "http://localhost:9200/_cat/indices/jaeger-span*?v"

# 날짜 확인
date
```

### OpenSearch 연결 실패

```bash
# OpenSearch 상태 확인
curl -s http://localhost:9200/_cluster/health

# 컨테이너 상태 확인
docker ps | grep opensearch
```

## 요약

✅ **Spark Dependencies 빌드 완료**: OpenSearch용 JAR 생성
✅ **실행 스크립트 작성**: 진행 상황 모니터링 가능
✅ **의존성 데이터 생성**: jaeger-dependencies-YYYY-MM-DD 인덱스
✅ **Jaeger UI 통합**: http://localhost:16686/dependencies

---

**생성일**: 2026-03-04
**상태**: ✅ 완료
**실행 스크립트**: `/root/jaeger/docker-compose/monitor/run-spark-deps-v2.sh`
