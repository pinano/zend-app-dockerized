# Image for running the main app
# Declare default PHP version before FROM
ARG PHP_VERSION=8.5

# Choose our base image
FROM serversideup/php:${PHP_VERSION}-fpm-apache

# Arguments coming from docker-compose to handle permissions dynamically
ARG USER_ID=1000
ARG GROUP_ID=1000

# Switch to root to perform system-level configuration
USER root

# --- DEBIAN ARCHIVE FIX ---
# Debian 11 (Bullseye) reached end of LTS and moved to archive.debian.org.
# In archive.debian.org, Bullseye packages are consolidated into a single repository.
# Align libexpat1 with the archive version to satisfy build dependencies of imagick and gd.
RUN if grep -q "bullseye" /etc/os-release 2>/dev/null; then \
        echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99no-check-valid-until && \
        echo 'deb http://archive.debian.org/debian bullseye main contrib non-free' > /etc/apt/sources.list && \
        rm -f /etc/apt/sources.list.d/*.list && \
        apt-get update && \
        apt-get install -y --allow-downgrades libexpat1=2.2.10-2+deb11u5 && \
        rm -rf /var/lib/apt/lists/*; \
    elif grep -q "buster" /etc/os-release 2>/dev/null; then \
        echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99no-check-valid-until && \
        echo 'deb http://archive.debian.org/debian buster main contrib non-free' > /etc/apt/sources.list && \
        echo 'deb http://archive.debian.org/debian-security buster/updates main contrib non-free' >> /etc/apt/sources.list && \
        rm -f /etc/apt/sources.list.d/*.list; \
    fi
# --------------------------

# --- USER SYNC ---
# 1. Update www-data UID and GID to match the host user (e.g., 1002)
# 2. Use find to reassign ownership of existing files from the old ID (33) to the new one
RUN usermod -o -u ${USER_ID} www-data && \
    groupmod -o -g ${GROUP_ID} www-data && \
    [ -d "/var/www" ] && find /var/www -user 33 -exec chown -h www-data {} \; || true
# -----------------

# --- APP INITIALIZATION ---
# Copy the initialization script to run on startup
# Creates tmpfs directory structure and auto-generates healthcheck.php
COPY docker/scripts/init-app.sh /etc/entrypoint.d/99-init-app.sh
RUN chmod +x /etc/entrypoint.d/99-init-app.sh
# -----------------

# --- COMPOSER & TOOLS ---
# Install system packages required by Composer (git, unzip, zip) and copy Composer binary
RUN apt-get update && \
    apt-get install -y --no-install-recommends git unzip zip && \
    rm -rf /var/lib/apt/lists/*
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
ENV COMPOSER_HOME=/var/www/html/tmp/composer \
    COMPOSER_CACHE_DIR=/var/www/html/tmp/composer/cache
# ------------------------

# Install required PHP extensions with root permissions
RUN install-php-extensions exif imagick gd intl xdebug redis

# IMPORTANT: We do NOT use "USER www-data" here.
# Leaving the user as root allows the entrypoint script to configure Apache modules
# and symlinks. The image will automatically drop privileges to www-data for PHP-FPM.
