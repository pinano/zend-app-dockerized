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
