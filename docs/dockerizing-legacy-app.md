# Dockerizing a Legacy Zend Framework 1.x Application

This guide walks you through migrating and configuring a legacy Zend Framework 1.x (ZF1) application to run efficiently and securely inside this Docker stack.

---

## 1. Directory Structure Setup

To dockerize your application, place the codebase inside the `docroot/` folder. The folder structure should align with a standard ZF1 layout:

```
.
├── docker/
├── docs/
├── docroot/                  # 👈 Copy your application code here (ignored by Git)
│   ├── application/
│   │   ├── Bootstrap.php
│   │   ├── configs/
│   │   │   └── application.ini
│   │   ├── controllers/
│   │   └── ...
│   ├── public/
│   │   ├── index.php         # Entrypoint
│   │   └── ...
│   └── weblibs/              # 👈 Custom / legacy shared libraries (FPDF, PHPOffice, etc.)
└── docker-compose.yml
```

> [!NOTE]
> The `docroot/` folder is bind-mounted directly to `/var/www/html/` inside the application container.

---

## 2. Handling URL Rewriting (No `.htaccess` Required)

Legacy ZF1 applications traditionally rely on a `.htaccess` file in the `public/` directory to redirect all requests to `index.php`. 

In this modern Docker environment:
- **`AllowOverride None`** is configured for performance (avoids scanning the filesystem on every request for `.htaccess` files).
- **Zend Rewrite Rules** are defined globally in Apache's virtual host configuration at [httpd.conf](file:///home/pinano/Documents/webroot/pinano-zend-app-dockerized/docker/apache/httpd.conf).

Therefore, you **do not need** a `.htaccess` file in your `public/` folder. All requests not matching a physical static file, folder, or symlink are automatically forwarded to `index.php` at the Apache server level.

---

## 3. Shared Libraries (`weblibs`)

Many legacy projects require shared external libraries (such as old versions of Zend Framework, FPDF, or PHPExcel) that are not managed via Composer.

1. Create a `weblibs/` folder inside `docroot/`: `docroot/weblibs/`.
2. Move your custom external library folders inside `docroot/weblibs/`. For example:
   - `docroot/weblibs/Zend-1.12.17/`
   - `docroot/weblibs/fpdf16/`
   - `docroot/weblibs/PHPExcel-1.7.5/`
3. These libraries will map to `/var/www/html/weblibs/` inside the container and must be registered in the PHP `include_path`.

---

## 4. Automation: Setup Configurations in One Command

You can automatically generate/update the modern entrypoint and configuration structure using the following command:

```bash
make setup-legacy-configs
```

### What does this command do?
1. Creates the directories `docroot/public` and `docroot/application/configs` if they do not exist.
2. Scans `docroot/weblibs/` for directories and maps them to `/var/www/html/weblibs/` container paths. If a library contains a `Classes` subdirectory (e.g. `PHPExcel-1.7.5/Classes`), it automatically resolves to it.
3. Automatically generates the `docroot/public/index.php` file using [index.php.sample](file:///home/pinano/Documents/webroot/pinano-zend-app-dockerized/docs/index.php.sample), injecting the detected include paths into the `$paths` array.
4. Copies the clean and formatted [application.ini.sample](file:///home/pinano/Documents/webroot/pinano-zend-app-dockerized/docs/application.ini.sample) template to `docroot/application/configs/application.ini`.
5. **Backup protection:** If a file already exists, it automatically creates a `.bak` backup copy of the existing configuration before applying updates.

---

## 5. Security & Configurations via Environment Variables

To prevent committing database credentials or API secrets (e.g., to GitHub), the generated `index.php` and `application.ini` files load credentials dynamically from Docker's environment variables.

### How to use variables in configuration:
1. Define the parameters in your local `.env` file (e.g., `DB_HOST=db`, `SMTP_SERVER=mail.example.com`).
2. The `index.php` loads them using `getenv_docker()` and defines global PHP constants:
   ```php
   define('DB_HOST', getenv_docker('DB_HOST', 'unknown'));
   define('SMTP_SERVER', getenv_docker('SMTP_SERVER', ''));
   ```
3. The `application.ini` references these constants directly (without quotes):
   ```ini
   resources.multidb.mysql.host = DB_HOST
   resources.email.smtp.server  = SMTP_SERVER
   ```

### Recommended `.env` configurations:
Ensure these variables are set in your `.env` file to fully configure your app:
- Database connectivity: `DB_HOST`, `DB_NAME`, `DB_USER`, `DB_PASS`
- SMTP Server: `SMTP_SERVER`, `SMTP_SSL` (e.g. `tls`), `SMTP_PORT` (e.g. `587`), `SMTP_USER`, `SMTP_PASS`

---

## 6. Environment Inheritance in `application.ini`

The generated `application.ini` is structured to support standard Zend environment inheritance based on the Docker `APP_ENV` variable (`production` or `development`):

- **`[production]`**: Heavy caching enabled, PHP startup errors / display errors turned off to prevent leaks.
- **`[development : production]`**: Development settings that override production parameters:
  - Enables PHP startup errors and display errors.
  - Sets `resources.frontController.throwErrors = true` so exceptions bubble up instead of being swallowed.

---

## 7. Redis / Valkey Caching By Default

The generated `application.ini` comes pre-configured to use **Redis** (powered by Valkey in the stack) for caching out of the box:

- **Metadata Cache**: Database schema metadata (`resources.cache.metadata_cache`) is cached in Redis instead of SQLite files to improve I/O speed.
- **Application Cache Manager**: A general `general` cache resource is configured with the `Cm_Cache_Backend_Redis` backend.

To use these caches, ensure you have enabled the `redis` compose profile in your `.env` file (`COMPOSE_PROFILES=redis`) and restarted the stack.

