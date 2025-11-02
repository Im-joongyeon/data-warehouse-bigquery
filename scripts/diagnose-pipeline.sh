#!/bin/bash

# Comprehensive pipeline diagnostics
# Checks the entire PostgreSQL -> Debezium -> Kafka -> BigQuery pipeline

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load environment variables
if [ -f "${SCRIPT_DIR}/../.env" ]; then
    export $(cat "${SCRIPT_DIR}/../.env" | grep -v '^#' | xargs)
fi

PROJECT_ID="${GCP_PROJECT_ID:-}"
CONNECT_URL="http://localhost:8084"

echo "==========================================="
echo "Data Pipeline Comprehensive Diagnostics"
echo "==========================================="
echo ""

# ============================================
# 1. Environment Check
# ============================================
echo "--- 1. Environment Check ---"
if [ -z "$PROJECT_ID" ]; then
    echo "❌ GCP_PROJECT_ID not set in .env"
else
    echo "✓ GCP_PROJECT_ID: ${PROJECT_ID}"
fi

if [ ! -f "${SCRIPT_DIR}/../gcp/service-account-key.json" ]; then
    echo "❌ Service account key not found"
else
    echo "✓ Service account key exists"
fi
echo ""

# ============================================
# 2. Kafka Connect Status
# ============================================
echo "--- 2. Kafka Connect Status ---"
if curl -s "${CONNECT_URL}" > /dev/null 2>&1; then
    echo "✓ Kafka Connect is running at ${CONNECT_URL}"
    
    # Check available plugins
    PLUGINS=$(curl -s "${CONNECT_URL}/connector-plugins" 2>/dev/null)
    if echo "$PLUGINS" | grep -q "BigQuerySinkConnector"; then
        echo "✓ BigQuery Sink Connector plugin available"
    else
        echo "❌ BigQuery Sink Connector plugin NOT found"
    fi
else
    echo "❌ Kafka Connect is not running"
    echo "   Start with: ./scripts/start.sh"
    exit 1
fi
echo ""

# ============================================
# 3. Connector Status
# ============================================
echo "--- 3. Connector Status ---"
for connector in "bigquery-sink-accounts" "bigquery-sink-transactions"; do
    echo ""
    echo "[${connector}]"
    STATUS=$(curl -s "${CONNECT_URL}/connectors/${connector}/status" 2>/dev/null)
    
    if echo "$STATUS" | grep -q '"state":"RUNNING"'; then
        echo "  ✓ State: RUNNING"
        
        # Get task status
        TASK_STATE=$(echo "$STATUS" | grep -o '"state":"[^"]*"' | head -2 | tail -1 | cut -d'"' -f4)
        echo "  ✓ Task state: ${TASK_STATE}"
    else
        echo "  ❌ Not running"
        echo "  Status: ${STATUS}"
    fi
    
    # Get config
    CONFIG=$(curl -s "${CONNECT_URL}/connectors/${connector}/config" 2>/dev/null)
    TOPIC=$(echo "$CONFIG" | grep -o '"topics":"[^"]*"' | cut -d'"' -f4)
    OFFSET_RESET=$(echo "$CONFIG" | grep -o '"consumer.override.auto.offset.reset":"[^"]*"' | cut -d'"' -f4)
    TRANSFORMS=$(echo "$CONFIG" | grep -o '"transforms":"[^"]*"' | cut -d'"' -f4)
    
    echo "  Topic: ${TOPIC}"
    echo "  Offset reset: ${OFFSET_RESET:-default (latest)}"
    echo "  Transforms: ${TRANSFORMS:-none}"
done
echo ""

# ============================================
# 4. Kafka Topics Check
# ============================================
echo "--- 4. Kafka Topics Check ---"
KAFKA_CONTAINER=$(docker ps --filter "name=kafka" --format "{{.Names}}" | grep -v "connect" | head -n 1)

if [ -z "$KAFKA_CONTAINER" ]; then
    echo "❌ Kafka container not found"
else
    echo "✓ Kafka container: ${KAFKA_CONTAINER}"
    echo ""
    
    for topic in "dbserver1.public.accounts" "dbserver1.public.transactions"; do
        echo "[${topic}]"
        
        # Check if topic exists
        if docker exec "${KAFKA_CONTAINER}" kafka-topics --list --bootstrap-server localhost:9092 2>/dev/null | grep -q "^${topic}$"; then
            echo "  ✓ Topic exists"
            
            # Get topic info
            TOPIC_INFO=$(docker exec "${KAFKA_CONTAINER}" kafka-run-class kafka.tools.GetOffsetShell \
                --broker-list localhost:9092 \
                --topic "${topic}" 2>/dev/null || echo "error")
            
            if [ "$TOPIC_INFO" != "error" ] && [ -n "$TOPIC_INFO" ]; then
                # Parse offset info
                END_OFFSET=$(echo "$TOPIC_INFO" | grep -oE ":[0-9]+:" | tail -1 | tr -d ':')
                if [ -n "$END_OFFSET" ]; then
                    echo "  ✓ Total messages (approximate): ${END_OFFSET}"
                    
                    # Try to read a sample message
                    SAMPLE=$(docker exec "${KAFKA_CONTAINER}" kafka-console-consumer \
                        --bootstrap-server localhost:9092 \
                        --topic "${topic}" \
                        --from-beginning \
                        --max-messages 1 \
                        --timeout-ms 3000 2>/dev/null | head -1 || echo "")
                    
                    if [ -n "$SAMPLE" ]; then
                        echo "  ✓ Sample message format:"
                        echo "    $(echo "$SAMPLE" | cut -c1-80)..."
                        
                        # Check message structure
                        if echo "$SAMPLE" | grep -q '"after"'; then
                            echo "  ⚠ Message has 'after' field (Debezium format)"
                        elif echo "$SAMPLE" | grep -q '"account_id"\|"tx_id"'; then
                            echo "  ✓ Message is in flat format (no 'after' wrapper)"
                        fi
                    else
                        echo "  ⚠ Could not read sample message"
                    fi
                else
                    echo "  ⚠ Could not determine message count"
                fi
            else
                echo "  ⚠ Could not get topic info"
            fi
        else
            echo "  ❌ Topic does not exist"
        fi
        echo ""
    done
fi
echo ""

# ============================================
# 5. BigQuery Tables Check
# ============================================
echo "--- 5. BigQuery Tables Check ---"
if [ -z "$PROJECT_ID" ]; then
    echo "⚠ Skipping (PROJECT_ID not set)"
else
    DATASET="kafka_ingestion"
    
    if command -v bq &> /dev/null; then
        echo "✓ bq CLI available"
        
        # List tables
        TABLES=$(bq ls ${PROJECT_ID}:${DATASET} 2>/dev/null || echo "")
        
        if [ -n "$TABLES" ]; then
            for table in "accounts" "transactions"; do
                echo ""
                echo "[${table}]"
                
                # Check if table exists
                if echo "$TABLES" | grep -q "${table}"; then
                    echo "  ✓ Table exists"
                    
                    # Get row count
                    COUNT=$(bq query --use_legacy_sql=false --format=csv \
                        "SELECT COUNT(*) as cnt FROM \`${PROJECT_ID}.${DATASET}.${table}\`" 2>/dev/null | tail -1 || echo "error")
                    
                    if [ "$COUNT" != "error" ] && [ -n "$COUNT" ]; then
                        echo "  ✓ Row count: ${COUNT}"
                    else
                        echo "  ⚠ Could not get row count"
                    fi
                    
                    # Get sample data
                    SAMPLE=$(bq query --use_legacy_sql=false --format=pretty \
                        "SELECT * FROM \`${PROJECT_ID}.${DATASET}.${table}\` LIMIT 1" 2>/dev/null || echo "")
                    
                    if [ -n "$SAMPLE" ] && ! echo "$SAMPLE" | grep -q "does not exist"; then
                        echo "  ✓ Sample data available"
                    fi
                else
                    echo "  ❌ Table does not exist"
                    echo "     (Will be auto-created by connector)"
                fi
            done
        else
            echo "❌ Dataset '${DATASET}' does not exist or not accessible"
        fi
    else
        echo "⚠ bq CLI not installed - skipping BigQuery checks"
    fi
fi
echo ""

# ============================================
# 6. Connector Logs (Recent Errors)
# ============================================
echo "--- 6. Recent Connector Logs (Errors/Warnings) ---"
CONTAINER=$(docker ps --filter "name=connect-bigquery" --format "{{.Names}}" | head -n 1)

if [ -n "$CONTAINER" ]; then
    echo "Container: ${CONTAINER}"
    echo ""
    
    # Get recent errors/warnings
    ERRORS=$(docker logs --tail 200 "${CONTAINER}" 2>&1 | \
        grep -i -E "(error|exception|failed|warn|bigquery-sink)" | \
        grep -v "INFO.*GET /connectors" | tail -10)
    
    if [ -n "$ERRORS" ]; then
        echo "$ERRORS"
    else
        echo "✓ No recent errors found"
    fi
else
    echo "❌ connect-bigquery container not found"
fi
echo ""

# ============================================
# Summary & Recommendations
# ============================================
echo "==========================================="
echo "Summary & Recommendations"
echo "==========================================="
echo ""
echo "Next steps:"
echo "  1. If topics have messages but BigQuery is empty:"
echo "     - Check connector logs: docker logs -f ${CONTAINER}"
echo "     - Verify message format matches connector transforms"
echo ""
echo "  2. If connector is not reading from beginning:"
echo "     - Delete and re-register: ./connectors/register_sink.sh"
echo "     - Or reset offsets: docker exec kafka kafka-consumer-groups --bootstrap-server localhost:9092 --group connect-bigquery-sink-accounts --reset-offsets --to-earliest --topic dbserver1.public.accounts --execute"
echo ""
echo "  3. If messages have wrong format:"
echo "     - Check Debezium source connector configuration"
echo "     - Verify transform chain in sink connector"
echo ""
echo "  4. View detailed logs:"
echo "     ./scripts/check-connector-logs.sh bigquery-sink-accounts"
echo ""

