# Capacity and Sizing Guide

Proper sizing is crucial for running stable Zend Framework 1.x legacy applications, especially when hosting multiple tenants on the same server. This guide covers how to size your deployments safely.

## Automated Sizing Profiles
The provided `Makefile` includes predefined sizing profiles that automatically adjust `.env` variables to apply balanced CPU, Memory, caching, and database limits based on the expected application size.

To apply a profile, run:
```bash
make size-xs   # For micro app/local dev (< 100 visits/day)
make size-s    # For low traffic (< 1000 visits/day)
make size-m    # For medium traffic (1000 - 5000 visits/day)
make size-l    # For high traffic (5000 - 15000 visits/day)
make size-xl   # For very high traffic (15000 - 50000 visits/day)
make size-xxl  # For critical/high-load app (> 50000 visits/day)
```

Always run `make start` or `make restart` to apply environment variable changes to running containers.
You can view active sizing values easily using `make size-show`.

### Sizing Profiles Reference

The table below shows all variables configured by each profile:

| Variable / Parameter | Description | XS | S | M | L | XL | XXL |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| **App Service (`app`)** | | | | | | | |
| `APP_CPUS` | CPU limit for the web container | `0.25` | `0.5` | `1.0` | `2.0` | `4.0` | `8.0` |
| `APP_MEMORY` | Memory limit for the web container | `128M` | `256M` | `512M` | `1G` | `2G` | `4G` |
| `APP_MEMORY_RESERVATION` | Reserved memory for the web container | `32M` | `64M` | `128M` | `256M` | `512M` | `1G` |
| `APP_TMPFS_SIZE` | Size of high-performance `tmpfs` volume | `64M` | `128M` | `256M` | `512M` | `1G` | `2G` |
| `PHP_MEMORY_LIMIT` | Memory limit per PHP script execution | `64M` | `128M` | `256M` | `512M` | `768M` | `1G` |
| `PHP_OPCACHE_MEMORY_CONSUMPTION`| OPcache buffer memory size | `64MB` | `128MB` | `256MB` | `512MB` | `512MB` | `1GB` |
| `PHP_OPCACHE_HUGE_CODE_PAGES` | OPcache Huge Code Pages (1=on, 0=off) | `0` | `0` | `0` | `0` | `1` | `1` |
| **Apache & PHP-FPM** | | | | | | | |
| `APACHE_MAX_REQUEST_WORKERS` | Max concurrent Apache threads | `5` | `10` | `25` | `40` | `75` | `150` |
| `PHP_FPM_PM_MAX_CHILDREN` | Max PHP-FPM worker processes | `5` | `10` | `25` | `40` | `75` | `150` |
| `PHP_FPM_PM_START_SERVERS` | Initial worker processes spawned | `2` | `3` | `8` | `12` | `20` | `40` |
| `PHP_FPM_PM_MIN_SPARE_SERVERS`| Min idle worker processes | `1` | `2` | `5` | `8` | `15` | `30` |
| `PHP_FPM_PM_MAX_SPARE_SERVERS`| Max idle worker processes | `3` | `5` | `15` | `24` | `45` | `90` |
| `PHP_FPM_PM_MAX_REQUESTS` | Workers recycled after N requests | `500` | `500` | `500` | `500` | `500` | `500` |
| `PHP_FPM_SLOWLOG_TIMEOUT` | Slow request log threshold | `10s` | `10s` | `10s` | `10s` | `5s` | `5s` |
| **Database Service (`db`)** | | | | | | | |
| `DB_CPUS` | CPU limit for the MariaDB container | `0.5` | `1.0` | `2.0` | `3.0` | `6.0` | `12.0` |
| `DB_MEMORY` | Memory limit for the MariaDB container | `256M` | `512M` | `1.5G` | `3G` | `6G` | `12G` |
| `DB_MEMORY_RESERVATION` | Reserved memory for the DB container | `64M` | `128M` | `256M` | `512M` | `1G` | `2G` |
| `DB_MAX_CONNECTIONS` | Max database client connections | `20` | `50` | `100` | `150` | `300` | `500` |
| `DB_INNODB_BUFFER_POOL_SIZE` | Size of InnoDB buffer pool | `64M` | `128M` | `512M` | `1.5G` | `3G` | `8G` |
| `DB_INNODB_BUFFER_POOL_INSTANCES`| Number of InnoDB buffer pool chunks | `1` | `1` | `1` | `1` | `2` | `4` |
| `DB_INNODB_LOG_FILE_SIZE` | Size of transaction log files | `16M` | `32M` | `128M` | `256M` | `512M` | `1G` |
| **Cron Service (`cron`)** | | | | | | | |
| `CRON_CPUS` | CPU limit for the CLI/cron container | `0.05` | `0.1` | `0.25` | `0.5` | `1.0` | `2.0` |
| `CRON_MEMORY` | Memory limit for the CLI/cron container | `64M` | `128M` | `256M` | `512M` | `1G` | `2G` |
| `CRON_MEMORY_RESERVATION` | Reserved memory for the cron container | `16M` | `32M` | `64M` | `128M` | `256M` | `512M` |

## Critical Warning: SWAP Usage and tmpfs

> [!CAUTION]
> **Active SWAP memory on the host completely destroys Zend Framework performance when using `tmpfs`.**

This stack intentionally mounts the temporary `/var/www/html/tmp` directory into a fast, in-memory `tmpfs` volume instead of the persistent disk. This is because ZF1 heavily depends on the `/tmp` directory for session storage and various framework caches (core, classes, pages, forms).

Using `tmpfs` is dramatically faster than SSD I/O. However, if your host server runs out of physical RAM and begins using SWAP files:
1. Docker will seamlessly begin swapping the `tmpfs` volume back to the slow, physical disk.
2. Because the OS kernel manages SWAP, it abstracts the disk latency from Docker. 
3. The "in-memory" cache operations effectively become heavily delayed disk operations, causing catastrophic performance collapses and 500/504 Gateway errors.

**Recommendation:**
- Strictly control memory using `size-xs` or `size-s` on hosts with low RAM.
- Use monitoring tools (like Netdata, Datadog or Prometheus) to specifically alert if the host begins allocating SWAP.
- Ensure the sum of all `*_MEMORY` limits across all tenants combined never exceeds 90% of the host's physical RAM, leaving 10% for OS overhead.

## Database Connection Capacity Planning

> [!IMPORTANT]
> **Rule of thumb: `DB_MAX_CONNECTIONS` should be ≥ `PHP_FPM_PM_MAX_CHILDREN × 3`.**

Some legacy ZF1 applications open **multiple database connections per request** (e.g., separate connections per module, read/write splitting, or one per `Zend_Db_Table` adapter). With the cron container also connecting, the formula is:

```
Required connections ≥ (FPM max_children × connections_per_request) + cron_connections + monitoring
```

The `make validate` target will warn you if your configuration is at risk. If you see the warning, increase `DB_MAX_CONNECTIONS` in your `.env`.

## Database Schema Considerations (Large Apps)

For applications with **thousands of tables** (common in large legacy ZF1 backoffices with per-client table schemas):

- **`DB_TABLE_OPEN_CACHE`**: Each concurrent query needs open table descriptors. With thousands of tables and hundreds of connections, the default (2000) may not be enough. The L/XL/XXL profiles set this to `4000`/`6000`/`10000`.
- **`DB_TABLE_DEFINITION_CACHE`**: Caches `.frm` file metadata. The default (400) is far too low for large schemas — every cache miss triggers a disk read. The L/XL/XXL profiles set this to `2000`/`3000`/`5000`.
- **`DB_INNODB_BUFFER_POOL_SIZE`**: For databases with thousands of tables, just the InnoDB data dictionary and adaptive hash index can consume hundreds of MB. The L/XL/XXL profiles allocate larger buffer pools (up to 8G) to keep the working set in memory.

## SQL Mode Compatibility Note

> [!WARNING]
> **`STRICT_TRANS_TABLES` is intentionally disabled** in the MariaDB configuration for legacy ZF1 compatibility.

This means MariaDB will silently truncate too-long strings, convert invalid types, and insert default values for NOT NULL columns. This behavior matches what older MySQL 5.x versions did, which is what most ZF1 applications were written against.

If you are migrating a **new** application (not legacy), consider re-enabling strict mode by adding to `docker-compose.override.yml`:
```yaml
services:
  db:
    command:
      - --sql_mode=STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION
```

