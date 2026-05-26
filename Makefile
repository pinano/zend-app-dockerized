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
	@echo "  doctor        Run diagnostic checks (port conflicts, host transparent huge pages)"
	@echo "  opcache-clear Clear OPcache for PHP-FPM pool (zero-downtime flush)"
	@echo "  shell         Open a shell in a container (usage: make shell [service], default: app)"
	@echo "  pull          Pull latest images"
	@echo "  clean         Clean up everything, removing volumes (Requires confirmation)"
	@echo "  config        Validate Docker Compose configuration"
	@echo "  php-info      Show active PHP configuration in the container (OPcache, Memory, Errors...)"
	@echo "  db            DB Tools (console, import, export). Run 'make db', 'make db import <file>', 'make db export'"
	@echo "  db-root       Access database console as root user"
	@echo "  ctop          Monitor containers using ctop"
	@echo ""
	@echo "Logging:"
	@echo "  logs          Follow logs for all containers or a specific service (usage: make logs [service])"
	@echo "  logs-apache   Follow Apache access and error logs (standard Docker stream)"
	@echo "  logs-php      Follow PHP-FPM error log directly"
	@echo "  logs-zend     Follow Zend Framework application log directly"
	@echo ""
	@echo "Port Management:"
	@echo "  open-ports    Open DB & SFTP ports to the outside world (0.0.0.0)"
	@echo "  close-ports   Close DB & SFTP ports (restrict to 127.0.0.1)"
	@echo "  open-db       Open only DB port"
	@echo "  close-db      Close only DB port"
	@echo "  open-sftp     Open only SFTP port"
	@echo "  close-sftp    Close only SFTP port"
	@if docker compose config --services 2>/dev/null | grep -q 'redis'; then \
		echo ""; \
		echo "Redis Management:"; \
		echo "  redis-info    Show Redis server statistics"; \
		echo "  redis-monitor Monitor Redis commands in real-time"; \
		echo "  redis-ping    Ping Redis server"; \
	fi
	@echo ""
	@echo "Cron Management:"
	@echo "  crontab-init Create example crontab file"
	@echo ""
	@echo "Sizing:"
	@echo "  size-small    Configure .env for low-traffic app (< 500 visits/day)"
	@echo "  size-medium   Configure .env for medium-traffic app (500-5000 visits/day)"
	@echo "  size-large    Configure .env for high-traffic app (> 5000 visits/day)"
	@echo "  size-show     Show current sizing configuration"

.PHONY: init
init:
	@if [ ! -f .env ]; then \
		echo "⚙️  Initializing .env from .env.dist..."; \
		cp .env.dist .env; \
		dir_name=$$(basename "$$(pwd)"); \
		pid=$$(echo "$$dir_name" | cut -d'-' -f1); \
		if echo "$$pid" | grep -Eq '^[0-9]+$$'; then \
			pname=$$(echo "$$dir_name" | cut -d'-' -f2-); \
			echo "🔍 Detected PROJECT_ID: $$pid, PROJECT_NAME: $$pname"; \
			if [ "$$(uname)" = "Darwin" ]; then \
				sed -i '' "s|^PROJECT_ID=.*|PROJECT_ID=$$pid|" .env; \
				sed -i '' "s|^PROJECT_NAME=.*|PROJECT_NAME=$$pname|" .env; \
			else \
				sed -i "s|^PROJECT_ID=.*|PROJECT_ID=$$pid|" .env; \
				sed -i "s|^PROJECT_NAME=.*|PROJECT_NAME=$$pname|" .env; \
			fi; \
		else \
			printf "🔢 Enter PROJECT_ID (e.g., 999): " && read pid; \
			if [ -n "$$pid" ]; then \
				if [ "$$(uname)" = "Darwin" ]; then \
					sed -i '' "s|^PROJECT_ID=.*|PROJECT_ID=$$pid|" .env; \
				else \
					sed -i "s|^PROJECT_ID=.*|PROJECT_ID=$$pid|" .env; \
				fi; \
				echo "✅ PROJECT_ID set to $$pid"; \
			fi; \
			default_pname=$$(echo "$$dir_name" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_-]//g'); \
			printf "📛 Enter PROJECT_NAME (default: $$default_pname): " && read pname_input; \
			pname=$${pname_input:-$$default_pname}; \
			if [ "$$(uname)" = "Darwin" ]; then \
				sed -i '' "s|^PROJECT_NAME=.*|PROJECT_NAME=$$pname|" .env; \
			else \
				sed -i "s|^PROJECT_NAME=.*|PROJECT_NAME=$$pname|" .env; \
			fi; \
			echo "✅ PROJECT_NAME set to $$pname"; \
		fi; \
		echo "✅ .env created. Please review variables before starting."; \
	else \
		echo "ℹ️  .env already exists."; \
	fi

.PHONY: start
start:
	@if [ ! -f .env ]; then \
		$(MAKE) --no-print-directory init || exit 1; \
	fi
	@$(MAKE) --no-print-directory validate
	@echo "🐳 Starting containers..."
	@. ./docker/scripts/set-env-vars.sh && docker compose up -d --remove-orphans
	@echo "✅ Stack is up!"

.PHONY: validate
validate:
	@echo "Validating .env configuration..."
	@[ -n "$$(grep '^PROJECT_NAME=' .env | cut -d= -f2 | head -1)" ] || \
		(echo "❌ ERROR: PROJECT_NAME is not set!"; exit 1)
	@[ -n "$$(grep '^PROJECT_ID=' .env | cut -d= -f2 | head -1)" ] || \
		(echo "❌ ERROR: PROJECT_ID is not set!"; exit 1)
	@[ -n "$$(grep '^DB_NAME=' .env | cut -d= -f2 | head -1)" ] || \
		(echo "❌ ERROR: DB_NAME is not set!"; exit 1)
	@[ -n "$$(grep '^DB_USER=' .env | cut -d= -f2 | head -1)" ] || \
		(echo "❌ ERROR: DB_USER is not set!"; exit 1)
	@[ -n "$$(grep '^DB_PASS=' .env | cut -d= -f2 | head -1)" ] || \
		(echo "❌ ERROR: DB_PASS is not set!"; exit 1)
	@[ "$$(grep '^USER_ID=' .env | cut -d= -f2 | head -1)" != "0" ] && \
		[ -n "$$(grep '^USER_ID=' .env | cut -d= -f2 | head -1)" ] || \
		(echo "❌ ERROR: USER_ID must be set and non-zero!"; exit 1)
	@[ "$$(grep '^GROUP_ID=' .env | cut -d= -f2 | head -1)" != "0" ] && \
		[ -n "$$(grep '^GROUP_ID=' .env | cut -d= -f2 | head -1)" ] || \
		(echo "❌ ERROR: GROUP_ID must be set and non-zero!"; exit 1)
	@grep -q "^DB_PASS=dbrootpass" .env && \
		echo "⚠️  WARNING: DB_PASS is using default password!" || true
	@grep -q "^DB_ROOT_PASS=dbrootpass" .env && \
		echo "⚠️  WARNING: DB_ROOT_PASS is using default password!" || true
	@grep -q "^SFTP_PASS=sftppass" .env && \
		echo "⚠️  WARNING: SFTP_PASS is using default password!" || true
	@MAX_CONN=$$(grep '^DB_MAX_CONNECTIONS=' .env | cut -d= -f2 | head -1); \
	MAX_CHILDREN=$$(grep '^PHP_FPM_PM_MAX_CHILDREN=' .env | cut -d= -f2 | head -1); \
	if [ -n "$$MAX_CONN" ] && [ -n "$$MAX_CHILDREN" ]; then \
		MIN_CONN=$$((MAX_CHILDREN * 3)); \
		if [ "$$MAX_CONN" -lt "$$MIN_CONN" ]; then \
			echo "⚠️  WARNING: DB_MAX_CONNECTIONS ($$MAX_CONN) < PHP_FPM_PM_MAX_CHILDREN × 3 ($$MIN_CONN). Some ZF1 apps open multiple DB connections per request."; \
		fi; \
	fi
	@echo "✅ Validation passed successfully!"

.PHONY: stop
stop:
	@echo "🛑 Stopping containers..."
	@. ./docker/scripts/set-env-vars.sh && docker compose down --remove-orphans
	@echo "✅ Stack is down!"

.PHONY: restart
restart:
	@echo "🔄 Restarting stack..."
	@$(MAKE) --no-print-directory stop
	@$(MAKE) --no-print-directory start

.PHONY: status
status: _ensure_env
	@. ./docker/scripts/set-env-vars.sh && docker compose ps

.PHONY: services
services: _ensure_env
	@. ./docker/scripts/set-env-vars.sh && docker compose config --services

.PHONY: sync
sync: _ensure_env
	@echo "🔄 Synchronizing .env with .env.dist..."
	@command -v python3 >/dev/null 2>&1 || (echo "❌ python3 is required for 'make sync'. Install it with: apt install python3 / brew install python3"; exit 1)
	@python3 docker/scripts/sync-env.py

.PHONY: logs logs-apache logs-php logs-zend
logs: _ensure_env
	@SERVICE="$(filter-out $@,$(MAKECMDGOALS))"; \
	. ./docker/scripts/set-env-vars.sh && docker compose logs -f $$SERVICE

logs-apache: _ensure_env
	@echo "📋 Tailing Apache logs (Access & Error)..."
	@. ./docker/scripts/set-env-vars.sh && docker compose logs -f app

logs-php: _ensure_env
	@echo "📋 Tailing PHP-FPM error log..."
	@. ./docker/scripts/set-env-vars.sh && docker compose exec app tail -n 100 -f /var/www/html/tmp/php_errors.log

logs-zend: _ensure_env
	@echo "📋 Tailing Zend Framework application log..."
	@. ./docker/scripts/set-env-vars.sh && docker compose exec app tail -n 100 -f /var/www/html/application/logs/error.log

.PHONY: shell
shell: _ensure_env
	@SERVICE="$(filter-out $@,$(MAKECMDGOALS))"; \
	if [ -z "$$SERVICE" ]; then SERVICE="app"; fi; \
	. ./docker/scripts/set-env-vars.sh && docker compose exec $$SERVICE /bin/bash 2>/dev/null || . ./docker/scripts/set-env-vars.sh && docker compose exec $$SERVICE /bin/sh

.PHONY: pull
pull: _ensure_env
	@. ./docker/scripts/set-env-vars.sh && docker compose pull

.PHONY: clean
clean: _ensure_env
	@printf "⚠️  WARNING: This will remove containers, networks, and VOLUMES. Are you sure? [y/N] " && read ans && \
	if [ $${ans:-N} = y ]; then \
		. ./docker/scripts/set-env-vars.sh && docker compose down -v --remove-orphans; \
		echo "🧹 Clean complete."; \
	else \
		echo "Aborting clean."; \
	fi

.PHONY: config
config: _ensure_env
	@. ./docker/scripts/set-env-vars.sh && docker compose config

.PHONY: rebuild
rebuild: _ensure_env
	@. ./docker/scripts/set-env-vars.sh && docker compose build $(filter-out $@,$(MAKECMDGOALS))

.PHONY: db
db: _ensure_env
	@ACTION="$(word 2,$(MAKECMDGOALS))"; \
	if [ "$$ACTION" = "import" ]; then \
		FILE="$(word 3,$(MAKECMDGOALS))"; \
		if [ -z "$$FILE" ]; then \
			echo "❌ ERROR: Please specify a file to import (e.g., make db import file.sql)"; \
			exit 1; \
		fi; \
		if [ ! -f "$$FILE" ]; then \
			echo "❌ ERROR: File $$FILE not found!"; \
			exit 1; \
		fi; \
		echo "📄 Importing $$FILE into database..."; \
		if command -v pv >/dev/null 2>&1; then \
			. ./docker/scripts/set-env-vars.sh && pv "$$FILE" | docker compose exec -T -e MYSQL_PWD=$${DB_PASS} db mariadb -u $${DB_USER} $${DB_NAME}; \
		else \
			echo "💡 Tip: Install 'pv' (e.g., brew install pv / apt install pv) to see a progress bar during imports."; \
			. ./docker/scripts/set-env-vars.sh && docker compose exec -T -e MYSQL_PWD=$${DB_PASS} db mariadb -u $${DB_USER} $${DB_NAME} < "$$FILE"; \
		fi; \
		echo "✅ Import complete!"; \
	elif [ "$$ACTION" = "export" ]; then \
		PROJECT_ID=$$(grep '^PROJECT_ID=' .env | cut -d= -f2 | head -1); \
		PROJECT_NAME=$$(grep '^PROJECT_NAME=' .env | cut -d= -f2 | head -1); \
		TIMESTAMP=$$(date +%Y%m%d_%H%M%S); \
		FILENAME="$${PROJECT_ID}-$${PROJECT_NAME}-$${TIMESTAMP}.sql"; \
		echo "📤 Exporting database to $$FILENAME..."; \
		if command -v pv >/dev/null 2>&1; then \
			. ./docker/scripts/set-env-vars.sh && docker compose exec -T -e MYSQL_PWD=$${DB_PASS} db mariadb-dump --single-transaction -u $${DB_USER} $${DB_NAME} | sed 's/DEFINER[[:space:]]*=[[:space:]]*[^*]*\*/\*/g' | pv > "$$FILENAME"; \
		else \
			echo "💡 Tip: Install 'pv' (e.g., brew install pv / apt install pv) to see a progress tracker during exports."; \
			. ./docker/scripts/set-env-vars.sh && docker compose exec -T -e MYSQL_PWD=$${DB_PASS} db mariadb-dump --single-transaction -u $${DB_USER} $${DB_NAME} | sed 's/DEFINER[[:space:]]*=[[:space:]]*[^*]*\*/\*/g' > "$$FILENAME"; \
		fi; \
		echo "✅ Export complete! Saved to $$FILENAME"; \
	elif [ -n "$$ACTION" ]; then \
		echo "❌ ERROR: Invalid db action: $$ACTION. Use 'import <file>', 'export', or no arguments for console."; \
		exit 1; \
	else \
		echo "🔌 Connecting to database..."; \
		. ./docker/scripts/set-env-vars.sh && docker compose exec -e MYSQL_PWD=$${DB_PASS} db mariadb -u $${DB_USER} $${DB_NAME}; \
	fi

.PHONY: db-root
db-root: _ensure_env
	@echo "🔌 Connecting to database as root..."
	@. ./docker/scripts/set-env-vars.sh && docker compose exec -e MYSQL_PWD=$${DB_ROOT_PASS} db mariadb -u root $${DB_NAME}

.PHONY: ctop
ctop:
	@PROJECT_NAME=$$(grep '^PROJECT_NAME=' .env | cut -d= -f2 | head -1); \
	docker run --rm -ti \
		--platform linux/amd64 \
		--name=ctop \
		--volume /var/run/docker.sock:/var/run/docker.sock:ro \
		elswork/ctop:latest -f "$$PROJECT_NAME"

.PHONY: php-info
php-info: _ensure_env
	@echo "🔍 Active PHP Configuration (CLI context):"
	@. ./docker/scripts/set-env-vars.sh && docker compose exec app php -i | grep -E "^(date\.timezone|error_log|error_reporting|display_errors|log_errors|max_input_vars|memory_limit|max_execution_time|opcache\.(enable|validate_timestamps|revalidate_freq)) "

.PHONY: opcache-clear
opcache-clear: _ensure_env
	@echo "🧹 Clearing OPcache (PHP-FPM)..."
	@. ./docker/scripts/set-env-vars.sh && docker compose exec -T app sh -c 'echo "<?php opcache_reset(); echo \"OPcache cleared\n\";" > /var/www/html/public/opcache_reset_temp.php'
	@. ./docker/scripts/set-env-vars.sh && docker compose exec -T app curl -s http://localhost/opcache_reset_temp.php || echo "❌ Failed to query OPcache reset script"
	@. ./docker/scripts/set-env-vars.sh && docker compose exec -T app rm -f /var/www/html/public/opcache_reset_temp.php

.PHONY: doctor
doctor: _ensure_env
	@echo "🩺 Running diagnostic checks..."
	@echo "─────────────────────────────────"
	@docker info >/dev/null 2>&1 && echo "✅ Docker daemon is running" || echo "❌ Docker daemon is NOT running or accessible"
	@if [ -f /sys/kernel/mm/transparent_hugepage/enabled ]; then \
		THP_STATUS=$$(cat /sys/kernel/mm/transparent_hugepage/enabled | grep -o '\[.*\]' | tr -d '[]'); \
		echo "ℹ️  Host Transparent Huge Pages: $$THP_STATUS"; \
		if [ "$$THP_STATUS" = "never" ]; then \
			echo "   ⚠️  Note: OPcache Huge Code Pages won't work because THP is disabled on the host."; \
		fi; \
	else \
		echo "ℹ️  Host Transparent Huge Pages: Not supported by OS kernel"; \
	fi
	@PROJECT_ID=$$(grep '^PROJECT_ID=' .env | cut -d= -f2 | head -1); \
	DB_PORT="33$$PROJECT_ID"; \
	SFTP_PORT="22$$PROJECT_ID"; \
	if command -v ss >/dev/null 2>&1; then \
		if ss -tln | grep -q ":$$DB_PORT "; then echo "⚠️  Warning: Port $$DB_PORT is already in use on the host!"; else echo "✅ DB Port $$DB_PORT is available"; fi; \
		if ss -tln | grep -q ":$$SFTP_PORT "; then echo "⚠️  Warning: Port $$SFTP_PORT is already in use on the host!"; else echo "✅ SFTP Port $$SFTP_PORT is available"; fi; \
	elif command -v netstat >/dev/null 2>&1; then \
		if netstat -tln | grep -q ":$$DB_PORT "; then echo "⚠️  Warning: Port $$DB_PORT is already in use on the host!"; else echo "✅ DB Port $$DB_PORT is available"; fi; \
		if netstat -tln | grep -q ":$$SFTP_PORT "; then echo "⚠️  Warning: Port $$SFTP_PORT is already in use on the host!"; else echo "✅ SFTP Port $$SFTP_PORT is available"; fi; \
	fi
	@echo "─────────────────────────────────"

.PHONY: open-ports
open-ports: _ensure_env
	@echo "🌐 Opening DB and SFTP ports externally (0.0.0.0)..."
	$(call set_env,DB_BIND_IP,0.0.0.0)
	$(call set_env,SFTP_BIND_IP,0.0.0.0)
	@echo "⚠️  Ports configured to be open. Run 'make restart' or 'docker compose up -d' to apply."

.PHONY: close-ports
close-ports: _ensure_env
	@echo "🔒 Closing DB and SFTP ports (127.0.0.1)..."
	$(call set_env,DB_BIND_IP,127.0.0.1)
	$(call set_env,SFTP_BIND_IP,127.0.0.1)
	@echo "✅ Ports configured to be closed. Run 'make restart' or 'docker compose up -d' to apply."

.PHONY: open-db
open-db: _ensure_env
	@echo "🌐 Opening DB port externally (0.0.0.0)..."
	$(call set_env,DB_BIND_IP,0.0.0.0)
	@echo "⚠️  DB port configured to be open. Run 'make restart' or 'docker compose up -d' to apply."

.PHONY: close-db
close-db: _ensure_env
	@echo "🔒 Closing DB port (127.0.0.1)..."
	$(call set_env,DB_BIND_IP,127.0.0.1)
	@echo "✅ DB port configured to be closed. Run 'make restart' or 'docker compose up -d' to apply."

.PHONY: open-sftp
open-sftp: _ensure_env
	@echo "🌐 Opening SFTP port externally (0.0.0.0)..."
	$(call set_env,SFTP_BIND_IP,0.0.0.0)
	@echo "⚠️  SFTP port configured to be open. Run 'make restart' or 'docker compose up -d' to apply."

.PHONY: close-sftp
close-sftp: _ensure_env
	@echo "🔒 Closing SFTP port (127.0.0.1)..."
	$(call set_env,SFTP_BIND_IP,127.0.0.1)
	@echo "✅ SFTP port configured to be closed. Run 'make restart' or 'docker compose up -d' to apply."

.PHONY: redis-info
redis-info: _ensure_env
	@. ./docker/scripts/set-env-vars.sh && docker compose exec redis valkey-cli info

.PHONY: redis-monitor
redis-monitor: _ensure_env
	@echo "📡 Monitoring Redis commands... (Press Ctrl+C to stop)"
	@. ./docker/scripts/set-env-vars.sh && docker compose exec redis valkey-cli monitor

.PHONY: redis-ping
redis-ping: _ensure_env
	@. ./docker/scripts/set-env-vars.sh && docker compose exec redis valkey-cli ping

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
		$(MAKE) --no-print-directory init || exit 1; \
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
	$(call set_env,DB_CPUS,1.0)
	$(call set_env,DB_MEMORY,512M)
	$(call set_env,DB_MEMORY_RESERVATION,128M)
	$(call set_env,DB_INNODB_BUFFER_POOL_SIZE,128M)
	$(call set_env,DB_INNODB_BUFFER_POOL_INSTANCES,1)
	$(call set_env,DB_INNODB_LOG_FILE_SIZE,32M)
	$(call set_env,DB_MAX_CONNECTIONS,50)
	$(call set_env,DB_TABLE_OPEN_CACHE,2000)
	$(call set_env,DB_TABLE_DEFINITION_CACHE,1400)
	$(call set_env,PHP_MEMORY_LIMIT,128M)
	$(call set_env,PHP_OPCACHE_MEMORY_CONSUMPTION,128)
	$(call set_env,PHP_OPCACHE_HUGE_CODE_PAGES,0)
	$(call set_env,APP_TMPFS_SIZE,128M)
	$(call set_env,APACHE_MAX_REQUEST_WORKERS,10)
	$(call set_env,PHP_FPM_PM,dynamic)
	$(call set_env,PHP_FPM_PM_MAX_CHILDREN,10)
	$(call set_env,PHP_FPM_PM_START_SERVERS,3)
	$(call set_env,PHP_FPM_PM_MIN_SPARE_SERVERS,2)
	$(call set_env,PHP_FPM_PM_MAX_SPARE_SERVERS,5)
	$(call set_env,PHP_FPM_PM_MAX_REQUESTS,500)
	$(call set_env,PHP_FPM_SLOWLOG_TIMEOUT,10s)
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
	$(call set_env,DB_INNODB_BUFFER_POOL_INSTANCES,1)
	$(call set_env,DB_INNODB_LOG_FILE_SIZE,64M)
	$(call set_env,DB_MAX_CONNECTIONS,100)
	$(call set_env,DB_TABLE_OPEN_CACHE,2000)
	$(call set_env,DB_TABLE_DEFINITION_CACHE,1400)
	$(call set_env,PHP_MEMORY_LIMIT,256M)
	$(call set_env,PHP_OPCACHE_MEMORY_CONSUMPTION,256)
	$(call set_env,PHP_OPCACHE_HUGE_CODE_PAGES,0)
	$(call set_env,APP_TMPFS_SIZE,256M)
	$(call set_env,APACHE_MAX_REQUEST_WORKERS,25)
	$(call set_env,PHP_FPM_PM,dynamic)
	$(call set_env,PHP_FPM_PM_MAX_CHILDREN,25)
	$(call set_env,PHP_FPM_PM_START_SERVERS,8)
	$(call set_env,PHP_FPM_PM_MIN_SPARE_SERVERS,5)
	$(call set_env,PHP_FPM_PM_MAX_SPARE_SERVERS,15)
	$(call set_env,PHP_FPM_PM_MAX_REQUESTS,500)
	$(call set_env,PHP_FPM_SLOWLOG_TIMEOUT,10s)
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
	$(call set_env,DB_MEMORY,3G)
	$(call set_env,DB_MEMORY_RESERVATION,512M)
	$(call set_env,DB_INNODB_BUFFER_POOL_SIZE,1G)
	$(call set_env,DB_INNODB_BUFFER_POOL_INSTANCES,2)
	$(call set_env,DB_INNODB_LOG_FILE_SIZE,256M)
	$(call set_env,DB_MAX_CONNECTIONS,300)
	$(call set_env,DB_TABLE_OPEN_CACHE,4000)
	$(call set_env,DB_TABLE_DEFINITION_CACHE,2000)
	$(call set_env,PHP_MEMORY_LIMIT,512M)
	$(call set_env,PHP_OPCACHE_MEMORY_CONSUMPTION,512)
	$(call set_env,PHP_OPCACHE_HUGE_CODE_PAGES,1)
	$(call set_env,APP_TMPFS_SIZE,512M)
	$(call set_env,APACHE_MAX_REQUEST_WORKERS,50)
	$(call set_env,PHP_FPM_PM,dynamic)
	$(call set_env,PHP_FPM_PM_MAX_CHILDREN,50)
	$(call set_env,PHP_FPM_PM_START_SERVERS,15)
	$(call set_env,PHP_FPM_PM_MIN_SPARE_SERVERS,10)
	$(call set_env,PHP_FPM_PM_MAX_SPARE_SERVERS,30)
	$(call set_env,PHP_FPM_PM_MAX_REQUESTS,500)
	$(call set_env,PHP_FPM_SLOWLOG_TIMEOUT,5s)
	@echo "✅ LARGE profile applied. Run 'make restart' to apply changes."

.PHONY: size-show
size-show: _ensure_env
	@APP_MEM=$$(grep '^APP_MEMORY=' .env | cut -d= -f2); \
	DB_MEM=$$(grep '^DB_MEMORY=' .env | cut -d= -f2); \
	FPM_CHILDREN=$$(grep '^PHP_FPM_PM_MAX_CHILDREN=' .env | cut -d= -f2); \
	PROFILE="⚠️  CUSTOM (modified)"; \
	if [ "$$APP_MEM" = "256M" ] && [ "$$DB_MEM" = "512M" ] && [ "$$FPM_CHILDREN" = "10" ]; then \
		PROFILE="🟢 SMALL (Low traffic)"; \
	elif [ "$$APP_MEM" = "512M" ] && [ "$$DB_MEM" = "1G" ] && [ "$$FPM_CHILDREN" = "25" ]; then \
		PROFILE="🟡 MEDIUM (Medium traffic)"; \
	elif [ "$$APP_MEM" = "1G" ] && [ "$$DB_MEM" = "3G" ] && [ "$$FPM_CHILDREN" = "50" ]; then \
		PROFILE="🔴 LARGE (High traffic)"; \
	fi; \
	echo "📊 Current sizing configuration (Profile: $$PROFILE):"; \
	echo "─────────────────────────────────"
	@echo "  App:   CPU=$$(grep '^APP_CPUS=' .env | cut -d= -f2)  MEM=$$(grep '^APP_MEMORY=' .env | cut -d= -f2)  Tmpfs=$$(grep '^APP_TMPFS_SIZE=' .env | cut -d= -f2)"
	@echo "  Cron:  CPU=$$(grep '^CRON_CPUS=' .env | cut -d= -f2)  MEM=$$(grep '^CRON_MEMORY=' .env | cut -d= -f2)"
	@echo "  DB:    CPU=$$(grep '^DB_CPUS=' .env | cut -d= -f2)  MEM=$$(grep '^DB_MEMORY=' .env | cut -d= -f2)  BufferPool=$$(grep '^DB_INNODB_BUFFER_POOL_SIZE=' .env | cut -d= -f2)  LogFile=$$(grep '^DB_INNODB_LOG_FILE_SIZE=' .env | cut -d= -f2)  MaxConn=$$(grep '^DB_MAX_CONNECTIONS=' .env | cut -d= -f2)"
	@echo "  DB:    TableOpenCache=$$(grep '^DB_TABLE_OPEN_CACHE=' .env | cut -d= -f2)  TableDefCache=$$(grep '^DB_TABLE_DEFINITION_CACHE=' .env | cut -d= -f2)  BPInstances=$$(grep '^DB_INNODB_BUFFER_POOL_INSTANCES=' .env | cut -d= -f2)"
	@echo "  PHP:   MemLimit=$$(grep '^PHP_MEMORY_LIMIT=' .env | cut -d= -f2)  OPcache=$$(grep '^PHP_OPCACHE_MEMORY_CONSUMPTION=' .env | cut -d= -f2)MB  HugePages=$$(grep '^PHP_OPCACHE_HUGE_CODE_PAGES=' .env | cut -d= -f2)"
	@echo "  FPM:   PM=$$(grep '^PHP_FPM_PM=' .env | cut -d= -f2)  MaxChildren=$$(grep '^PHP_FPM_PM_MAX_CHILDREN=' .env | cut -d= -f2)  Start=$$(grep '^PHP_FPM_PM_START_SERVERS=' .env | cut -d= -f2)  MinSpare=$$(grep '^PHP_FPM_PM_MIN_SPARE_SERVERS=' .env | cut -d= -f2)  MaxSpare=$$(grep '^PHP_FPM_PM_MAX_SPARE_SERVERS=' .env | cut -d= -f2)"
	@echo "─────────────────────────────────"

.PHONY: crontab-init
crontab-init:
	@if [ ! -f docker/scripts/crontab ]; then \
		mkdir -p docker/scripts; \
		echo "# m h dom mon dow user  command" > docker/scripts/crontab; \
		echo "# * * * * * www-data php /var/www/html/scripts/cron.php" >> docker/scripts/crontab; \
		echo "✅ Created example crontab at docker/scripts/crontab"; \
	else \
		echo "ℹ️  crontab file already exists."; \
	fi

# Catch-all target for positional arguments
%:
	@: