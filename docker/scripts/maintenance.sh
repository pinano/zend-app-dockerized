#!/bin/bash
# maintenance.sh - Periodic cleanup for tmpfs shared volume
# This script is intended to run inside the cron container.
# Runs every 15 minutes via the crontab.

TMP_DIR="/var/www/html/tmp"

echo "--- [$(date)] Starting Maintenance Task ---"

# 1. Truncate logs if they are too big (> 5MB)
# Using :> to truncate preserves the file descriptor for the tail process.
# Threshold lowered to 5MB to prevent runaway logs from filling the tmpfs volume,
# which would cause all cache and session writes to fail (complete outage).
LOG_FILES=("$TMP_DIR"/*.log "/var/www/html/application/logs/error.log")
for log in "${LOG_FILES[@]}"; do
    if [ -f "$log" ] && [ $(stat -c%s "$log") -gt 5242880 ]; then
        echo "Truncating large log file: $log"
        : > "$log"
    fi
done
echo "✅ Checked and truncated large log files."

# 2. Clean up old sessions (older than 24h)
if [ -d "$TMP_DIR/sessions" ]; then
    # -mmin +1440 = 24 hours
    find "$TMP_DIR/sessions" -type f -mmin +1440 -delete
    echo "✅ Cleaned up sessions older than 24h."
fi

# 3. Clean up old cache files (older than 7 days)
# We use -mindepth 1 to avoid deleting the base cache directories themselves
CACHE_DIRS=("cache" "cache_class" "cache_core" "cache_core_300" "cache_core_60" "cache_forms" "cache_pages")
for cdir in "${CACHE_DIRS[@]}"; do
    if [ -d "$TMP_DIR/$cdir" ]; then
        find "$TMP_DIR/$cdir" -mindepth 1 -type f -mtime +7 -delete
        echo "✅ Cleaned up stale files in $cdir (older than 7 days)."
    fi
done

echo "--- [$(date)] Maintenance Task Complete ---"
