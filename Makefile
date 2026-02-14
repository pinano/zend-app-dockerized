# Makefile for Dockerized Zend Framework 1.x App

# Default target
.PHONY: help
help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  up       Start the stack (creates .env if missing)"
	@echo "  down     Stop the stack and remove orphans"
	@echo "  restart  Restart the stack"
	@echo "  logs     Tail container logs"
	@echo "  shell    Open a shell in the app container"
	@echo "  config   Validate Docker Compose configuration"
	@echo "  build    Rebuild the app container"
	@echo "  db       Connect to MariaDB console"

.PHONY: up
up:
	@if [ ! -f .env ]; then \
		echo "⚠️  .env file not found, creating one from .env.dist..."; \
		cp .env.dist .env; \
	fi
	@echo "🐳 Starting containers..."
	@docker compose up -d --remove-orphans
	@echo "✅ Stack is up!"

.PHONY: down
down:
	@echo "🛑 Stopping containers..."
	@docker compose down --remove-orphans
	@echo "✅ Stack is down!"

.PHONY: restart
restart: down up

.PHONY: logs
logs:
	@docker compose logs -f

.PHONY: shell
shell:
	@docker compose exec app /bin/bash 2>/dev/null || docker compose exec app /bin/sh

.PHONY: config
config:
	@docker compose config

.PHONY: build
build:
	@docker compose build

.PHONY: db
db:
	@echo "🔌 Connecting to database..."
	@docker compose exec db sh -c 'mariadb -u $${MARIADB_USER} -p$${MARIADB_PASSWORD} $${MARIADB_DATABASE}'