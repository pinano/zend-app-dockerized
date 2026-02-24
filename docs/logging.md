# Logging Guide

Docker captures all output written to `stdout`/`stderr` by the container. Run:

```bash
make logs app       # follow all container logs
make logs app -n 50 # last 50 lines
```

## What appears automatically

| Source | Visible in `make logs`? |
|---|---|
| Apache access log (every request + status code) | ✅ Yes |
| PHP fatal / parse errors | ✅ Yes |
| `error_log()` calls in PHP code | ✅ Yes |
| `Zend_Log` writing to a **file** | ❌ No (file inside container) |
| ZF1 exceptions caught by `ErrorController` | ❌ No (unless you add `error_log()`, see below) |

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

## Enabling full PHP error display (development only)

In `APP_ENV=development`, errors are already configured to display (`display_errors=On`).
To also make ZF1 throw exceptions instead of routing to ErrorController, add to
`application.ini` under `[development:production]`:

```ini
resources.frontController.throwErrors = true
```

> ⚠️ Never enable `throwErrors` in production — it exposes stack traces to end users.

## Redirecting Zend_Log to stderr (optional)

If you use `Zend_Log` in your application and want those logs visible in Docker,
change the writer path from the logfile to `php://stderr`:

```ini
; application.ini [production]
resources.logger.path   = "php://stderr"
resources.logger.writer = "simple"
```
