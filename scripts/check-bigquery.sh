#!/bin/bash

# Check BigQuery tables and data

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load environment variables
if [ -f "${SCRIPT_DIR}/../.env" ]; then
    export $(cat "${SCRIPT_DIR}/../.env" | grep -v '^#' | xargs)
fi

PROJECT_ID="${GCP_PROJECT_ID:-}"
DATASET="kafka_ingestion"

# Check if PROJECT_ID is set
if [ -z "$PROJECT_ID" ]; then
    echo "❌ Error: GCP_PROJECT_ID not set"
    echo ""
    echo "Please configure your .env file:"
    echo "  GCP_PROJECT_ID=your-actual-project-id"
    exit 1
fi

echo "==========================================="
echo "BigQuery Data Check"
echo "==========================================="
echo "Project: ${PROJECT_ID}"
echo "Dataset: ${DATASET}"
echo ""

# Check if bq is installed
if ! command -v bq &> /dev/null; then
    echo "⚠ bq CLI is not installed"
    echo ""
    echo "Check BigQuery Console instead:"
    echo "  https://console.cloud.google.com/bigquery?project=${PROJECT_ID}"
    echo ""
    exit 0
fi

# List tables
echo "--- Tables ---"
bq ls ${PROJECT_ID}:${DATASET} 2>/dev/null || {
    echo "❌ Unable to access dataset"
    echo ""
    echo "Please check:"
    echo "  1. gcloud auth login"
    echo "  2. Dataset exists: ./gcp/setup-bigquery.sh"
    exit 1
}

echo ""
echo "--- Row Counts ---"
bq query --use_legacy_sql=false --format=pretty \
    "SELECT 
        'accounts' as table_name, 
        COUNT(*) as row_count 
     FROM \`${PROJECT_ID}.${DATASET}.accounts\` 
     UNION ALL 
     SELECT 
        'transactions' as table_name, 
        COUNT(*) as row_count 
     FROM \`${PROJECT_ID}.${DATASET}.transactions\`" 2>/dev/null || {
    echo "Unable to query tables"
    echo "Tables may not exist yet. They will be auto-created by connectors."
}

echo ""
echo "--- Latest Data ---"
echo ""
echo "Accounts (last 5):"
bq query --use_legacy_sql=false --format=pretty \
    "SELECT account_id, user_id, balance, status, created_at 
     FROM \`${PROJECT_ID}.${DATASET}.accounts\` 
     ORDER BY created_at DESC 
     LIMIT 5" 2>/dev/null || echo "No data or table doesn't exist"

echo ""
echo "Transactions (last 5):"
bq query --use_legacy_sql=false --format=pretty \
    "SELECT tx_id, account_id, tx_type, amount, status, created_at 
     FROM \`${PROJECT_ID}.${DATASET}.transactions\` 
     ORDER BY created_at DESC 
     LIMIT 5" 2>/dev/null || echo "No data or table doesn't exist"

echo ""
echo "==========================================="
echo ""
echo "BigQuery Console:"
echo "  https://console.cloud.google.com/bigquery?project=${PROJECT_ID}"
echo ""
