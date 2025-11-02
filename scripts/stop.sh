#!/bin/bash

# Stop Kafka Connect with BigQuery Sink Connector

set -e

echo "==========================================="
echo "Stopping Kafka Connect"
echo "==========================================="

docker-compose stop

echo ""
echo "✓ Services stopped successfully!"
echo ""
echo "To start again: ./scripts/start.sh"
echo ""
