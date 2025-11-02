#!/bin/bash

# Delete BigQuery Sink Connectors

set -e

CONNECT_URL="http://localhost:8084"

echo "==========================================="
echo "Deleting BigQuery Sink Connectors"
echo "==========================================="

# Check if Kafka Connect is running
if ! curl -s "${CONNECT_URL}" > /dev/null 2>&1; then
    echo "❌ Kafka Connect is not running"
    exit 1
fi

# Confirmation
echo ""
echo "⚠️  This will delete both connectors:"
echo "  - bigquery-sink-accounts"
echo "  - bigquery-sink-transactions"
echo ""
read -p "Are you sure? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled"
    exit 0
fi

# Delete accounts connector
echo ""
echo "Deleting bigquery-sink-accounts..."
RESPONSE=$(curl -s -X DELETE "${CONNECT_URL}/connectors/bigquery-sink-accounts" 2>&1)
if [ $? -eq 0 ]; then
    echo "✓ Accounts connector deleted"
else
    echo "⚠ Connector may not exist"
fi

# Delete transactions connector
echo ""
echo "Deleting bigquery-sink-transactions..."
RESPONSE=$(curl -s -X DELETE "${CONNECT_URL}/connectors/bigquery-sink-transactions" 2>&1)
if [ $? -eq 0 ]; then
    echo "✓ Transactions connector deleted"
else
    echo "⚠ Connector may not exist"
fi

echo ""
echo "✓ Deletion completed!"
echo ""
echo "To re-register connectors: ./scripts/register-connectors.sh"
echo ""
