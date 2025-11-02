#!/bin/bash

# Start Kafka Connect with BigQuery Sink Connector

set -e

echo "==========================================="
echo "Starting Kafka Connect with BigQuery Sink"
echo "==========================================="

# Check if service account key exists
if [ ! -f "gcp/service-account-key.json" ]; then
    echo "❌ Error: Service account key not found!"
    echo ""
    echo "Please copy your GCP service account key:"
    echo "  cp ~/Downloads/your-key.json gcp/service-account-key.json"
    echo "  chmod 600 gcp/service-account-key.json"
    exit 1
fi


# Start service
echo "Starting Kafka Connect..."
docker-compose up -d

echo ""
echo "Waiting for Kafka Connect to start (this may take 60-90 seconds)..."
echo "The BigQuery connector plugin needs to be downloaded and installed."
sleep 10

# Wait for service to be healthy
echo ""
echo "Checking service status..."
for i in {1..12}; do
    if docker-compose ps | grep -q "Up (healthy)"; then
        echo "✓ Kafka Connect is healthy"
        break
    fi
    if [ $i -eq 12 ]; then
        echo "⚠ Service is taking longer than expected to start"
        echo "Check logs: docker-compose logs connect-bigquery"
        exit 1
    fi
    echo "Waiting... ($((i*5)) seconds elapsed)"
    sleep 5
done

# Check if BigQuery connector plugin is installed
echo ""
echo "Checking BigQuery connector plugin..."
for i in {1..18}; do
    if curl -s http://localhost:8084/connector-plugins 2>/dev/null | grep -q "BigQuerySinkConnector"; then
        echo "✓ BigQuery connector plugin is installed"
        break
    fi
    if [ $i -eq 18 ]; then
        echo "⚠ BigQuery connector plugin not detected"
        echo "Check logs: docker-compose logs connect-bigquery"
        exit 1
    fi
    echo "Waiting for plugin installation... ($((i*5)) seconds elapsed)"
    sleep 5
done

echo ""
echo "==========================================="
echo "✓ Services started successfully!"
echo "==========================================="
echo ""
echo "Next steps:"
echo "  1. Register connectors: ./scripts/register-connectors.sh"
echo "  2. Check status: ./scripts/check-connectors.sh"
echo "  3. View logs: docker-compose logs -f connect-bigquery"
echo ""
echo "Kafka Connect API: http://localhost:8084"
echo ""