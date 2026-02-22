#!/bin/sh
# init-app.sh
# Initialization script for the Zend Framework 1.x Docker container.
# Runs automatically via the entrypoint system (/etc/entrypoint.d/)

# --- TMP DIRECTORY STRUCTURE ---
# Required because /var/www/html/tmp is mounted as tmpfs (wiped on restart)
echo "📁 Initializing /var/www/html/tmp structure..."

mkdir -p /var/www/html/tmp/cache \
         /var/www/html/tmp/cache_class \
         /var/www/html/tmp/cache_core \
         /var/www/html/tmp/cache_core_300 \
         /var/www/html/tmp/cache_core_60 \
         /var/www/html/tmp/cache_forms \
         /var/www/html/tmp/cache_pages \
         /var/www/html/tmp/sessions

chown -R www-data:www-data /var/www/html/tmp
chmod -R 775 /var/www/html/tmp
echo "✅ Tmp structure initialized."

# --- HEALTHCHECK ---
# Auto-generate a minimal healthcheck.php if it doesn't already exist.
# This allows Docker healthchecks to verify PHP-FPM is responding without
# depending on the application's routing or framework.
HEALTHCHECK_FILE="${APACHE_DOCUMENT_ROOT:-/var/www/html/public}/healthcheck.php"
if [ ! -f "$HEALTHCHECK_FILE" ]; then
    echo '<?php http_response_code(200); echo "ok";' > "$HEALTHCHECK_FILE"
    chown www-data:www-data "$HEALTHCHECK_FILE"
    echo "✅ Healthcheck created at $HEALTHCHECK_FILE"
else
    echo "ℹ️  Healthcheck already exists at $HEALTHCHECK_FILE, skipping."
fi

# --- CRON ENVIRONMENT INJECTION ---
# The vanilla 'cron' daemon strips out all Docker-injected environment variables.
# We must manually dump them into /etc/environment so scheduled PHP scripts
# can connect to MariaDB and respect the APP_ENV.
if [ "$IS_CRON" = "1" ]; then
    echo "⚙️  Cron environment detected: Saving variables for scheduled tasks..."
    # Export critical variables explicitly to guarantee connectivity
    {
        echo "export DB_HOST=${DB_HOST}"
        echo "export DB_NAME=${DB_NAME}"
        echo "export DB_USER=${DB_USER}"
        echo "export DB_PASS=${DB_PASS}"
        echo "export APP_ENV=${APP_ENV}"
        printenv | grep -v "no_proxy" | grep -v "HOSTNAME" | grep -v "PWD"
    } > /etc/environment
    echo "✅ /etc/environment populated with Docker variables."
fi
