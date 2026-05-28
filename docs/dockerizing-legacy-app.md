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

## 4. Automation: Setup Entrypoint in One Command

You can automatically generate/update the modern entrypoint structure using the following command:

```bash
make setup-index
```

### What does this command do?
1. Creates the directory `docroot/public` if it does not exist.
2. Scans `docroot/weblibs/` for directories and maps them to `/var/www/html/weblibs/` container paths. If a library contains a `Classes` subdirectory (e.g. `PHPExcel-1.7.5/Classes`), it automatically resolves to it.
3. Automatically generates the `docroot/public/index.php` file using [index.php.sample](file:///home/pinano/Documents/webroot/pinano-zend-app-dockerized/docs/index.php.sample), injecting the detected include paths into the `$paths` array.
4. **Backup protection:** If `index.php` already exists, it automatically creates a `.bak` backup copy of the existing file before applying updates.
