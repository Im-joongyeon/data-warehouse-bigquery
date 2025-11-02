#!/bin/bash

# Debug version of setup-bigquery.sh to troubleshoot .env loading

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==========================================="
echo "DEBUG: Environment Variable Loading"
echo "==========================================="
echo "Script directory: ${SCRIPT_DIR}"
echo "Looking for .env at: ${SCRIPT_DIR}/../.env"
echo ""

# Check if .env file exists
if [ -f "${SCRIPT_DIR}/../.env" ]; then
    echo "✓ .env file found"
    echo ""
    echo "--- .env file contents ---"
    cat "${SCRIPT_DIR}/../.env"
    echo ""
    echo "--- End of .env file ---"
    echo ""
    
    # Load environment variables
    echo "Loading environment variables..."
    export $(cat "${SCRIPT_DIR}/../.env" | grep -v '^#' | xargs)
    echo "✓ Environment variables loaded"
    echo ""
else
    echo "❌ .env file NOT found at: ${SCRIPT_DIR}/../.env"
    echo ""
    echo "Please create .env file:"
    echo "  cd ${SCRIPT_DIR}/.."
    echo "  cp .env.example .env"
    echo "  vi .env"
    exit 1
fi

# Check environment variables
echo "--- Environment Variables ---"
echo "GCP_PROJECT_ID: '${GCP_PROJECT_ID}'"
echo "GCP_DATASET: '${GCP_DATASET}'"
echo "GCP_LOCATION: '${GCP_LOCATION}'"
echo ""

# Set variables
PROJECT_ID="${GCP_PROJECT_ID:-your-project-id}"
DATASET="${GCP_DATASET:-kafka_ingestion}"
LOCATION="${GCP_LOCATION:-US}"

echo "--- Final Variables ---"
echo "PROJECT_ID: '${PROJECT_ID}'"
echo "DATASET: '${DATASET}'"
echo "LOCATION: '${LOCATION}'"
echo ""

# Check if PROJECT_ID is set
if [ "$PROJECT_ID" = "your-project-id" ] || [ -z "$PROJECT_ID" ]; then
    echo "❌ Error: GCP_PROJECT_ID not set properly"
    echo ""
    echo "Please configure your .env file:"
    echo "  cd ${SCRIPT_DIR}/.."
    echo "  vi .env"
    echo ""
    echo "Set the following:"
    echo "  GCP_PROJECT_ID=your-actual-project-id"
    echo "  GCP_DATASET=kafka_ingestion"
    echo "  GCP_LOCATION=asia-northeast3"
    exit 1
else
    echo "✓ PROJECT_ID is set correctly"
fi

echo ""
echo "==========================================="
echo "✓ All checks passed!"
echo "==========================================="