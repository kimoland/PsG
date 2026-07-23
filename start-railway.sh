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

# ۱. پچ main.py برای آی‌پی 0.0.0.0
sed -i 's/bind_args\["host"\] = ip/bind_args["host"] = server_settings.host/' /code/main.py || true

# ۲. مایگریشن دیتابیس
python -m alembic upgrade head || true

# ۳. ساخت فیزیکی و تضمینی ادمین Sudo در دیتابیس SQLite پایتون
if [ -n "${SUDO_USERNAME:-}" ] && [ -n "${SUDO_PASSWORD:-}" ]; then
    echo "Ensuring sudo admin '${SUDO_USERNAME}' exists in database..."
    python -c "
import asyncio
import os

async def main():
    username = os.environ.get('SUDO_USERNAME', 'admin')
    password = os.environ.get('SUDO_PASSWORD', 'admin')
    
    try:
        from app.db.base import GetDB
    except ImportError:
        from app.db import GetDB

    admin_crud = None
    try:
        from app.db.crud import admin as admin_crud
    except ImportError:
        try:
            import app.crud.admin as admin_crud
        except ImportError:
            pass

    admin_schema = None
    try:
        from app.schemas.admin import AdminCreate as admin_schema
    except ImportError:
        try:
            from app.schemas import AdminCreate as admin_schema
        except ImportError:
            pass

    async with GetDB() as db:
        if admin_crud and hasattr(admin_crud, 'get_admin'):
            try:
                existing = await admin_crud.get_admin(db, username=username)
                if existing:
                    print(f'Admin {username} already exists in database.')
                    return
            except Exception as e:
                print('Check admin:', e)

        if admin_crud and hasattr(admin_crud, 'create_admin'):
            try:
                if admin_schema:
                    admin_in = admin_schema(username=username, password=password, is_sudo=True)
                    await admin_crud.create_admin(db, admin_in)
                else:
                    await admin_crud.create_admin(db, username=username, password=password, is_sudo=True)
                print(f'Admin {username} successfully inserted into database!')
                return
            except Exception as e:
                print('Create admin error:', e)

asyncio.run(main())
" || true
fi

# ۴. اجرای سرویس
exec /code/start.sh
