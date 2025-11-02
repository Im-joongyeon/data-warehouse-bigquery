FROM confluentinc/cp-kafka-connect:7.5.0

USER root

# RedHat/UBI 기반 패키지 설치
RUN microdnf install -y curl unzip && \
    microdnf clean all

# 기본 사용자(appuser)로 돌아가기
USER appuser
