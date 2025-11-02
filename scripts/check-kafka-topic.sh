#!/bin/bash

# Check Kafka topic messages
# This script helps debug by showing actual messages in Kafka topics

set -e

TOPIC="${1:-dbserver1.public.accounts}"
LIMIT="${2:-5}"

echo "==========================================="
echo "Kafka Topic Messages Check"
echo "==========================================="
echo "Topic: ${TOPIC}"
echo "Limit: ${LIMIT} messages"
echo ""

# Check if kafka-console-consumer is available
if ! command -v kafka-console-consumer &> /dev/null; then
    echo "⚠ kafka-console-consumer is not available"
    echo ""
    echo "Using Docker to access Kafka..."
    echo ""
    
    # Try to find Kafka container
    KAFKA_CONTAINER=$(docker ps --filter "name=kafka" --format "{{.Names}}" | head -n 1)
    
    if [ -z "$KAFKA_CONTAINER" ]; then
        echo "❌ Kafka container not found"
        echo ""
        echo "Please make sure Kafka is running:"
        echo "  docker ps | grep kafka"
        exit 1
    fi
    
    echo "Found Kafka container: ${KAFKA_CONTAINER}"
    echo ""
    echo "Reading messages from topic '${TOPIC}'..."
    echo "Press Ctrl+C to stop"
    echo ""
    echo "-------------------------------------------"
    
    docker exec -it "${KAFKA_CONTAINER}" kafka-console-consumer \
        --bootstrap-server localhost:9092 \
        --topic "${TOPIC}" \
        --from-beginning \
        --max-messages "${LIMIT}" \
        --property print.key=true \
        --property print.value=true \
        --property key.separator=" | " \
        2>/dev/null || {
        echo ""
        echo "❌ Failed to read messages"
        echo ""
        echo "Troubleshooting:"
        echo "  1. Check if topic exists: docker exec ${KAFKA_CONTAINER} kafka-topics --list --bootstrap-server localhost:9092"
        echo "  2. Check Kafka logs: docker logs ${KAFKA_CONTAINER}"
        exit 1
    }
else
    echo "Reading messages from topic '${TOPIC}'..."
    echo "Press Ctrl+C to stop"
    echo ""
    echo "-------------------------------------------"
    
    kafka-console-consumer \
        --bootstrap-server localhost:9092 \
        --topic "${TOPIC}" \
        --from-beginning \
        --max-messages "${LIMIT}" \
        --property print.key=true \
        --property print.value=true \
        --property key.separator=" | " \
        2>/dev/null
fi

echo ""
echo "==========================================="
echo ""
echo "Note: Debezium messages typically have this structure:"
echo "  {"
echo "    \"schema\": {...},"
echo "    \"payload\": {"
echo "      \"before\": null,"
echo "      \"after\": { ... actual data ... },"
echo "      \"source\": {...},"
echo "      \"op\": \"c\""
echo "    }"
echo "  }"
echo ""
echo "The ExtractField transform should extract the 'after' field."
echo ""

