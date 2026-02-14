#!/bin/bash

echo "🛑 Deteniendo y limpiando contenedores..."

docker compose \
    -f docker-compose.yml \
    down --remove-orphans

echo "✅ Proyecto detenido"
