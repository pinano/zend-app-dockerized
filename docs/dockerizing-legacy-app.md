# Dockerizing a Legacy Zend Framework 1.x Application

This guide walks you through migrating and configuring a legacy Zend Framework 1.x (ZF1) application to run efficiently and securely inside this Docker stack.

---

## 1. Directory Structure Setup

To dockerize your application, clone or integrate this Docker stack directly into a `docker/` directory inside your Zend Framework 1.x application repository. The project repository root contains the Zend application codebase:

```
my-zend-project/             # Zend project repository root
├── application/             # ZF1 application code
│   ├── Bootstrap.php
│   ├── controllers/
│   ├── models/
│   └── ...
├── public/                  # Public web root
│   ├── index.php            # Entrypoint
│   └── ...
├── weblibs/                 # Custom / legacy shared libraries (FPDF, PHPOffice, etc.)
└── docker/                  # 👈 THIS REPOSITORY (Docker stack)
    ├── apache/              # Apache configuration (httpd.conf, security.conf)
    ├── php/                 # PHP & PHP-FPM configuration
    ├── scripts/             # Setup and maintenance scripts
    ├── docs/                # Documentation
    ├── docker-compose.yml   # Container orchestration
    ├── Dockerfile           # App container Dockerfile
    ├── Dockerfile.cron      # Cron container Dockerfile
    ├── Makefile             # Command task runner
    └── .env                 # Environment variables
```

> [!NOTE]
> The project root folder is bind-mounted directly to `/var/www/html/` inside the application container.

---

## 2. Handling URL Rewriting (No `.htaccess` Required)

Legacy ZF1 applications traditionally rely on a `.htaccess` file in the `public/` directory to redirect all requests to `index.php`. 

In this modern Docker environment:
- **`AllowOverride None`** is configured for performance (avoids scanning the filesystem on every request for `.htaccess` files).
- **Zend Rewrite Rules** are defined globally in Apache's virtual host configuration at [httpd.conf](../apache/httpd.conf).

Therefore, you **do not need** a `.htaccess` file in your `public/` folder. All requests not matching a physical static file, folder, or symlink are automatically forwarded to `index.php` at the Apache server level.

---

## 3. Shared Libraries (`weblibs`)

Many legacy projects require shared external libraries (such as old versions of Zend Framework, FPDF, or PHPExcel) that are not managed via Composer.

1. Ensure a `weblibs/` folder exists in your project root: `weblibs/`.
2. Move your custom external library folders inside `weblibs/`. For example:
   - `weblibs/Zend-1.12.17/`
   - `weblibs/fpdf16/`
   - `weblibs/PHPExcel-1.7.5/`
3. These libraries map to `/var/www/html/weblibs/` inside the container and will be registered in PHP's `include_path`.

---

## 4. Modern Libraries via Composer

If your project requires modern Composer packages (or you are gradually modernizing a legacy ZF1 app):

1. Place your `composer.json` file in your project root (`composer.json`).
2. Whenever the stack starts (`make start` or container boot), the container detects `composer.json` and automatically runs:
   ```bash
   composer install --prefer-dist --optimize-autoloader
   ```
3. The entrypoint template ([index.php.sample](index.php.sample)) automatically loads `vendor/autoload.php` if present:
   ```php
   $composerAutoload = ROOT_DIR . '/vendor/autoload.php';
   if (file_exists($composerAutoload)) {
       require_once $composerAutoload;
   }
   ```
4. You can also run Composer commands on demand from your host without entering the container (from within the `docker/` folder):
   ```bash
   make composer require <vendor/package>
   make composer update
   make composer dump-autoload
   ```

---

## 5. Automation: Setup Entrypoint in One Command

From the `docker/` directory, you can automatically generate/update the modern entrypoint structure using the following command:

```bash
make setup-index
```

### What does this command do?
1. Creates the directory `public` in the project root if it does not exist.
2. Scans `weblibs/` in the project root for directories and maps them to `/var/www/html/weblibs/` container paths. If a library contains a `Classes` subdirectory (e.g. `PHPExcel-1.7.5/Classes`) or a `library` subdirectory (standard for Zend Framework releases, e.g. `Zend-1.12.17/library`), it automatically resolves directly to it.
3. Automatically generates the `public/index.php` file using [index.php.sample](index.php.sample), injecting the detected include paths into the `$paths` array.
4. **Backup protection:** If `index.php` already exists, it automatically creates a `.bak` backup copy of the existing file before applying updates.

