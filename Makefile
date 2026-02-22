# Makefile for Dockerized Zend Framework 1.x App

# Default target
.PHONY: help
help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  start       Start the stack (creates .env if missing)"
	@echo "  stop        Stop the stack and remove orphans"
	@echo "  restart     Restart the stack"
	@echo "  logs        Tail container logs"
	@echo "  shell       Open a shell in the app container"
	@echo "  config      Validate Docker Compose configuration"
	@echo "  build       Rebuild the app container"
	@echo "  db          Connect to MariaDB console"
	@echo ""
	@echo "Sizing:"
	@echo "  size-small   Configure .env for low-traffic app (< 500 visits/day)"
	@echo "  size-medium  Configure .env for medium-traffic app (500-5000 visits/day)"
	@echo "  size-large   Configure .env for high-traffic app (> 5000 visits/day)"
	@echo "  size-show    Show current sizing configuration"

.PHONY: start
start:
	@if [ ! -f .env ]; then \
		echo "⚠️  .env file not found, creating one from .env.dist..."; \
		cp .env.dist .env; \
	fi
	@echo "🐳 Starting containers..."
	@docker compose up -d --remove-orphans
	@echo "✅ Stack is up!"

.PHONY: stop
stop:
	@echo "🛑 Stopping containers..."
	@docker compose down --remove-orphans
	@echo "✅ Stack is down!"

.PHONY: restart
restart: stop start

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

# --- Sizing Profiles ---
# Helper function to update a variable in .env (works on both macOS and Linux)
define set_env
	@sed -i.bak 's/^$(1)=.*/$(1)=$(2)/' .env && rm -f .env.bak
endef

.PHONY: _ensure_env
_ensure_env:
	@if [ ! -f .env ]; then \
		echo "⚠️  .env file not found, creating one from .env.dist..."; \
		cp .env.dist .env; \
	fi

.PHONY: size-small
size-small: _ensure_env
	@echo "📐 Applying SMALL profile (< 500 visits/day)..."
	$(call set_env,APP_CPUS,0.5)
	$(call set_env,APP_MEMORY,256M)
	$(call set_env,APP_MEMORY_RESERVATION,64M)
	$(call set_env,CRON_CPUS,0.1)
	$(call set_env,CRON_MEMORY,128M)
	$(call set_env,CRON_MEMORY_RESERVATION,32M)
	$(call set_env,DB_CPUS,0.5)
	$(call set_env,DB_MEMORY,512M)
	$(call set_env,DB_MEMORY_RESERVATION,128M)
	$(call set_env,DB_INNODB_BUFFER_POOL_SIZE,128M)
	$(call set_env,DB_MAX_CONNECTIONS,50)
	$(call set_env,PHP_OPCACHE_MEMORY_CONSUMPTION,128)
	@echo "✅ SMALL profile applied. Run 'make restart' to apply changes."

.PHONY: size-medium
size-medium: _ensure_env
	@echo "📐 Applying MEDIUM profile (500-5000 visits/day)..."
	$(call set_env,APP_CPUS,1.0)
	$(call set_env,APP_MEMORY,512M)
	$(call set_env,APP_MEMORY_RESERVATION,128M)
	$(call set_env,CRON_CPUS,0.25)
	$(call set_env,CRON_MEMORY,256M)
	$(call set_env,CRON_MEMORY_RESERVATION,64M)
	$(call set_env,DB_CPUS,2.0)
	$(call set_env,DB_MEMORY,1G)
	$(call set_env,DB_MEMORY_RESERVATION,256M)
	$(call set_env,DB_INNODB_BUFFER_POOL_SIZE,256M)
	$(call set_env,DB_MAX_CONNECTIONS,100)
	$(call set_env,PHP_OPCACHE_MEMORY_CONSUMPTION,256)
	@echo "✅ MEDIUM profile applied. Run 'make restart' to apply changes."

.PHONY: size-large
size-large: _ensure_env
	@echo "📐 Applying LARGE profile (> 5000 visits/day)..."
	$(call set_env,APP_CPUS,2.0)
	$(call set_env,APP_MEMORY,1G)
	$(call set_env,APP_MEMORY_RESERVATION,256M)
	$(call set_env,CRON_CPUS,0.5)
	$(call set_env,CRON_MEMORY,512M)
	$(call set_env,CRON_MEMORY_RESERVATION,128M)
	$(call set_env,DB_CPUS,4.0)
	$(call set_env,DB_MEMORY,2G)
	$(call set_env,DB_MEMORY_RESERVATION,512M)
	$(call set_env,DB_INNODB_BUFFER_POOL_SIZE,512M)
	$(call set_env,DB_MAX_CONNECTIONS,300)
	$(call set_env,PHP_OPCACHE_MEMORY_CONSUMPTION,512)
	@echo "✅ LARGE profile applied. Run 'make restart' to apply changes."

.PHONY: size-show
size-show: _ensure_env
	@echo "📊 Current sizing configuration:"
	@echo "─────────────────────────────────"
	@echo "  App:   CPU=$$(grep '^APP_CPUS=' .env | cut -d= -f2)  MEM=$$(grep '^APP_MEMORY=' .env | cut -d= -f2)"
	@echo "  Cron:  CPU=$$(grep '^CRON_CPUS=' .env | cut -d= -f2)  MEM=$$(grep '^CRON_MEMORY=' .env | cut -d= -f2)"
	@echo "  DB:    CPU=$$(grep '^DB_CPUS=' .env | cut -d= -f2)  MEM=$$(grep '^DB_MEMORY=' .env | cut -d= -f2)  BufferPool=$$(grep '^DB_INNODB_BUFFER_POOL_SIZE=' .env | cut -d= -f2)  MaxConn=$$(grep '^DB_MAX_CONNECTIONS=' .env | cut -d= -f2)"
	@echo "  PHP:   OPcache=$$(grep '^PHP_OPCACHE_MEMORY_CONSUMPTION=' .env | cut -d= -f2)MB"
	@echo "─────────────────────────────────"