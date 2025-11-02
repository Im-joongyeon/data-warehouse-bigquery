# Data Warehouse Setup Guide

이 가이드는 Kafka에서 BigQuery로 데이터를 스트리밍하는 파이프라인을 설정하는 방법을 단계별로 설명합니다.

## 📋 사전 요구사항

### 완료 필수
- [x] data-ingestion 파이프라인 실행 중
- [x] GCP 프로젝트 생성
- [x] BigQuery API 활성화
- [x] Service Account 생성 및 JSON 키 다운로드
- [x] Service Account에 BigQuery 권한 부여

### 소프트웨어
- Docker & Docker Compose
- gcloud CLI (선택사항, BigQuery 수동 설정 시)
- bq CLI (선택사항, gcloud에 포함)

## 🚀 Step 1: GCP Service Account 키 설정

### 1-1. JSON 키 파일 복사

다운로드한 Service Account JSON 키를 `gcp/` 디렉토리에 복사:

```bash
# Downloads 폴더에서 복사 (파일명은 다를 수 있음)
cp ~/Downloads/프로젝트id.json gcp/service-account-key.json

# 권한 설정 (보안)
chmod 600 gcp/service-account-key.json
```

### 1-2. 키 파일 검증

```bash
# JSON 형식 확인
cat gcp/service-account-key.json | jq '.project_id'
# 출력: "프로젝트id"

# 파일이 .gitignore에 포함되었는지 확인
git status
# service-account-key.json이 나타나지 않아야 함
```

## 🗄️ Step 2: BigQuery 데이터셋 및 테이블 생성

### 방법 1: 자동 스크립트 (추천)

```bash
# gcloud 인증 (처음 한 번만)
gcloud auth login

# 스크립트 실행
cd gcp
chmod +x setup-bigquery.sh
./setup-bigquery.sh
```

### 방법 2: 수동 생성

```bash
# 프로젝트 설정
gcloud config set project 프로젝트id

# 데이터셋 생성
bq mk --dataset --location=US 프로젝트id:kafka_ingestion

# 테이블 생성
bq mk --table 프로젝트id:kafka_ingestion.accounts schemas/accounts_schema.json
bq mk --table 프로젝트id:kafka_ingestion.transactions schemas/transactions_schema.json

# 확인
bq ls 프로젝트id:kafka_ingestion
```

### 방법 3: BigQuery Console (웹)

1. https://console.cloud.google.com/bigquery?project=프로젝트id
2. 프로젝트 이름 옆 ⋮ 클릭 → **데이터 세트 만들기**
3. 데이터 세트 ID: `kafka_ingestion`
4. 위치: `US` (또는 선호하는 리전)
5. **데이터 세트 만들기** 클릭

테이블은 Connector가 자동으로 생성할 수도 있습니다 (`autoCreateTables: true` 설정).

## 🐳 Step 3: Docker Compose로 Kafka Connect 시작

### 3-1. 환경변수 설정

```bash
cp .env.example .env
# .env 파일 확인 (기본값으로 충분)
```

### 3-2. 서비스 시작

```bash
docker-compose up -d
```

### 3-3. 서비스 확인

```bash
# 컨테이너 상태 확인
docker-compose ps

# Kafka Connect 로그 확인
docker-compose logs -f connect-bigquery

# BigQuery connector plugin 설치 확인 (60초 정도 소요)
docker-compose logs connect-bigquery | grep "BigQuery"
```

**중요:** Kafka Connect가 완전히 시작되고 BigQuery connector plugin이 설치될 때까지 **60-90초** 기다려야 합니다.

### 3-4. Health Check

```bash
# Kafka Connect API 확인
curl http://localhost:8084/

# Connector plugins 확인
curl http://localhost:8084/connector-plugins | jq '.' | grep BigQuery
```

`BigQuerySinkConnector`가 보이면 준비 완료!

## 🔌 Step 4: BigQuery Sink Connector 등록

### 4-1. data-ingestion 파이프라인 확인

BigQuery로 전송할 Kafka 토픽에 데이터가 있는지 확인:

```bash
# data-ingestion 디렉토리로 이동
cd ../data-ingestion

# 토픽 확인
docker-compose exec kafka kafka-topics --list --bootstrap-server localhost:9092 | grep dbserver1

# 메시지 확인
docker-compose exec kafka kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic dbserver1.public.accounts \
  --max-messages 1

# data-warehouse 디렉토리로 복귀
cd ../data-warehouse
```

### 4-2. Connector 등록

```bash
cd kafka-bigquery-connector
chmod +x register_sink.sh
./register_sink.sh
```

### 4-3. Connector 상태 확인

```bash
# accounts connector 상태
curl http://localhost:8084/connectors/bigquery-sink-accounts/status | jq '.'

# transactions connector 상태
curl http://localhost:8084/connectors/bigquery-sink-transactions/status | jq '.'
```

**정상 상태:**
```json
{
  "name": "bigquery-sink-accounts",
  "connector": {
    "state": "RUNNING",
    "worker_id": "..."
  },
  "tasks": [
    {
      "id": 0,
      "state": "RUNNING",
      "worker_id": "..."
    }
  ]
}
```

## ✅ Step 5: 데이터 검증

### 5-1. BigQuery Console에서 확인

1. https://console.cloud.google.com/bigquery?project=프로젝트id
2. 좌측 탐색기에서 `프로젝트id` → `kafka_ingestion` 확장
3. `accounts` 테이블 클릭 → **미리보기** 탭

### 5-2. SQL 쿼리로 확인

BigQuery Editor에서 실행:

```sql
-- accounts 데이터 확인
SELECT * FROM `프로젝트id.kafka_ingestion.accounts`
ORDER BY created_at DESC
LIMIT 10;

-- transactions 데이터 확인
SELECT * FROM `프로젝트id.kafka_ingestion.transactions`
ORDER BY created_at DESC
LIMIT 10;

-- 데이터 개수 확인
SELECT 
  'accounts' as table_name,
  COUNT(*) as row_count
FROM `프로젝트id.kafka_ingestion.accounts`
UNION ALL
SELECT 
  'transactions' as table_name,
  COUNT(*) as row_count
FROM `프로젝트id.kafka_ingestion.transactions`;
```

### 5-3. 실시간 데이터 테스트

**터미널 1 - BigQuery 모니터링:**

BigQuery Console에서 자동 새로고침 활성화 또는 쿼리 반복 실행

**터미널 2 - PostgreSQL 데이터 삽입:**

```bash
cd ../data-ingestion
docker-compose exec postgres psql -U postgres -d mydb

-- 새 계좌 생성
INSERT INTO accounts (user_id, balance, status) 
VALUES (1000, 100000.00, 'ACTIVE');

-- 거래 추가
INSERT INTO transactions (account_id, tx_type, amount, balance_after, status) 
VALUES (1000, 'deposit', 100000.00, 100000.00, 'COMPLETED');
```

**터미널 3 - BigQuery 확인 (10-30초 후):**

```sql
SELECT * FROM `프로젝트id.kafka_ingestion.accounts`
WHERE user_id = 1000;

SELECT * FROM `프로젝트id.kafka_ingestion.transactions`
WHERE account_id = 1000;
```

## 🔍 Step 6: 모니터링

### Connector 로그 확인

```bash
# 실시간 로그
docker-compose logs -f connect-bigquery

# 에러만 확인
docker-compose logs connect-bigquery | grep -i error

# 특정 connector 로그
docker-compose logs connect-bigquery | grep bigquery-sink-accounts
```

### Connector 메트릭

```bash
# 모든 connector 목록
curl http://localhost:8084/connectors

# 특정 connector 상세 정보
curl http://localhost:8084/connectors/bigquery-sink-accounts | jq '.'

# Task 상태
curl http://localhost:8084/connectors/bigquery-sink-accounts/tasks/0/status | jq '.'
```

### BigQuery 모니터링

```sql
-- 테이블 크기 및 행 수
SELECT 
  table_name,
  row_count,
  ROUND(size_bytes / 1024 / 1024, 2) as size_mb,
  ROUND(size_bytes / row_count, 0) as avg_row_bytes
FROM `프로젝트id.kafka_ingestion.__TABLES__`;

-- 최근 삽입 시간
SELECT 
  'accounts' as table_name,
  MAX(created_at) as last_insert_time
FROM `프로젝트id.kafka_ingestion.accounts`
UNION ALL
SELECT 
  'transactions' as table_name,
  MAX(created_at) as last_insert_time
FROM `프로젝트id.kafka_ingestion.transactions`;
```

## 🎯 다음 단계

데이터가 BigQuery에 정상적으로 들어오고 있다면:

1. **dbt-project**: 데이터 변환 및 모델링
   - Staging models
   - Fact & Dimension tables
   - Data quality tests

2. **data-analytics**: 시각화
   - Looker Studio 대시보드
   - 비즈니스 메트릭
   - 알림 설정

## 📚 참고 자료

- [Kafka Connect BigQuery Sink](https://github.com/confluentinc/kafka-connect-bigquery)
- [BigQuery Documentation](https://cloud.google.com/bigquery/docs)
- [Confluent Hub](https://www.confluent.io/hub/confluentinc/kafka-connect-bigquery)
