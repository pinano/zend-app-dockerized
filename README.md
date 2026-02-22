# Dockerized Legacy ZF1 Application

A modernized Docker stack for running legacy Zend Framework 1.x applications, featuring optimized performance, secure defaults, and easy management via `make`.

## Features
- **Configurable PHP Version**: Switch between PHP versions (e.g., 5.6, 7.4, 8.1) via `.env`.
- **MariaDB 12**: Latest stable database version.
- **Performance Tuned**: Optimized `opcache` and `realpath_cache` settings for ZF1.
- **Tmpfs Integration**: High-performance, ephemeral storage for ZF1 cache/sessions.
- **Secure by Default**: SFTP and DB ports restricted to localhost.
- **Traefik Ready**: Integrated labels for Traefik reverse proxy.
- **Advanced Flexibility**: Built-in support for Redis, Xdebug, Cronjobs, and custom PHP overrides.
- **Unified Management**: Simple `Makefile` for all common operations.

## Quickstart

1.  **Start the Stack**
    ```bash
    make start
    ```
    This will automatically copy `.env.dist` to `.env` if it doesn't exist and start the containers.

2.  **Access the Application**
    The application is configured behind Traefik. Access it via your configured Traefik domain (e.g., `http://app-project.localhost`).

3.  **Database Access**
    Connect specifically to the MariaDB console:
    ```bash
    make db
    ```

## Configuration

Configuration is managed via the `.env` file. Key variables include:

- `PROJECT_NAME`: Used for container naming and network isolation.
- `APP_ENV`: Application environment (`production` or `development`). **[Read the APP_ENV Guide here](docs/app_env.md).**
- `PHP_VERSION`: The PHP version tag for `serversideup/php` (e.g., `7.4`).
- `APACHE_DOCUMENT_ROOT`: Path to the public web root (default: `/var/www/html/public`).
- `DB_*`: Database credentials and settings.
- `SFTP_*`: SFTP user credentials.

### Scalability and Performance Tuning

The stack is designed to scale from small low-traffic sites to large applications. You can adjust the allocated resources and caching parameters in your `.env` file:

- **App Resources**: Limit CPU (`APP_CPUS`) and memory (`APP_MEMORY`) for the PHP container.
- **PHP Performance**: Configure OPcache (`PHP_OPCACHE_MEMORY_CONSUMPTION`, `PHP_OPCACHE_MAX_ACCELERATED_FILES`) and realpath cache (`PHP_REALPATH_CACHE_SIZE`) for faster execution.
- **Database Resources**: Assign CPU and memory limits to MariaDB (`DB_CPUS`, `DB_MEMORY`).
- **Database Tuning**: For high traffic, increase `DB_MAX_CONNECTIONS` and `DB_INNODB_BUFFER_POOL_SIZE` (crucial for InnoDB performance).

For detailed sizing profiles (Small/Medium/Large) and capacity planning, see the **[Sizing Guide](docs/sizing.md)**.

### Advanced Stack Control

You can enable additional stack features for specific legacy applications via `.env` or configuration files:

- **Optional Redis Cache**: Add `COMPOSE_PROFILES=redis` to your `.env` to automatically start a lightweight Redis container. **[Read the Full Redis Integration Guide here](docs/redis.md).**
- **Xdebug for Local Dev**: Set `PHP_EXTENSION_XDEBUG=1` in your `.env`. Keep it disabled in production.
- **Cronjobs**: Schedule application tasks without connecting to the container by adding cron syntax to `.docker/scripts/crontab`. A dedicated CLI container executes them automatically. **[Read the Cronjobs Guide here](docs/cron.md).**
- **Local PHP Overrides**: If a specific project needs an unusual PHP setting (e.g., `max_input_vars = 5000`), simply add it to `.docker/php/custom.ini` without modifying the core image.
- **Verbose Logging**: Adjust `APACHE_LOG_LEVEL=debug` (or `warn` by default) in your `.env` to troubleshoot complex HTTP errors.

## Project Structure

```
.
├── .docker/            # Docker configuration files (Apache, PHP, Scripts)
├── docroot/            # Application source code
├── mariadb_data/       # Persistent database storage
├── .env                # Environment variables
├── docker-compose.yml  # Container orchestration config
└── Makefile            # Command task runner
```

## Management Commands

| Command | Description |
|---------|-------------|
| `make start` | Start the stack (and create .env) |
| `make stop` | Stop the stack and cleanup orphans |
| `make restart` | Restart all containers |
| `make logs` | View container logs |
| `make shell` | Access the app container shell |
| `make db` | Access the database console |
| `make config` | Validate Docker Compose config |

## Services

- **app**: PHP-FPM + Apache (serversideup/php image).
- **cron**: CLI container to run scheduled tasks.
- **db**: MariaDB 12.1.2.
- **sftp**: Secure file transfer (atmoz/sftp), restricted to localhost.
- **redis** (Optional): In-memory cache store.
