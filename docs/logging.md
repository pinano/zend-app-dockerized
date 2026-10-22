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
(it's under the application codebase bind mount). To tail it in real time:

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
