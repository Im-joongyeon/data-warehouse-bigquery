## 프로젝트 개요 (한 문장)
이 레포는 PostgreSQL → Kafka (data-ingestion) → Kafka Connect(BigQuery Sink) → BigQuery 로 이어지는 간단한 CDC 파이프라인을 제공합니다. 핵심 책임은 Kafka 토픽을 BigQuery 테이블로 안정적으로 적재하는 것입니다.

## 빠른 아키텍처 요약
- data-ingestion: PostgreSQL CDC (출처) —(Kafka)->
- data-warehouse: Kafka Connect(BigQuery Sink) 컨테이너가 토픽을 읽어 BigQuery `kafka_ingestion` 데이터셋으로 적재합니다.
- BigQuery 테이블 스키마는 `schemas/`에 JSON 형식으로 정의되어 있습니다 (`accounts_schema.json`, `transactions_schema.json`).

중요 파일/디렉터
- `docker-compose.yml` — Kafka Connect 서비스(`connect-bigquery`) 정의. 외부 네트워크 `data-ingestion_data-pipeline`에 연결됩니다.
- `gcp/service-account-key.json` — GCP 서비스 계정 키(로컬에 복사 후 사용). 컨테이너에서 `/tmp/keyfile.json`으로 마운트됩니다.
- `gcp/setup-bigquery.sh` — BigQuery 데이터셋(`kafka_ingestion`)과 테이블을 생성/재생성하는 스크립트.
- `connectors/` — Connector 등록 스크립트와 예시 JSON (`register_sink.sh`, `bigquery-sink-*.json`).
- `scripts/` — 서비스 시작/정지, 커넥터 상태 확인 등 운영 스크립트(예: `start.sh`, `check-connectors.sh`).

운영/개발 워크플로우 (핵심 명령 예시)
1. 서비스 계정 키 준비:
   - 복사: `cp ~/Downloads/your-key.json gcp/service-account-key.json` 및 `chmod 600 gcp/service-account-key.json`
2. BigQuery 리소스 생성:
   - `cd gcp` → `./setup-bigquery.sh` (GCP CLI `gcloud`/`bq` 필요)
3. Kafka Connect 시작:
   - 루트에서 `./scripts/start.sh` (start.sh는 외부 네트워크 존재 여부와 플러그인 설치/헬스 체크를 수행합니다)
4. Connector 등록:
   - `connectors/register_sink.sh`가 실제 등록 스크립트입니다. 이 스크립트는 `.env`에서 `GCP_PROJECT_ID`를 읽고 `bigquery-sink-*.json`의 `${GCP_PROJECT_ID}` 플레이스홀더를 치환하여 등록합니다.
5. 상태 확인:
   - Kafka Connect API: `http://localhost:8084` (`docker-compose`가 `8084:8083`으로 매핑)
   - 등록된 커넥터 목록: `curl http://localhost:8084/connectors`
   - 스크립트: `./scripts/check-connectors.sh`, BigQuery 확인용 `./scripts/check-bigquery.sh`

프로젝트-특정 컨벤션 및 잡힌 패턴
- 네트워크: `data-ingestion_data-pipeline` (외부 네트워크) — `scripts/start.sh`는 이 네트워크 존재를 필수로 확인합니다.
- 커넥터 설정: `connectors/bigquery-sink-*.json` 파일은 `${GCP_PROJECT_ID}` 플레이스홀더를 사용합니다. 등록 스크립트에서 sed로 치환합니다.
- 인증: 서비스 계정 키를 컨테이너 내부의 `/tmp/keyfile.json`으로 마운트하고, 커넥터 설정에서 `keyfile`과 `keySource: FILE`을 사용합니다.
- 데이터 변환: Kafka Connect에서 JsonConverter(schema disabled)와 Flatten transform(`transforms.flatten`)을 사용하여 필드명을 `_<delimiter>`로 연결합니다.
- BigQuery: 데이터셋 이름은 `kafka_ingestion`으로 고정되어 있으며, 테이블 이름은 커넥터 설정의 `table.name.format`으로 지정됩니다.

주의할 점 / 발견된 불일치
- 문서(`scripts/start.sh` 등)는 `./scripts/register-connectors.sh` 같은 경로를 참조하지만, 실제 등록 스크립트는 `connectors/register_sink.sh`입니다. 자동화/문서화를 수행할 때 이 경로 차이를 유의하세요.

디버깅 팁 (빠른 체크리스트)
- Kafka Connect 헬스: `curl http://localhost:8084/` (정상적이면 JSON 응답)
- 등록된 커넥터 및 상태: `curl http://localhost:8084/connectors/<name>/status`
- 컨테이너 로그: `docker-compose logs -f connect-bigquery`
- BigQuery 쿼리: `bq query --use_legacy_sql=false 'SELECT COUNT(*) FROM \\`<PROJECT>.kafka_ingestion.accounts\\`'`

간단한 계약(Inputs / Outputs / Error modes)
- 입력: `GCP service-account` JSON, 활성화된 `data-ingestion` 네트워크, `GCP_PROJECT_ID` 환경변수
- 출력: `kafka_ingestion` 데이터셋의 `accounts` / `transactions` 테이블에 적재된 레코드
- 주요 오류 모드: 인증 오류(키 파일/권한), 네트워크 미존재, 커넥터 플러그인 미설치

마지막으로
- 변경/추가가 필요하면 이 파일의 해당 섹션(예: 경로 불일치)을 지적해 주세요. 불명확한 운영 절차(예: `.env` 예시, CI 배포)는 피드백을 받은 뒤 확장하겠습니다.
