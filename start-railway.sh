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

# ۳. ساخت فیزیکی و مستقیم ادمین Sudo در دیتابیس SQLite
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

    from app.db.models import Admin

    get_password_hash = None
    for mod in ['app.security', 'app.core.security', 'app.db.security']:
        try:
            m = __import__(mod, fromlist=['get_password_hash'])
            get_password_hash = getattr(m, 'get_password_hash', None)
            if get_password_hash:
                break
        except Exception:
            pass

    async with GetDB() as db:
        try:
            from app.db.crud.admin import get_admin
            existing = await get_admin(db, username=username)
            if existing:
                print(f'Admin {username} already exists in database.')
                return
        except Exception:
            pass

        try:
            hashed = get_password_hash(password) if get_password_hash else password
            admin_obj = Admin(username=username, hashed_password=hashed, is_sudo=True)
            db.add(admin_obj)
            await db.commit()
            print(f'Admin {username} successfully created and saved in database!')
        except Exception as e:
            print('Create admin error:', e)

asyncio.run(main())
" || true
fi

# ۴. اجرای سرویس
exec /code/start.sh
