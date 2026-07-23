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

# ۳. همگام‌سازی و ساخت مستقیم ادمین Sudo در دیتابیس SQLite با هش نیتیو
if [ -n "${SUDO_USERNAME:-}" ] && [ -n "${SUDO_PASSWORD:-}" ]; then
    echo "Ensuring sudo admin '${SUDO_USERNAME}' password is synced in database..."
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
    for mod_name in [
        'app.app.utils.security',
        'app.utils.security',
        'app.core.security',
        'app.security',
        'app.services.security',
        'app.auth.security',
        'app.db.security'
    ]:
        try:
            m = __import__(mod_name, fromlist=['get_password_hash'])
            func = getattr(m, 'get_password_hash', None)
            if func:
                get_password_hash = func
                print(f'Using get_password_hash from {mod_name}')
                break
        except Exception:
            pass

    if not get_password_hash:
        print('Internal get_password_hash not found, using passlib CryptContext')
        from passlib.context import CryptContext
        pwd_context = CryptContext(schemes=['argon2', 'bcrypt'], deprecated='auto')
        get_password_hash = pwd_context.hash

    hashed = get_password_hash(password)

    async with GetDB() as db:
        try:
            from app.db.crud.admin import get_admin
            existing = await get_admin(db, username=username)
            if existing:
                existing.hashed_password = hashed
                db.add(existing)
                await db.commit()
                print(f'Admin {username} password successfully updated in database!')
                return
        except Exception as e:
            print('Check admin existing note:', e)

        try:
            try:
                admin_obj = Admin(username=username, hashed_password=hashed, sudo=True)
            except Exception:
                try:
                    admin_obj = Admin(username=username, hashed_password=hashed, is_sudo=True)
                except Exception:
                    admin_obj = Admin(username=username, hashed_password=hashed)

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
