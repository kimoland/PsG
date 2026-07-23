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

# ۱. اصلاح پورت و شبکه
sed -i 's/bind_args\["host"\] = ip/bind_args["host"] = server_settings.host/' /code/main.py || true

# ۲. مایگریشن دیتابیس
python -m alembic upgrade head || true

# ۳. ثبت اتوماتیک کلید موقت در دیتابیس SQLite جهت تایید ۱۰۰٪ در مرورگر
if [ -n "${TEMP_KEY:-}" ]; then
    echo "Registering TEMP_KEY '${TEMP_KEY}' in database..."
    python -c "
import asyncio
import os
from datetime import datetime, timedelta, timezone
from app.db.base import GetDB
from app.db.models import TempKey

async def insert_key():
    key_str = os.environ.get('TEMP_KEY')
    if not key_str:
        return
    now = datetime.now(timezone.utc)
    expires = now + timedelta(minutes=60)
    async with GetDB() as db:
        tk = TempKey(key=key_str, created_at=now, expires_at=expires)
        db.add(tk)
        try:
            await db.commit()
            print('TempKey registered successfully in database:', key_str)
        except Exception as e:
            await db.rollback()
            print('TempKey registration skipped:', e)

asyncio.run(insert_key())
" || true
fi

# ۴. اجرای پنل
exec /code/start.sh
