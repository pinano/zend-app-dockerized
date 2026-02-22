# Makefile for Dockerized Zend Framework 1.x App

# Default target
.PHONY: help
help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  help          Show this help message"
	@echo "  init          Initialize environment (.env)"
	@echo "  start         Start the stack (creates & validates .env if missing)"
	@echo "  stop          Stop the stack and remove orphans"
	@echo "  restart       Restart the stack"
	@echo "  rebuild       Rebuild services from Dockerfile (usage: make rebuild [service])"
	@echo "  status        Show stack status (docker compose ps)"
	@echo "  services      List available services"
	@echo "  validate      Validate .env against minimum requirements"
	@echo "  sync          Synchronize .env with .env.dist (Add missing keys)"
	@echo "  logs          Follow logs for all containers or a specific service (usage: make logs [service])"
	@echo "  shell         Open a shell in a container (usage: make shell [service], default: app)"
	@echo "  pull          Pull latest images"
	@echo "  clean         Clean up everything, removing volumes (Requires confirmation)"
	@echo "  config        Validate Docker Compose configuration"
	@echo "  db            Connect to MariaDB console"
	@echo "  ctop          Monitor containers using ctop"
	@echo ""
	@echo "Redis Management:"
	@echo "  redis-info    Show Redis server statistics"
	@echo "  redis-monitor Monitor Redis commands in real-time"
	@echo "  redis-ping    Ping Redis server"
	@echo ""
	@echo "Cron Management:"
	@echo "  crontab-init Create example crontab file"
	@echo ""
	@echo "Sizing:"
	@echo "  size-small   Configure .env for low-traffic app (< 500 visits/day)"
	@echo "  size-medium  Configure .env for medium-traffic app (500-5000 visits/day)"
	@echo "  size-large   Configure .env for high-traffic app (> 5000 visits/day)"
	@echo "  size-show    Show current sizing configuration"

.PHONY: init
init:
	@if [ ! -f .env ]; then \
		echo "⚙️  Initializing .env from .env.dist..."; \
		cp .env.dist .env; \
		echo "✅ .env created. Please review variables before starting."; \
	else \
		echo "ℹ️  .env already exists."; \
	fi

.PHONY: start
start:
	@if [ ! -f .env ]; then \
		echo "⚠️  .env file not found, creating one from .env.dist..."; \
		cp .env.dist .env; \
	fi
	@$(MAKE) validate
	@echo "🐳 Starting containers..."
	@docker compose up -d --remove-orphans
	@echo "✅ Stack is up!"

.PHONY: validate
validate:
	@echo "Validating .env configuration..."
	@[ -n "$$(grep '^PROJECT_NAME=' .env | cut -d= -f2 | head -1)" ] || \
		(echo "❌ ERROR: PROJECT_NAME is not set!"; exit 1)
	@[ -n "$$(grep '^DB_NAME=' .env | cut -d= -f2 | head -1)" ] || \
		(echo "❌ ERROR: DB_NAME is not set!"; exit 1)
	@[ -n "$$(grep '^DB_USER=' .env | cut -d= -f2 | head -1)" ] || \
		(echo "❌ ERROR: DB_USER is not set!"; exit 1)
	@[ -n "$$(grep '^DB_PASS=' .env | cut -d= -f2 | head -1)" ] || \
		(echo "❌ ERROR: DB_PASS is not set!"; exit 1)
	@grep -q "^DB_PASS=dbrootpass" .env && \
		echo "⚠️  WARNING: DB_PASS is using default password!" || true
	@grep -q "^DB_ROOT_PASS=dbrootpass" .env && \
		echo "⚠️  WARNING: DB_ROOT_PASS is using default password!" || true
	@grep -q "^SFTP_PASS=sftppass" .env && \
		echo "⚠️  WARNING: SFTP_PASS is using default password!" || true

.PHONY: stop
stop:
	@echo "🛑 Stopping containers..."
	@docker compose down --remove-orphans
	@echo "✅ Stack is down!"

.PHONY: restart
restart:
	@echo "🔄 Restarting stack..."
	@$(MAKE) stop
	@$(MAKE) start

.PHONY: status
status:
	@docker compose ps

.PHONY: services
services:
	@docker compose config --services

.PHONY: sync
sync:
	@echo "🔄 Synchronizing .env with .env.dist..."
	@awk -F= '!/^#/ && NF>0 {print $$1}' .env.dist | while read key; do \
		if ! grep -q "^$$key=" .env; then \
			value=$$(grep "^$$key=" .env.dist | cut -d= -f2-); \
			echo "$$key=$$value" >> .env; \
			echo "➕ Added missing key: $$key"; \
		fi \
	done
	@echo "✅ Sync complete."

.PHONY: logs
logs:
	@docker compose logs -f $(filter-out $@,$(MAKECMDGOALS))

.PHONY: shell
shell:
	@SERVICE="$(filter-out $@,$(MAKECMDGOALS))"; \
	if [ -z "$$SERVICE" ]; then SERVICE="app"; fi; \
	docker compose exec $$SERVICE /bin/bash 2>/dev/null || docker compose exec $$SERVICE /bin/sh

.PHONY: pull
pull:
	@docker compose pull

.PHONY: clean
clean:
	@read -p "⚠️  WARNING: This will remove containers, networks, and VOLUMES. Area you sure? [y/N] " ans && \
	if [ $${ans:-N} = y ]; then \
		docker compose down -v --remove-orphans; \
		echo "🧹 Clean complete."; \
	else \
		echo "Aborting clean."; \
	fi

.PHONY: config
config:
	@docker compose config

.PHONY: rebuild
rebuild:
	@docker compose build $(filter-out $@,$(MAKECMDGOALS))

.PHONY: db
db:
	@echo "🔌 Connecting to database..."
	@docker compose exec db sh -c 'MYSQL_PWD=$${MARIADB_PASSWORD} mariadb -u $${MARIADB_USER} $${MARIADB_DATABASE}'

.PHONY: ctop
ctop:
	@docker run --rm -ti \
		--name=ctop \
		--volume /var/run/docker.sock:/var/run/docker.sock:ro \
		quay.io/vektorlab/ctop:latest

.PHONY: redis-info
redis-info:
	@docker compose exec redis valkey-cli info

.PHONY: redis-monitor
redis-monitor:
	@echo "📡 Monitoring Redis commands... (Press Ctrl+C to stop)"
	@docker compose exec redis valkey-cli monitor

.PHONY: redis-ping
redis-ping:
	@docker compose exec redis valkey-cli ping

# --- Sizing Profiles ---
# Helper function to update a variable in .env (works on both macOS and Linux)
define set_env
	@if grep -q "^$(1)=" .env; then \
		if [ "$$(uname)" = "Darwin" ]; then \
			sed -i '' 's|^$(1)=.*|$(1)=$(2)|' .env; \
		else \
			sed -i 's|^$(1)=.*|$(1)=$(2)|' .env; \
		fi \
	else \
		awk 'END {if (NR>0 && $$0!="") printf "\n"}' .env >> .env; \
		echo "$(1)=$(2)" >> .env; \
	fi
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
	$(call set_env,CRON_TMPFS_SIZE,64M)
	$(call set_env,DB_CPUS,1.0)
	$(call set_env,DB_MEMORY,512M)
	$(call set_env,DB_MEMORY_RESERVATION,128M)
	$(call set_env,DB_INNODB_BUFFER_POOL_SIZE,128M)
	$(call set_env,DB_INNODB_LOG_FILE_SIZE,32M)
	$(call set_env,DB_MAX_CONNECTIONS,50)
	$(call set_env,PHP_MEMORY_LIMIT,128M)
	$(call set_env,PHP_OPCACHE_MEMORY_CONSUMPTION,128)
	$(call set_env,APP_TMPFS_SIZE,128M)
	@# $(call set_env,PHP_REALPATH_CACHE_SIZE,32M) # Currently not available in serversideup images
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
	$(call set_env,CRON_TMPFS_SIZE,128M)
	$(call set_env,DB_CPUS,2.0)
	$(call set_env,DB_MEMORY,1G)
	$(call set_env,DB_MEMORY_RESERVATION,256M)
	$(call set_env,DB_INNODB_BUFFER_POOL_SIZE,256M)
	$(call set_env,DB_INNODB_LOG_FILE_SIZE,64M)
	$(call set_env,DB_MAX_CONNECTIONS,100)
	$(call set_env,PHP_MEMORY_LIMIT,256M)
	$(call set_env,PHP_OPCACHE_MEMORY_CONSUMPTION,256)
	$(call set_env,APP_TMPFS_SIZE,256M)
	@# $(call set_env,PHP_REALPATH_CACHE_SIZE,64M) # Currently not available in serversideup images
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
	$(call set_env,CRON_TMPFS_SIZE,256M)
	$(call set_env,DB_CPUS,4.0)
	$(call set_env,DB_MEMORY,2G)
	$(call set_env,DB_MEMORY_RESERVATION,512M)
	$(call set_env,DB_INNODB_BUFFER_POOL_SIZE,512M)
	$(call set_env,DB_INNODB_LOG_FILE_SIZE,128M)
	$(call set_env,DB_MAX_CONNECTIONS,300)
	$(call set_env,PHP_MEMORY_LIMIT,512M)
	$(call set_env,PHP_OPCACHE_MEMORY_CONSUMPTION,512)
	$(call set_env,APP_TMPFS_SIZE,512M)
	@# $(call set_env,PHP_REALPATH_CACHE_SIZE,128M) # Currently not available in serversideup images
	@echo "✅ LARGE profile applied. Run 'make restart' to apply changes."

.PHONY: size-show
size-show: _ensure_env
	@echo "📊 Current sizing configuration:"
	@echo "─────────────────────────────────"
	@echo "  App:   CPU=$$(grep '^APP_CPUS=' .env | cut -d= -f2)  MEM=$$(grep '^APP_MEMORY=' .env | cut -d= -f2)  Tmpfs=$$(grep '^APP_TMPFS_SIZE=' .env | cut -d= -f2)"
	@echo "  Cron:  CPU=$$(grep '^CRON_CPUS=' .env | cut -d= -f2)  MEM=$$(grep '^CRON_MEMORY=' .env | cut -d= -f2)  Tmpfs=$$(grep '^CRON_TMPFS_SIZE=' .env | cut -d= -f2)"
	@echo "  DB:    CPU=$$(grep '^DB_CPUS=' .env | cut -d= -f2)  MEM=$$(grep '^DB_MEMORY=' .env | cut -d= -f2)  BufferPool=$$(grep '^DB_INNODB_BUFFER_POOL_SIZE=' .env | cut -d= -f2)  LogFile=$$(grep '^DB_INNODB_LOG_FILE_SIZE=' .env | cut -d= -f2)  MaxConn=$$(grep '^DB_MAX_CONNECTIONS=' .env | cut -d= -f2)"
	@echo "  PHP:   MemLimit=$$(grep '^PHP_MEMORY_LIMIT=' .env | cut -d= -f2)  OPcache=$$(grep '^PHP_OPCACHE_MEMORY_CONSUMPTION=' .env | cut -d= -f2)MB"
	@echo "─────────────────────────────────"

.PHONY: crontab-init
crontab-init:
	@if [ ! -f .docker/scripts/crontab ]; then \
		mkdir -p .docker/scripts; \
		echo "# m h dom mon dow user  command" > .docker/scripts/crontab; \
		echo "# * * * * * www-data php /var/www/html/scripts/cron.php" >> .docker/scripts/crontab; \
		echo "✅ Created example crontab at .docker/scripts/crontab"; \
	else \
		echo "ℹ️  crontab file already exists."; \
	fi

# Catch-all target for positional arguments
%:
	@: