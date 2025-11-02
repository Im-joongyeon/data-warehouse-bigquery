#!/bin/bash

# Check BigQuery Sink Connector status

set -e

CONNECT_URL="http://localhost:8084"

echo "==========================================="
echo "BigQuery Sink Connector Status"
echo "==========================================="

# Check if Kafka Connect is running
if ! curl -s "${CONNECT_URL}" > /dev/null 2>&1; then
    echo "❌ Kafka Connect is not running"
    echo ""
    echo "Start services first: ./scripts/start.sh"
    exit 1
fi

echo ""
echo "--- Registered Connectors ---"
CONNECTORS=$(curl -s "${CONNECT_URL}/connectors" 2>/dev/null)
if [ -z "$CONNECTORS" ] || [ "$CONNECTORS" = "[]" ]; then
    echo "No connectors registered"
    echo ""
    echo "Register connectors: ./scripts/register-connectors.sh"
    exit 0
fi

echo "$CONNECTORS" | tr ',' '\n' | sed 's/\[//g;s/\]//g;s/"//g' | sed 's/^/  - /'

echo ""
echo "--- Accounts Connector Status ---"
ACCOUNTS_STATUS=$(curl -s "${CONNECT_URL}/connectors/bigquery-sink-accounts/status" 2>/dev/null)
if [ -n "$ACCOUNTS_STATUS" ]; then
    if command -v jq &> /dev/null; then
        echo "$ACCOUNTS_STATUS" | jq '.'
    else
        echo "$ACCOUNTS_STATUS"
    fi
    
    # Check if running
    if echo "$ACCOUNTS_STATUS" | grep -q '"state":"RUNNING"'; then
        echo "✓ Accounts connector is RUNNING"
    else
        echo "⚠ Accounts connector is not running properly"
    fi
else
    echo "Connector not found"
fi

echo ""
echo "--- Transactions Connector Status ---"
TRANSACTIONS_STATUS=$(curl -s "${CONNECT_URL}/connectors/bigquery-sink-transactions/status" 2>/dev/null)
if [ -n "$TRANSACTIONS_STATUS" ]; then
    if command -v jq &> /dev/null; then
        echo "$TRANSACTIONS_STATUS" | jq '.'
    else
        echo "$TRANSACTIONS_STATUS"
    fi
    
    # Check if running
    if echo "$TRANSACTIONS_STATUS" | grep -q '"state":"RUNNING"'; then
        echo "✓ Transactions connector is RUNNING"
    else
        echo "⚠ Transactions connector is not running properly"
    fi
else
    echo "Connector not found"
fi

echo ""
echo "==========================================="
echo ""
echo "Useful commands:"
echo "  - View logs: docker-compose logs -f connect-bigquery"
echo "  - Restart connectors: ./scripts/restart-connectors.sh"
echo "  - Check BigQuery: ./scripts/check-bigquery.sh"
echo ""
