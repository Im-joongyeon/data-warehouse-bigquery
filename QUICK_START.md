# Quick Start Guide - BigQuery Sink

10분 안에 Kafka → BigQuery 파이프라인을 시작하는 방법입니다.

## ✅ 사전 확인

```bash
# 1. data-ingestion이 실행 중인지 확인
cd ../data-ingestion
docker-compose ps
# postgres, kafka, connect가 모두 Up (healthy)

# 2. Kafka 토픽에 데이터 확인
docker-compose exec kafka kafka-topics --list --bootstrap-server localhost:9092 | grep dbserver1
# dbserver1.public.accounts
# dbserver1.public.transactions

cd ../data-warehouse
```

## 🚀 빠른 시작

### 1️⃣ Service Account 키 설정

```bash
# 다운로드한 JSON 키 파일 복사
cp ~/Downloads/프로젝트id-*.json gcp/service-account-key.json

# 권한 설정
chmod 600 gcp/service-account-key.json

# 확인
cat gcp/service-account-key.json | jq '.project_id'
# 출력: "프로젝트id"
```

### 2️⃣ BigQuery 설정

```bash
# gcloud 인증 (처음 한 번만)
gcloud auth login

# BigQuery 테이블 생성
cd gcp
./setup-bigquery.sh
cd ..
```

### 3️⃣ Kafka Connect 시작

```bash
# 서비스 시작 (60초 소요)
./scripts/start.sh
```

### 4️⃣ Connector 등록

```bash
# BigQuery Sink Connector 등록
cd kafka-bigquery-connector
./register_sink.sh
cd ..
```

### 5️⃣ 확인

```bash
# Connector 상태 확인
./scripts/check-connectors.sh

# BigQuery에서 데이터 확인
./scripts/check-bigquery.sh
```

**또는 BigQuery Console:**
https://console.cloud.google.com/bigquery?project=프로젝트id

```sql
SELECT * FROM `프로젝트id.kafka_ingestion.accounts` LIMIT 10;
SELECT * FROM `프로젝트id.kafka_ingestion.transactions` LIMIT 10;
```

---

## 🧪 테스트

### 실시간 CDC 테스트

**터미널 1 - 데이터 삽입:**
```bash
cd ../data-ingestion
docker-compose exec postgres psql -U postgres -d mydb

INSERT INTO accounts (user_id, balance, status) 
VALUES (88888, 888888.00, 'ACTIVE');

INSERT INTO transactions (account_id, tx_type, amount, balance_after, status) 
VALUES (88888, 'deposit', 888888.00, 888888.00, 'COMPLETED');

\q
```

**터미널 2 - BigQuery 확인 (10-30초 후):**
```sql
-- BigQuery Console에서 실행
SELECT * FROM `프로젝트id.kafka_ingestion.accounts`
WHERE user_id = 88888;

SELECT * FROM `프로젝트id.kafka_ingestion.transactions`
WHERE account_id = 88888;
```

---

## 🚀 Available Scripts

모든 스크립트는 프로젝트 루트에서 실행:

```bash
# 서비스 관리
./scripts/start.sh              # 서비스 시작
./scripts/stop.sh               # 서비스 중지
./scripts/clean.sh              # 컨테이너 삭제

# Connector 관리
./scripts/check-connectors.sh   # 상태 확인
./scripts/restart-connectors.sh # 재시작
./scripts/delete-connectors.sh  # 삭제

# 모니터링
./scripts/check-bigquery.sh     # BigQuery 데이터 확인
docker-compose logs -f          # 로그 확인

# 테스트
./scripts/test.sh               # End-to-end 테스트
```

자세한 내용: [scripts/README.md](scripts/README.md)

---

## 🔍 상태 확인

### 1. Docker 컨테이너

```bash
docker-compose ps
# connect-bigquery: Up (healthy)
```

### 2. Kafka Connect

```bash
curl http://localhost:8084/
# 응답: {"version":"7.5.0",...}
```

### 3. Connector 상태

```bash
curl http://localhost:8084/connectors
# ["bigquery-sink-accounts", "bigquery-sink-transactions"]

curl http://localhost:8084/connectors/bigquery-sink-accounts/status | jq '.connector.state'
# "RUNNING"
```

### 4. BigQuery 데이터

```bash
# CLI로 확인
bq query --use_legacy_sql=false \
  'SELECT COUNT(*) as count FROM `프로젝트id.kafka_ingestion.accounts`'

# Console에서 확인
https://console.cloud.google.com/bigquery?project=프로젝트id
```

---

## 🚨 문제 발생 시

### Connector가 FAILED 상태

```bash
# 에러 로그 확인
docker-compose logs connect-bigquery | grep -i error

# 상세 에러
curl http://localhost:8084/connectors/bigquery-sink-accounts/status | jq '.tasks[0].trace'

# 재시작
make restart-connector
```

### 인증 에러

```bash
# 키 파일 확인
ls -la gcp/service-account-key.json
cat gcp/service-account-key.json | jq '.project_id'

# 컨테이너 내부에서 확인
docker-compose exec connect-bigquery cat /tmp/keyfile.json | jq '.project_id'
```

### 데이터가 안 들어옴

```bash
# Kafka 토픽 확인
cd ../data-ingestion
docker-compose exec kafka kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic dbserver1.public.accounts \
  --max-messages 1

# Connector 로그 확인
cd ../data-warehouse
docker-compose logs connect-bigquery -f
```

---

## 📚 다음 단계

데이터가 BigQuery에 정상적으로 들어오고 있다면:

✅ **data-ingestion**: PostgreSQL → Kafka  
✅ **data-warehouse**: Kafka → BigQuery  
⬜ **dbt-project**: BigQuery 데이터 변환  
⬜ **data-analytics**: 대시보드 구축

---

## 🔗 유용한 링크

- **BigQuery Console**: https://console.cloud.google.com/bigquery?project=프로젝트id
- **Kafka Connect API**: http://localhost:8084
- **Documentation**: [docs/setup.md](docs/setup.md)
- **Troubleshooting**: [docs/troubleshooting.md](docs/troubleshooting.md)

---

즐거운 데이터 엔지니어링 되세요! 🎉
