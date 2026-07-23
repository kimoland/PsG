#!/usr/bin/env bash
set -e

# پورت و اینترفیس‌های uvicorn
export UVICORN_HOST="0.0.0.0"
export UVICORN_PORT="${PORT:-8000}"

# دیتابیس پیش‌فرض sqlite
export SQLALCHEMY_DATABASE_URL="${SQLALCHEMY_DATABASE_URL:-sqlite+aiosqlite:///db.sqlite3}"
export ROLE="${ROLE:-all-in-one}"

# هدرهای پروکسی برای تشخیص HTTPS در Railway
export UVICORN_PROXY_HEADERS="${UVICORN_PROXY_HEADERS:-true}"
export UVICORN_FORWARDED_ALLOW_IPS="${UVICORN_FORWARDED_ALLOW_IPS:-*}"

echo "Starting PasarGuard panel on port ${UVICORN_PORT}..."

# 1. مایگریشن دیتابیس
python -m alembic upgrade head || true

# 2. ساخت فیزیکی ادمین در دیتابیس توسط CLI رسمی پاسارگاد (بدون نیاز به DEBUG)
if [ -n "${SUDO_USERNAME:-}" ] && [ -n "${SUDO_PASSWORD:-}" ]; then
    echo "Creating admin '${SUDO_USERNAME}' via PasarGuard CLI..."
    pasarguard cli admin create --username "$SUDO_USERNAME" --password "$SUDO_PASSWORD" --sudo || true
fi

# 3. اجرای پنل
exec /code/start.sh
