#!/bin/bash

echo "🛑 Stopping and cleaning up containers..."

docker compose \
    -f docker-compose.yml \
    down --remove-orphans

echo "✅ Project stopped"
