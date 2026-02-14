#!/bin/bash

if [ ! -f .env ]; then
    echo "⚠️  .env file not found, creating one from .env.dist..."
    cp .env.dist .env
fi

echo "🐳 Deploying containers..."
docker compose \
    -f docker-compose.yml \
    up -d --force-recreate --remove-orphans

echo "✅ Deployment finished"
