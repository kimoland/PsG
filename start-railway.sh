#!/usr/bin/env bash
set -e

export UVICORN_HOST="0.0.0.0"
export UVICORN_PORT="${PORT:-8000}"
export SQLALCHEMY_DATABASE_URL="${SQLALCHEMY_DATABASE_URL:-sqlite+aiosqlite:///db.sqlite3}"
export ROLE="${ROLE:-all-in-one}"
export UVICORN_PROXY_HEADERS="true"
export UVICORN_FORWARDED_ALLOW_IPS="*"

echo "Starting PasarGuard panel on port ${UVICORN_PORT}..."

sed -i 's/bind_args\["host"\] = ip/bind_args["host"] = server_settings.host/' /code/main.py || true

python -m alembic upgrade head || true

if [ -n "${SUDO_USERNAME:-}" ] && [ -n "${SUDO_PASSWORD:-}" ]; then
    echo "Creating admin '${SUDO_USERNAME}' via pasarguard-cli.py..."
    python /code/pasarguard-cli.py admin create --username "$SUDO_USERNAME" --password "$SUDO_PASSWORD" --sudo || true
fi

exec /code/start.sh
