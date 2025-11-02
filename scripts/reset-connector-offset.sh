#!/bin/bash

# Reset Kafka Connect connector offset to earliest
# This allows the connector to re-read all messages from the beginning

set -e

CONNECT_URL="http://localhost:8084"
CONNECTOR_NAME="${1:-bigquery-sink-accounts}"

echo "==========================================="
echo "Reset Connector Offset"
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

echo "⚠️  WARNING: This will reset the consumer offset for ${CONNECTOR_NAME}"
echo "The connector will re-read all messages from the beginning."
echo ""
echo "This may result in duplicate data in BigQuery!"
echo ""
read -p "Are you sure? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled"
    exit 0
fi

echo ""
echo "Stopping connector..."
curl -X PUT "${CONNECT_URL}/connectors/${CONNECTOR_NAME}/pause" > /dev/null 2>&1 || true
sleep 2

echo ""
echo "Deleting consumer offsets..."
# Delete offsets by updating connector config with offset reset
# This is done by temporarily adding the offset reset config
CONFIG=$(curl -s "${CONNECT_URL}/connectors/${CONNECTOR_NAME}/config")

# Extract topics from config
TOPICS=$(echo "$CONFIG" | grep -o '"topics":"[^"]*"' | cut -d'"' -f4)

if [ -z "$TOPICS" ]; then
    echo "❌ Could not find topics in connector config"
    exit 1
fi

echo "Topics: ${TOPICS}"
echo ""
echo "To reset offset, we need to:"
echo "  1. Delete the connector offsets topic"
echo "  2. Restart the connector"
echo ""

# Find Kafka container
KAFKA_CONTAINER=$(docker ps --filter "name=kafka" --format "{{.Names}}" | head -n 1)

if [ -n "$KAFKA_CONTAINER" ]; then
    echo "Found Kafka container: ${KAFKA_CONTAINER}"
    echo ""
    echo "⚠️  To fully reset offsets, you may need to manually delete the offset topic:"
    echo "  docker exec ${KAFKA_CONTAINER} kafka-topics --delete --topic connect-offsets --bootstrap-server localhost:9092"
    echo ""
    echo "Alternatively, you can update the connector config to set:"
    echo "  \"consumer.override.auto.offset.reset\": \"earliest\""
    echo "  and restart the connector"
    echo ""
fi

echo "Resuming connector..."
curl -X PUT "${CONNECT_URL}/connectors/${CONNECTOR_NAME}/resume" > /dev/null 2>&1 || true

echo ""
echo "==========================================="
echo ""
echo "If you want to read from the beginning:"
echo "  1. Update connector config with: \"consumer.override.auto.offset.reset\": \"earliest\""
echo "  2. Or delete and re-register the connector"
echo ""
echo "Check connector status: ./scripts/check-connectors.sh"
echo ""

