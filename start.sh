#!/bin/bash

echo "🐳 Desplegando contenedores..."
docker compose \
    -f docker-compose.yml \
    up -d --force-recreate --remove-orphans

echo "✅ Despliegue finalizado"
