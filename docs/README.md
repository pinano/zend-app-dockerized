# 📚 Project Documentation: Reference Guides

This directory contains all technical documentation regarding the architecture, optimizations, and additional services of this Docker stack for legacy Zend Framework 1.x applications.

Below is an index organized by theme to facilitate navigation:

---

## 1. Setup & Migration

Key guides to prepare and deploy your application inside the container environment:

* **[Quickstart Guide](file:///home/pinano/Documents/webroot/pinano-zend-app-dockerized/docs/quickstart.md)**: Step-by-step setup instructions to boot the Docker stack on macOS, Linux (Ubuntu/Debian), and Windows (WSL2).
* **[Dockerization Guide](file:///home/pinano/Documents/webroot/pinano-zend-app-dockerized/docs/dockerizing-legacy-app.md)**: Step-by-step manual to migrate a legacy Zend application to the `docroot/` directory structure, configure the `index.php` entrypoint, and scan/inject shared libraries (`weblibs`). It also explains why `.htaccess` files are not required.
* **[Application Environments (APP_ENV)](file:///home/pinano/Documents/webroot/pinano-zend-app-dockerized/docs/app_env.md)**: Explanation of how the `APP_ENV` variable (`production` or `development`) interacts with the web server (PHP-FPM/Apache) and how to securely synchronize it with the framework constant.

---

## 2. Stack Services & Integrations

Details about the support services optionally included in the orchestration:

* **[Redis / Valkey Integration](file:///home/pinano/Documents/webroot/pinano-zend-app-dockerized/docs/redis.md)**: How to enable the in-memory Redis container and configure your Zend application to accelerate user sessions and store general caches.
* **[Scheduled Tasks (Cronjobs)](file:///home/pinano/Documents/webroot/pinano-zend-app-dockerized/docs/cron.md)**: Configuration and automatic execution of CLI scripts via a dedicated container, preventing background scheduled tasks from overlapping with the public-facing web server.
* **[Storage Architecture](file:///home/pinano/Documents/webroot/pinano-zend-app-dockerized/docs/storage.md)**: Information regarding disk persistence, the use of the ultra-fast `/tmp` folder mounted in RAM (`tmpfs`), and its impact on Input/Output operations.

---

## 3. Operations, Performance & Monitoring

Advanced techniques for stack maintenance, server capacity planning, and telemetry collection:

* **[Capacity and Sizing Guide](file:///home/pinano/Documents/webroot/pinano-zend-app-dockerized/docs/sizing.md)**: Pre-configured resource profiles (`Small`, `Medium`, `Large`), database connection planning, and optimization of OPcache buffers and InnoDB pool sizes.
* **[Logs Management and Tailing](file:///home/pinano/Documents/webroot/pinano-zend-app-dockerized/docs/logging.md)**: How to monitor errors in real time and guides to independently tail Apache records, PHP-FPM exceptions, and the Zend Framework logger.
* **[Monitoring with Zabbix](file:///home/pinano/Documents/webroot/pinano-zend-app-dockerized/docs/zabbix.md)**: How to integrate Zabbix templates and agents to extract metrics from the web server, databases, and host health.

---

## 4. Advanced Deployments

Special configurations for multi-project environments or cloud deployments:

* **[Multi-Tenancy (Multi-Client)](file:///home/pinano/Documents/webroot/pinano-zend-app-dockerized/docs/multi-tenancy.md)**: Guide on how to isolate and deploy multiple instances of the Zend stack on a single physical server sharing the reverse proxy (Traefik).
* **[Using Docker Compose Overrides](file:///home/pinano/Documents/webroot/pinano-zend-app-dockerized/docs/docker-compose-override-examples.md)**: Practical examples to scale the stack (Swarm, Kubernetes/Kompose) or execute custom configurations without modifying the base `docker-compose.yml` file.
