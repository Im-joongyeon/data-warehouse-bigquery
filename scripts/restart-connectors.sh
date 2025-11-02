#!/bin/bash

# Restart BigQuery Sink Connectors

set -e

CONNECT_URL="http://localhost:8084"

echo "==========================================="
echo "Restarting BigQuery Sink Connectors"
echo "==========================================="

# Check if Kafka Connect is running
if ! curl -s "${CONNECT_URL}" > /dev/null 2>&1; then
    echo "❌ Kafka Connect is not running"
    echo ""
    echo "Start services first: ./scripts/start.sh"
    exit 1
fi

# Restart accounts connector
echo ""
echo "Restarting bigquery-sink-accounts..."
RESPONSE=$(curl -s -X POST "${CONNECT_URL}/connectors/bigquery-sink-accounts/restart" 2>&1)
if [ $? -eq 0 ]; then
    echo "✓ Accounts connector restart requested"
else
    echo "⚠ Failed to restart accounts connector"
    echo "   Connector may not exist. Try: ./scripts/register-connectors.sh"
fi

# Restart transactions connector
echo ""
echo "Restarting bigquery-sink-transactions..."
RESPONSE=$(curl -s -X POST "${CONNECT_URL}/connectors/bigquery-sink-transactions/restart" 2>&1)
if [ $? -eq 0 ]; then
    echo "✓ Transactions connector restart requested"
else
    echo "⚠ Failed to restart transactions connector"
    echo "   Connector may not exist. Try: ./scripts/register-connectors.sh"
fi

echo ""
echo "Waiting for connectors to restart (5 seconds)..."
sleep 5

echo ""
echo "✓ Restart completed!"
echo ""
echo "Check status: ./scripts/check-connectors.sh"
echo ""
