#!/bin/bash
# Evaluates APP_ENV and exports variables for docker-compose to use

# Save current APP_ENV if passed inline
CURRENT_APP_ENV="${APP_ENV:-}"

if [ -f .env ]; then
  # Load .env variables
  set -a
  . .env
  set +a
fi

# Override with inline if it existed
if [ -n "$CURRENT_APP_ENV" ]; then
  export APP_ENV="$CURRENT_APP_ENV"
fi

if [ "$APP_ENV" = "development" ]; then
    export APP_ENV_IS_DEV_TIMESTAMPS=1
    export APP_ENV_IS_DEV_FREQ=0
else
    export APP_ENV_IS_DEV_TIMESTAMPS=0
    export APP_ENV_IS_DEV_FREQ=60
fi
