#!/bin/bash

# Script to register BigQuery Sink Connectors

set -e

CONNECT_URL="http://localhost:8084"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load environment variables
if [ -f "${SCRIPT_DIR}/../.env" ]; then
    export $(cat "${SCRIPT_DIR}/../.env" | grep -v '^#' | xargs)
fi

PROJECT_ID="${GCP_PROJECT_ID:-}"

echo "==========================================="
echo "Registering BigQuery Sink Connectors"
echo "==========================================="

# Check if PROJECT_ID is set
if [ -z "$PROJECT_ID" ]; then
    echo "❌ Error: GCP_PROJECT_ID not set"
    echo ""
    echo "Please configure your .env file:"
    echo "  cp .env.example .env"
    echo "  # Edit .env and set GCP_PROJECT_ID=your-actual-project-id"
    exit 1
fi

echo "Project ID: ${PROJECT_ID}"
echo ""

# Wait for Kafka Connect to be ready
echo "Waiting for Kafka Connect to be ready..."
until curl -s "${CONNECT_URL}" > /dev/null; do
    echo "Kafka Connect is unavailable - sleeping"
    sleep 5
done
echo "✓ Kafka Connect is ready"
echo ""

# Function to register a connector
register_connector() {
    local connector_name=$1
    local config_file=$2
    
    echo "-------------------------------------------"
    echo "Registering connector: ${connector_name}"
    echo "-------------------------------------------"
    
    # Check if connector already exists
    if curl -s "${CONNECT_URL}/connectors/${connector_name}" | grep -q "\"name\""; then
        echo "⚠ Connector '${connector_name}' already exists. Deleting..."
        curl -X DELETE "${CONNECT_URL}/connectors/${connector_name}"
        echo "✓ Connector deleted"
        sleep 2
    fi
    
    # Create temporary config with actual project ID
    # Support both ${GCP_PROJECT_ID} and YOUR_GCP_PROJECT_ID formats
    local temp_config="/tmp/${connector_name}-config.json"
    sed -e "s/\${GCP_PROJECT_ID}/${PROJECT_ID}/g" \
        -e "s/YOUR_GCP_PROJECT_ID/${PROJECT_ID}/g" \
        "${config_file}" > "${temp_config}"
    
    # Register the connector
    echo "Registering connector..."
    RESPONSE=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        --data @"${temp_config}" \
        "${CONNECT_URL}/connectors")
    
    # Clean up temp file
    rm -f "${temp_config}"
    
    if echo "$RESPONSE" | grep -q "\"name\""; then
        echo "✓ Connector registered successfully!"
        echo ""
        if command -v jq &> /dev/null; then
            echo "Connector details:"
            echo "$RESPONSE" | jq '.'
        else
            echo "$RESPONSE"
        fi
    else
        echo "✗ Failed to register connector"
        echo "Response: $RESPONSE"
        return 1
    fi
    
    echo ""
}

# Register accounts connector
register_connector "bigquery-sink-accounts" "${SCRIPT_DIR}/bigquery-sink-accounts.json"

# Register transactions connector
register_connector "bigquery-sink-transactions" "${SCRIPT_DIR}/bigquery-sink-transactions.json"

# Wait for connectors to start
echo "Waiting for connectors to start..."
sleep 10

# Check connector statuses
echo "==========================================="
echo "Connector Statuses"
echo "==========================================="

for connector in "bigquery-sink-accounts" "bigquery-sink-transactions"; do
    echo ""
    echo "--- ${connector} ---"
    STATUS=$(curl -s "${CONNECT_URL}/connectors/${connector}/status")
    if command -v jq &> /dev/null; then
        echo "$STATUS" | jq '.'
    else
        echo "$STATUS"
    fi
    
    # Check if running
    if echo "$STATUS" | grep -q '"state":"RUNNING"'; then
        echo "✓ ${connector} is RUNNING"
    else
        echo "⚠ ${connector} may not be running properly"
    fi
done

echo ""
echo "==========================================="
echo "Setup completed!"
echo "==========================================="
echo ""
echo "Next steps:"
echo "  1. Check connector status: curl ${CONNECT_URL}/connectors/<connector-name>/status"
echo "  2. Insert data in PostgreSQL (from data-ingestion)"
echo "  3. Check BigQuery console for data"
echo ""
echo "BigQuery Console:"
echo "  https://console.cloud.google.com/bigquery?project=${PROJECT_ID}"
echo ""
echo "Example queries:"
echo "  SELECT * FROM \`${PROJECT_ID}.kafka_ingestion.accounts\` LIMIT 10;"
echo "  SELECT * FROM \`${PROJECT_ID}.kafka_ingestion.transactions\` LIMIT 10;"
echo ""