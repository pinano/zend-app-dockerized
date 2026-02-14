# Dockerized Legacy ZF1 Application

A modernized Docker stack for running legacy Zend Framework 1.x applications, featuring optimized performance, secure defaults, and easy management via `make`.

## Features
- **Configurable PHP Version**: Switch between PHP versions (e.g., 5.6, 7.4, 8.1) via `.env`.
- **MariaDB 12**: Latest stable database version.
- **Performance Tuned**: Optimized `opcache` and `realpath_cache` settings for ZF1.
- **Tmpfs Integration**: High-performance, ephemeral storage for ZF1 cache/sessions.
- **Secure by Default**: SFTP and DB ports restricted to localhost.
- **Traefik Ready**: Integrated labels for Traefik reverse proxy.
- **Unified Management**: Simple `Makefile` for all common operations.

## Quickstart

1.  **Start the Stack**
    ```bash
    make up
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
- `PHP_VERSION`: The PHP version tag for `serversideup/php` (e.g., `7.4`).
- `APACHE_DOCUMENT_ROOT`: Path to the public web root (default: `/var/www/html/public`).
- `DB_*`: Database credentials and settings.
- `SFTP_*`: SFTP user credentials.

### Performance Tuning
PHP performance settings (OPcache, Realpath) are configured via environment variables in `docker-compose.yml`.

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
| `make up` | Start the stack (and create .env) |
| `make down` | Stop the stack and cleanup orphans |
| `make restart` | Restart all containers |
| `make logs` | View container logs |
| `make shell` | Access the app container shell |
| `make db` | Access the database console |
| `make config` | Validate Docker Compose config |

## Services

- **app**: PHP-FPM + Apache (serversideup/php image).
- **db**: MariaDB 12.1.2.
- **sftp**: Secure file transfer (atmoz/sftp), restricted to localhost.
