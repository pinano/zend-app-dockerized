# Logging Guide

There are two types of logs to monitor in this stack:

| Type | Command |
|---|---|
| Docker container logs (Apache, PHP errors, `error_log()`) | `make logs app` |
| Zend application log (`Zend_Log` to file) | `make logs-zend` |

```bash
make logs         # follow all container logs (all services)
make logs app     # follow only the app container
make logs-zend    # tail the Zend application log inside the container
```

## What appears automatically

| Source | Visible in `make logs app`? | Visible in `make logs-zend`? |
|---|---|---|
| Apache access log (every request + status code) | ✅ Yes | ❌ No |
| PHP fatal / parse errors | ✅ Yes | ❌ No |
| `error_log()` calls in PHP code | ✅ Yes | ❌ No |
| `Zend_Log` writes (`app.logfile`) | ❌ No | ✅ Yes |
| ZF1 exceptions caught by `ErrorController` | ❌ No (unless you add `error_log()`) | ❌ No |

## Why ZF1 500 errors are invisible by default

ZF1 routes all uncaught exceptions to `ErrorController::errorAction()` via the
`ErrorHandler` front-controller plugin (`throwErrors = false` in `application.ini`).
This prevents PHP from ever seeing the exception — so nothing reaches `error_log`
and nothing appears in Docker logs.

## Required: add `error_log()` to every ErrorController

Every module that has an `ErrorController` must forward 500 errors to stderr.
Add the following inside the `default:` / `EXCEPTION_OTHER:` case:

```php
case Zend_Controller_Plugin_ErrorHandler::EXCEPTION_OTHER:
default:
    $exception = $errors->exception;

    $this->getResponse()->setHttpResponseCode(500);
    // ... your existing code ...

    // ✅ REQUIRED: forward error to Docker logs
    error_log('[ZF1 500] ' . $exception->getMessage()
        . ' in ' . $exception->getFile() . ':' . $exception->getLine()
        . PHP_EOL . $exception->getTraceAsString());
    break;
```

### Modules with an ErrorController to check

Based on the application structure:

- `modules/default/controllers/ErrorController.php` ✅ (already done)
- `modules/backnet/controllers/ErrorController.php`
- `modules/api/controllers/ErrorController.php`
- `modules/app/controllers/ErrorController.php`

## PHP error display in development

In `APP_ENV=development`, `display_errors` is **Off** by default — errors are written
to the log instead of being printed in the HTTP response. This prevents stack traces
from leaking while still capturing all errors via `error_log()` / Zend Logger.

To make ZF1 throw exceptions instead of routing to `ErrorController` (useful during
active development), add to `application.ini` under `[development:production]`:

```ini
resources.frontController.throwErrors = true
```

> ⚠️ Never enable `throwErrors` in production — it exposes stack traces to end users.

## Zend application log (`app.logfile`)

The Zend application log (`app.logfile` in `application.ini`) is typically written to:

```
/var/www/html/application/logs/error.log   (inside the container)
```

> ℹ️ The exact path depends on your `application.ini` configuration. The `init-app.sh` script
> pre-creates this file with correct permissions on startup.

This path lives outside the container's `tmp` volume, so it **persists** across restarts
(it's under the `docroot` bind mount). To tail it in real time:

```bash
make logs-zend
```

> ℹ️ If you need ephemeral logs that reset on restart, change `app.logfile` in `application.ini`
> to a path under `/var/www/html/tmp/` (tmpfs), or redirect it to `php://stderr` (see below).

## Redirecting Zend_Log to stderr (optional)

If you prefer `Zend_Log` entries to appear in `make logs app` alongside PHP errors,
change the writer path to `php://stderr`:

```ini
; application.ini [production]
resources.logger.path   = "php://stderr"
resources.logger.writer = "simple"
```

> ⚠️ With this option `make logs zend` will no longer work (no file to tail).

---

## Structured JSON Logging for Grafana Alloy / Loki (Recommended)

If you run **Grafana Alloy + Loki** in your Traefik stack, plain text logs force you
to write complex regex parsers. A better approach is emitting **one JSON line per log
event** so Alloy can parse fields natively with a `json` stage.

### Option A: Simple text via `error_log()` (Zero code changes in controllers)

The `public/index.php` template now includes a global error handler that forwards
**all PHP errors and fatal shutdowns** to `error_log()`, which flows into Docker logs:

```php
register_shutdown_function(function () {
    $error = error_get_last();
    if ($error && in_array($error['type'], [E_ERROR, E_PARSE, E_CORE_ERROR, E_COMPILE_ERROR, E_USER_ERROR])) {
        error_log(sprintf('[ZF1 FATAL] %s in %s:%d', $error['message'], $error['file'], $error['line']));
    }
});

set_error_handler(function ($errno, $errstr, $errfile, $errline) {
    if (!(error_reporting() & $errno)) return false;
    $map = [E_WARNING => 'WARNING', E_NOTICE => 'NOTICE', E_DEPRECATED => 'DEPRECATED'];
    $level = $map[$errno] ?? 'ERROR';
    error_log(sprintf('[PHP %s] %s in %s:%d', $level, $errstr, $errfile, $errline));
    return false;
});
```

**What this captures:**
- PHP fatals, parse errors, memory exhausted
- Warnings and notices (even those swallowed by `@` if you adjust the handler)
- Any explicit `error_log()` calls you add to `ErrorController`

**What this does NOT capture:**
- Normal `Zend_Log::info()` / `Zend_Log::debug()` calls from business logic
- Exceptions caught gracefully by `ErrorController` (unless you add `error_log()` there)

### Option B: Structured JSON via custom `Zend_Log` writer (Best for Loki)

A custom writer `Log_Writer_StderrJson` is provided in `docs/Log_Writer_StderrJson.php`.
It converts every `Zend_Log` event into a JSON line written to STDERR:

```json
{"time":"2025-01-15T09:30:00+01:00","level":"ERR","message":"User login failed","logger":"zend","module":"default","controller":"auth"}
```

#### Installation

1. Copy the file to your ZF1 library folder:
   ```bash
   cp docs/Log_Writer_StderrJson.php docroot/library/Log/Writer/StderrJson.php
   ```

2. Update `application.ini`:
   ```ini
   [production]
   resources.logger.writerName = "StderrJson"
   ```

3. If your autoloader does not find the class, require it manually in `public/index.php`:
   ```php
   require_once 'Log/Writer/StderrJson.php';
   ```

4. (Optional) Enrich logs with static metadata in `index.php`:
   ```php
   $logger = Zend_Registry::get('logger');
   $logger->setEventItem('project', getenv('PROJECT_NAME'));
   $logger->setEventItem('env', APPLICATION_ENV);
   ```

> 💡 **Tip:** Combine Option A (global error handler) + Option B (JSON writer).
> Option A catches fatals and PHP errors. Option B catches application-level events.
> Both land in the same Docker log stream consumed by Alloy.

### Alloy / Loki Configuration Example

Add this `loki.process` or `promtail` scrape config to parse the JSON lines:

```alloy
loki.source.docker "zend_apps" {
  host       = "unix:///var/run/docker.sock"
  labels     = {"job" = "zend-legacy"}
}

loki.process "zend_json" {
  forward_to = [loki.write.default.receiver]

  stage.json {
    expressions = {
      level   = "level",
      message = "message",
      logger  = "logger",
    }
  }

  stage.labels {
    values = {
      level  = "level",
      logger = "logger",
    }
  }
}
```

With this setup, you can query in Grafana:
```logql
{job="zend-legacy"} | json | level="ERR"
```
