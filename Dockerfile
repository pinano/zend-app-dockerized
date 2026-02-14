# Delcare PHP version before FROM
ARG PHP_VERSION=7.4

# Choose our base image
FROM serversideup/php:${PHP_VERSION}-fpm-apache

# Arguments coming from docker-compose to handle permissions dynamically
ARG USER_ID
ARG GROUP_ID

# Switch to root to perform system-level configuration
USER root

# --- USER SYNC ---
# 1. Update www-data UID and GID to match the host user (e.g., 1002)
# 2. Use find to reassign ownership of existing files from the old ID (33) to the new one
RUN usermod -u ${USER_ID} www-data && \
    groupmod -g ${GROUP_ID} www-data && \
    find /var/www -user 33 -exec chown -h www-data {} \; || true
# -----------------

# --- ZEND TMP STRUCTURE ---
# Creamos la estructura de directorios necesaria para Zend Framework 1
# Usamos el usuario www-data que acabamos de sincronizar
RUN mkdir -p /var/www/html/tmp/cache \
             /var/www/html/tmp/cache_class \
             /var/www/html/tmp/cache_core \
             /var/www/html/tmp/cache_core_300 \
             /var/www/html/tmp/cache_core_60 \
             /var/www/html/tmp/cache_forms \
             /var/www/html/tmp/cache_pages \
             /var/www/html/tmp/sessions && \
    chown -R www-data:www-data /var/www/html/tmp && \
    chmod -R 775 /var/www/html/tmp
# -----------------

# Install required PHP extensions with root permissions
RUN install-php-extensions exif imagick gd intl

# IMPORTANT: We do NOT use "USER www-data" here.
# Leaving the user as root allows the entrypoint script to configure Apache modules
# and symlinks. The image will automatically drop privileges to www-data for PHP-FPM.
