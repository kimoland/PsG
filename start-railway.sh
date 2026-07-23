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
import inspect

async def main():
    username = os.environ.get('SUDO_USERNAME', 'admin')
    password = os.environ.get('SUDO_PASSWORD', 'admin')
    
    try:
        from app.db.base import GetDB
    except ImportError:
        from app.db import GetDB

    from app.db.crud import admin as admin_crud

    AdminClass = None
    for mod_path in ['app.schemas.admin', 'app.schemas', 'app.db.schemas.admin', 'app.db.schemas', 'app.db.models', 'app.models']:
        try:
            m = __import__(mod_path, fromlist=['AdminCreate', 'Admin'])
            AdminClass = getattr(m, 'AdminCreate', None) or getattr(m, 'Admin', None)
            if AdminClass:
                print(f'Found AdminClass in {mod_path}')
                break
        except Exception:
            pass

    async with GetDB() as db:
        try:
            existing = await admin_crud.get_admin(db, username=username)
            if existing:
                print(f'Admin {username} already exists in database.')
                return
        except Exception as e:
            print('Check admin:', e)

        try:
            if AdminClass:
                try:
                    admin_in = AdminClass(username=username, password=password, is_sudo=True)
                except Exception:
                    admin_in = AdminClass(username=username, password=password)
                await admin_crud.create_admin(db, admin_in)
                print(f'Admin {username} successfully inserted into database!')
                return
        except Exception as e:
            print('Create admin error:', e)

asyncio.run(main())
" || true
fi

# ۴. اجرای سرویس
exec /code/start.sh
