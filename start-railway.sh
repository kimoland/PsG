#!/usr/bin/env bash
set -e

# ۱. اضافه کردن مسیر محیط مجازی پایتون
export PATH="/code/.venv/bin:$PATH"

# ۲. پورت و آدرس پروکسی برای Railway
export UVICORN_HOST="0.0.0.0"
export UVICORN_PORT="${PORT:-8000}"
export SQLALCHEMY_DATABASE_URL="${SQLALCHEMY_DATABASE_URL:-sqlite+aiosqlite:///db.sqlite3}"
export ROLE="${ROLE:-all-in-one}"
export UVICORN_PROXY_HEADERS="true"
export UVICORN_FORWARDED_ALLOW_IPS="*"

echo "Starting PasarGuard panel on port ${UVICORN_PORT}..."

# ۳. اصلاح اتوماتیک main.py جهت لیسن کردن روی 0.0.0.0 به جای localhost
sed -i 's/bind_args\["host"\] = ip/bind_args["host"] = server_settings.host/' /code/main.py || true

# ۴. مایگریشن دیتابیس
python -m alembic upgrade head || true

# ۵. ساخت ادمین در دیتابیس SQLite توسط CLI پاسارگاد
if [ -n "${SUDO_USERNAME:-}" ] && [ -n "${SUDO_PASSWORD:-}" ]; then
    echo "Creating admin '${SUDO_USERNAME}' via PasarGuard CLI..."
    pasarguard admin create --username "$SUDO_USERNAME" --password "$SUDO_PASSWORD" --sudo || \
    python -m app.cli admin create --username "$SUDO_USERNAME" --password "$SUDO_PASSWORD" --sudo || true
fi

# ۶. اجرای سرویس اصلی در حالت Production
exec /code/start.sh
