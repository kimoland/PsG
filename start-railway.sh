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

# ۳. همگام‌سازی و بررسی دقیق ساختار نقش‌ها در دیتابیس
if [ -n "${SUDO_USERNAME:-}" ] && [ -n "${SUDO_PASSWORD:-}" ]; then
    echo "Ensuring sudo admin '${SUDO_USERNAME}' exists with full Owner permissions..."
    python -c "
import asyncio
import os
import inspect
import pkgutil
import importlib

async def main():
    username = os.environ.get('SUDO_USERNAME', 'admin')
    password = os.environ.get('SUDO_PASSWORD', 'admin')
    
    try:
        from app.db.base import GetDB
    except ImportError:
        from app.db import GetDB

    from app.db.models import Admin

    get_password_hash = None
    import app
    for importer, modname, ispkg in pkgutil.walk_packages(app.__path__, app.__name__ + '.'):
        try:
            mod = importlib.import_module(modname)
            for attr in ['hash_password', 'get_password_hash', 'get_password_hash_func']:
                if hasattr(mod, attr) and callable(getattr(mod, attr)):
                    get_password_hash = getattr(mod, attr)
                    break
            if get_password_hash:
                break
        except Exception:
            pass

    if not get_password_hash:
        try:
            from pwdlib import PasswordHash
            pwd_context = PasswordHash.recommended()
            get_password_hash = pwd_context.hash
        except Exception:
            import hashlib
            get_password_hash = lambda p: hashlib.sha256(p.encode()).hexdigest()

    if inspect.iscoroutinefunction(get_password_hash):
        hashed = await get_password_hash(password)
    else:
        hashed = get_password_hash(password)

    def apply_owner_permissions(obj):
        if hasattr(obj, 'is_sudo'):
            obj.is_sudo = True
        if hasattr(obj, 'sudo'):
            obj.sudo = True

    async with GetDB() as db:
        try:
            from app.db.crud.admin import get_admin
            existing = await get_admin(db, username=username)
            if existing:
                existing.hashed_password = hashed
                apply_owner_permissions(existing)
                db.add(existing)
                await db.commit()
                print(f'Admin {username} updated!')
            else:
                admin_obj = Admin(username=username, hashed_password=hashed)
                apply_owner_permissions(admin_obj)
                db.add(admin_obj)
                await db.commit()
                print(f'Admin {username} created!')
        except Exception as e:
            print('Create admin error:', e)

        # بررسی و چاپ دقیق ساختار ستون‌های دیتابیس
        try:
            from sqlalchemy import text
            res = await db.execute(text(\"SELECT * FROM admins WHERE username='admin'\"))
            row = res.fetchone()
            print('Admin DB Row Columns:', res.keys())
            print('Admin DB Row Data:', row)
            
            try:
                roles_res = await db.execute(text(\"SELECT * FROM roles\"))
                print('Roles Table Columns:', roles_res.keys())
                print('Roles Table Rows:', roles_res.fetchall())
            except Exception as e:
                print('No roles table:', e)
        except Exception as e:
            print('DB inspect error:', e)

asyncio.run(main())
" || true
fi

# ۴. اجرای سرویس
exec /code/start.sh
