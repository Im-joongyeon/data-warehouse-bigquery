#!/bin/bash

# Check Kafka Connect connector logs and errors

set -e

CONNECT_URL="http://localhost:8084"
CONNECTOR_NAME="${1:-bigquery-sink-accounts}"

echo "==========================================="
echo "Kafka Connect Connector Logs & Errors"
echo "==========================================="
echo "Connector: ${CONNECTOR_NAME}"
echo ""

# Check if Kafka Connect is running
if ! curl -s "${CONNECT_URL}" > /dev/null 2>&1; then
    echo "❌ Kafka Connect is not running"
    echo ""
    echo "Start services first: ./scripts/start.sh"
    exit 1
fi

echo "--- Connector Status ---"
STATUS=$(curl -s "${CONNECT_URL}/connectors/${CONNECTOR_NAME}/status" 2>/dev/null)
if command -v jq &> /dev/null; then
    echo "$STATUS" | jq '.'
else
    echo "$STATUS"
fi

echo ""
echo "--- Connector Config ---"
CONFIG=$(curl -s "${CONNECT_URL}/connectors/${CONNECTOR_NAME}/config" 2>/dev/null)
if command -v jq &> /dev/null; then
    echo "$CONFIG" | jq '.'
else
    echo "$CONFIG"
fi

echo ""
echo "--- Docker Container Logs (last 50 lines) ---"
CONTAINER=$(docker ps --filter "name=connect-bigquery" --format "{{.Names}}" | head -n 1)
if [ -n "$CONTAINER" ]; then
    echo "Container: ${CONTAINER}"
    echo ""
    docker logs --tail 50 "${CONTAINER}" 2>&1 | grep -i -E "(error|exception|failed|warn|${CONNECTOR_NAME})" || echo "No errors found in recent logs"
else
    echo "❌ connect-bigquery container not found"
fi

echo ""
echo "==========================================="
echo ""
echo "Full logs: docker logs -f connect-bigquery"
echo ""
echo "Other useful commands:"
echo "  - Check topic messages: ./scripts/check-kafka-topic.sh <topic-name>"
echo "  - Restart connector: curl -X POST ${CONNECT_URL}/connectors/${CONNECTOR_NAME}/restart"
echo ""

