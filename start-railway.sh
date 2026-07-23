#!/usr/bin/env bash
set -e

export UVICORN_HOST="0.0.0.0"
export UVICORN_PORT="${PORT:-8000}"

export SQLALCHEMY_DATABASE_URL="${SQLALCHEMY_DATABASE_URL:-sqlite+aiosqlite:///db.sqlite3}"
export ROLE="${ROLE:-all-in-one}"

export UVICORN_PROXY_HEADERS="${UVICORN_PROXY_HEADERS:-true}"
export UVICORN_FORWARDED_ALLOW_IPS="${UVICORN_FORWARDED_ALLOW_IPS:-*}"

echo "Starting PasarGuard panel on port ${UVICORN_PORT}..."

python -m alembic upgrade head || true

if [ -n "${SUDO_USERNAME:-}" ] && [ -n "${SUDO_PASSWORD:-}" ]; then
    echo "Creating database admin user '${SUDO_USERNAME}'..."
    python -c "
import asyncio
import os
from passlib.context import CryptContext
from app.db.base import GetDB
from app.db.models import Admin

pwd_context = CryptContext(schemes=['bcrypt'], deprecated='auto')

async def init_admin():
    username = os.environ.get('SUDO_USERNAME')
    password = os.environ.get('SUDO_PASSWORD')
    if not username or not password:
        return
    hashed = pwd_context.hash(password)
    async with GetDB() as db:
        admin = Admin(username=username, hashed_password=hashed, is_sudo=True)
        db.add(admin)
        try:
            await db.commit()
            print('Admin created successfully in database.')
        except Exception as e:
            await db.rollback()
            print('Admin creation skipped (already exists or DB locked):', e)

asyncio.run(init_admin())
" || true
fi

exec /code/start.sh
