#!/bin/sh
# init-tmp-dirs.sh
# Script to create the temporary directory structure for ZF1 on startup.
# Intended to be run under the container entrypoint system (e.g., /etc/entrypoint.d/)

echo "📁 Initializing /var/www/html/tmp structure..."

mkdir -p /var/www/html/tmp/cache \
         /var/www/html/tmp/cache_class \
         /var/www/html/tmp/cache_core \
         /var/www/html/tmp/cache_core_300 \
         /var/www/html/tmp/cache_core_60 \
         /var/www/html/tmp/cache_forms \
         /var/www/html/tmp/cache_pages \
         /var/www/html/tmp/sessions

# Ensure ownership is correct (www-data should already have the correct PUID/PGID if mapped)
chown -R www-data:www-data /var/www/html/tmp
chmod -R 775 /var/www/html/tmp

echo "✅ Tmp structure initialized."
