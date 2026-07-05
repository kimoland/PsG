# PasarGuard Panel – Railway Deploy

Deploy PasarGuard panel (https://github.com/PasarGuard/panel) on Railway.

## Files
- `Dockerfile` – builds PasarGuard panel from source and wraps startup for Railway.
- `start-railway.sh` – maps Railway's dynamic `$PORT` to PasarGuard's `UVICORN_PORT`.
- `railway.toml` – Railway build/deploy config.

## Quick start
1. Push this repo to GitHub.
2. Create a new Railway project → Deploy from GitHub repo.
3. (Optional) Set `SQLALCHEMY_DATABASE_URL` env var to use Postgres/MySQL instead of SQLite.
4. (Optional) Attach a Railway Volume mounted at `/code` if using SQLite, to persist data across redeploys.
5. After the first successful deploy, open a shell (Railway CLI) and run:
   `pasarguard cli admins --create <username>`

See the Persian guide document for full details.
