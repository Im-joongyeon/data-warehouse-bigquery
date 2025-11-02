#!/bin/bash

# Script to setup BigQuery dataset and tables

set -e

# Load environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "${SCRIPT_DIR}/../.env" ]; then
    export $(cat "${SCRIPT_DIR}/../.env" | grep -v '^#' | xargs)
fi

PROJECT_ID="${GCP_PROJECT_ID:-your-project-id}"
DATASET="${GCP_DATASET:-kafka_ingestion}"
LOCATION="${GCP_LOCATION:-US}"

echo "==========================================="
echo "BigQuery Setup Script"
echo "==========================================="
echo "Project ID: ${PROJECT_ID}"
echo "Dataset: ${DATASET}"
echo "Location: ${LOCATION}"
echo ""

if [ "$PROJECT_ID" = "your-project-id" ]; then
    echo "❌ Error: GCP_PROJECT_ID not set"
    echo ""
    echo "Please configure your .env file:"
    echo "  cp .env.example .env"
    echo "  # Edit .env and set GCP_PROJECT_ID=your-actual-project-id"
    exit 1
fi

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo "❌ gcloud CLI is not installed"
    echo "Install from: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

# Check if bq is installed
if ! command -v bq &> /dev/null; then
    echo "❌ bq CLI is not installed (comes with gcloud)"
    exit 1
fi

echo "✓ gcloud and bq CLIs are installed"
echo ""

# Set project
echo "Setting GCP project..."
gcloud config set project ${PROJECT_ID}
echo "✓ Project set to ${PROJECT_ID}"
echo ""

# Create dataset if it doesn't exist
echo "Creating dataset ${DATASET}..."
if bq ls ${PROJECT_ID}:${DATASET} &> /dev/null; then
    echo "⚠ Dataset ${DATASET} already exists"
else
    bq mk --dataset --location=${LOCATION} ${PROJECT_ID}:${DATASET}
    echo "✓ Dataset ${DATASET} created"
fi
echo ""

# Create accounts table
echo "Creating accounts table..."
if bq show ${PROJECT_ID}:${DATASET}.accounts &> /dev/null; then
    echo "⚠ Table accounts already exists"
    read -p "Do you want to delete and recreate it? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        bq rm -f -t ${PROJECT_ID}:${DATASET}.accounts
        bq mk --table ${PROJECT_ID}:${DATASET}.accounts ${SCRIPT_DIR}/../schemas/accounts_schema.json
        echo "✓ Table accounts recreated"
    fi
else
    bq mk --table ${PROJECT_ID}:${DATASET}.accounts ${SCRIPT_DIR}/../schemas/accounts_schema.json
    echo "✓ Table accounts created"
fi
echo ""

# Create transactions table
echo "Creating transactions table..."
if bq show ${PROJECT_ID}:${DATASET}.transactions &> /dev/null; then
    echo "⚠ Table transactions already exists"
    read -p "Do you want to delete and recreate it? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        bq rm -f -t ${PROJECT_ID}:${DATASET}.transactions
        bq mk --table ${PROJECT_ID}:${DATASET}.transactions ${SCRIPT_DIR}/../schemas/transactions_schema.json
        echo "✓ Table transactions recreated"
    fi
else
    bq mk --table ${PROJECT_ID}:${DATASET}.transactions ${SCRIPT_DIR}/../schemas/transactions_schema.json
    echo "✓ Table transactions created"
fi
echo ""

# List tables
echo "==========================================="
echo "Created Tables"
echo "==========================================="
bq ls ${PROJECT_ID}:${DATASET}
echo ""

echo "==========================================="
echo "Setup completed!"
echo "==========================================="
echo ""
echo "Next steps:"
echo "  1. Verify tables in BigQuery Console:"
echo "     https://console.cloud.google.com/bigquery?project=${PROJECT_ID}"
echo ""
echo "  2. Start the data-warehouse services:"
echo "     docker-compose up -d"
echo ""
echo "  3. Register BigQuery Sink Connectors:"
echo "     cd kafka-bigquery-connector"
echo "     ./register_sink.sh"
echo ""