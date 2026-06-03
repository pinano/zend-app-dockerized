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

# --- LOG FILES INITIALIZATION ---
# Pre-creates log files with correct permissions for separate tailing.

# 1. PHP Error Log (Generic PHP errors)
PHP_ERROR_LOG=/var/www/html/tmp/php_errors.log
touch "$PHP_ERROR_LOG"
chown www-data:www-data "$PHP_ERROR_LOG"
chmod 664 "$PHP_ERROR_LOG"

# 2. PHP-FPM Slow Log (Performance debugging)
FPM_SLOW_LOG=/var/www/html/tmp/php-fpm-slow.log
touch "$FPM_SLOW_LOG"
chown www-data:www-data "$FPM_SLOW_LOG"
chmod 664 "$FPM_SLOW_LOG"

# 3. Zend Application Log (Framework-specific errors)
ZEND_ERROR_LOG=/var/www/html/application/logs/error.log
mkdir -p "$(dirname "$ZEND_ERROR_LOG")"
touch "$ZEND_ERROR_LOG"
chown www-data:www-data "$ZEND_ERROR_LOG"
chmod 664 "$ZEND_ERROR_LOG"

echo "✅ Log files initialized for separate tailing."


echo "✅ Tmp structure initialized."

# --- HEALTHCHECK ---
# Auto-generate a healthcheck.php that validates both PHP-FPM and database connectivity.
# This allows Docker healthchecks and Traefik to detect actual service availability,
# not just that PHP-FPM is responding.
HEALTHCHECK_FILE="${APACHE_DOCUMENT_ROOT:-/var/www/html/public}/healthcheck.php"
mkdir -p "$(dirname "$HEALTHCHECK_FILE")"
if [ ! -f "$HEALTHCHECK_FILE" ]; then
    cat > "$HEALTHCHECK_FILE" <<'HEALTHCHECK_EOF'
<?php
// Auto-generated healthcheck — validates PHP-FPM + MariaDB connectivity.
// Docker healthcheck interval is typically 60s, so one DB connection per minute is negligible.
try {
    $pdo = new PDO(
        'mysql:host=' . getenv('DB_HOST') . ';dbname=' . getenv('DB_NAME'),
        getenv('DB_USER'),
        getenv('DB_PASS'),
        [PDO::ATTR_TIMEOUT => 3, PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
    );
    $pdo->query('SELECT 1');
    $pdo = null;
    http_response_code(200);
    echo 'ok';
} catch (Exception $e) {
    http_response_code(503);
    echo 'db_error';
}
HEALTHCHECK_EOF
    chown www-data:www-data "$HEALTHCHECK_FILE"
    echo "✅ Healthcheck created at $HEALTHCHECK_FILE (with DB validation)"
else
    echo "ℹ️  Healthcheck already exists at $HEALTHCHECK_FILE, skipping."
fi

# --- DYNAMIC PHP ERROR REPORTING ---
# Convert string values (like "E_ALL & ~E_NOTICE") to an integer for FPM pool.
# FPM cannot parse PHP language constants natively via env vars.
if [ -n "$PHP_ERROR_REPORTING" ]; then
    echo "⚙️  Evaluating PHP_ERROR_REPORTING to integer for FPM pool..."
    INT_VAL=$(php -r '
        $expr = trim(getenv("PHP_ERROR_REPORTING"));
        $expr = trim($expr, "\"\x27");
        $expr = trim($expr);
        if (empty($expr)) {
            echo E_ALL & ~E_WARNING & ~E_NOTICE & ~E_DEPRECATED;
            exit;
        }
        if (preg_match("/^[a-zA-Z0-9_\s&~|()]+$/", $expr)) {
            $val = eval("return $expr;");
            if ($val !== false) {
                echo $val;
                exit;
            }
        }
        echo E_ALL & ~E_NOTICE & ~E_DEPRECATED;
    ' 2>/dev/null)

    # Robust fallback: check if INT_VAL is a valid number to prevent PHP-FPM boot crashes.
    if ! [[ "$INT_VAL" =~ ^[0-9]+$ ]]; then
        echo "⚠️  Failed to evaluate PHP_ERROR_REPORTING expression. Using default error reporting."
        INT_VAL=$(php -r 'echo E_ALL & ~E_NOTICE & ~E_DEPRECATED;')
    fi

    cat > /usr/local/etc/php-fpm.d/99-dynamic-error-reporting.conf <<EOF
[www]
php_admin_value[error_reporting] = $INT_VAL
EOF
    echo "✅ PHP error reporting configured dynamically ($INT_VAL)."
fi
