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

# ۱. پچ main.py برای آدرس 0.0.0.0
sed -i 's/bind_args\["host"\] = ip/bind_args["host"] = server_settings.host/' /code/main.py || true

# ۲. مایگریشن دیتابیس
python -m alembic upgrade head || true

# ۳. ساخت فیزیکی و تضمینی ادمین Sudo در دیتابیس SQLite با سورس پایتون
if [ -n "${SUDO_USERNAME:-}" ] && [ -n "${SUDO_PASSWORD:-}" ]; then
    echo "Ensuring sudo admin '${SUDO_USERNAME}' exists in database..."
    python -c "
import asyncio
import os
from app.db.base import GetDB
from app.db.crud.admin import create_admin, get_admin
from app.db.schemas.admin import AdminCreate

async def init_admin():
    username = os.environ.get('SUDO_USERNAME', 'admin')
    password = os.environ.get('SUDO_PASSWORD', 'admin')
    async with GetDB() as db:
        existing = await get_admin(db, username=username)
        if existing:
            print(f'Admin {username} already exists in database.')
            return
        try:
            admin_in = AdminCreate(username=username, password=password, is_sudo=True)
            await create_admin(db, admin_in)
            print(f'Admin {username} successfully inserted into database!')
        except Exception as e:
            print(f'Admin creation note: {e}')

asyncio.run(init_admin())
" || true
fi

# ۴. اجرای سرویس اصلی
exec /code/start.sh
