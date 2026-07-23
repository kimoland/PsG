#!/usr/bin/env bash
set -e

export PATH="/code/.venv/bin:$PATH"
export UVICORN_HOST="0.0.0.0"
export UVICORN_PORT="${PORT:-8000}"
export SQLALCHEMY_DATABASE_URL="${SQLALCHEMY_DATABASE_URL:-sqlite+aiosqlite:///db.sqlite3}"
export ROLE="${ROLE:-all-in-one}"
export UVICORN_PROXY_HEADERS="true"
export UVICORN_FORWARDED_ALLOW_IPS="*"

echo "Starting PasarGuard panel on port ${UVICORN_PORT}..."

# باز کردن قفل localhost روی 0.0.0.0
sed -i 's/bind_args\["host"\] = ip/bind_args["host"] = server_settings.host/' /code/main.py || true

# ۱. مایگریشن دیتابیس
python -m alembic upgrade head || true

# ۲. ساخت ادمین در دیتابیس توسط pasarguard-cli.py
if [ -n "${SUDO_USERNAME:-}" ] && [ -n "${SUDO_PASSWORD:-}" ]; then
    echo "Creating admin '${SUDO_USERNAME}'..."
    python /code/pasarguard-cli.py admin create --username "$SUDO_USERNAME" --password "$SUDO_PASSWORD" --sudo || true
fi

# ۳. اجرای سرویس
exec /code/start.sh
