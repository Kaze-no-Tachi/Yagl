# Yagl — Personal Game & Hardware Library Tracker

Track your physical, digital, and retro games **and** hardware in one place, with a
companion mobile app (à la GameEye) that scans barcodes to add items, plus a web
dashboard. All data lives on your own server.

- **Backend:** Python · FastAPI · PostgreSQL · SQLAlchemy + Alembic (`backend/`)
- **Frontend:** Flutter — one codebase for iOS, Android, **and** web (`mobile/`)
- **Deploy:** fully Dockerized so it runs the same on Fly.io, a VPS, or a home server.

## Features

- 📷 **Barcode scan + manual add** — scan a UPC; resolve via GameUPC → UPCItemDB → IGDB; confirm a candidate. Manual IGDB search for retro/unscannable items.
- 🎮 **Games + hardware + accessories** — one model, filterable by platform / kind / format / condition.
- 🏷️ **Condition, photos & lending** — per-item condition (sealed/CIB/loose/…), your own photos, and a who-borrowed-it loan tracker.
- 📥 **Digital library import** — **Steam** (official Web API) + **generic CSV** (Epic/GOG/any export). Imports are matched to IGDB and de-duplicated.
- 🔒 **Accounts/JWT** from day one — personal now, multi-user-ready later.

> Value/price tracking (PriceCharting) and native GOG/Epic OAuth connectors are planned for v2; the data layer is built to slot them in.

## Quick start (Docker)

```bash
cp backend/.env.example backend/.env      # then edit SECRET_KEY and any API keys
docker compose up --build
```

- API + interactive docs: http://localhost:8000/docs
- Health: http://localhost:8000/health
- DB inspector (Adminer): http://localhost:8080  (server `db`, user/pass/db `yagl`)

The API works with **no** external keys (manual add + CSV import). To enable the rest:

| Feature | Env var(s) | Where to get it |
|---|---|---|
| Game metadata (covers, search) | `IGDB_CLIENT_ID`, `IGDB_CLIENT_SECRET` | https://dev.twitch.tv/console/apps |
| Barcode → game | `GAMEUPC_API_KEY` (+ optional `UPCITEMDB_API_KEY`) | https://www.gameupc.com/ |
| Steam import | `STEAM_API_KEY` | https://steamcommunity.com/dev/apikey |

## Local backend dev (without Docker)

```bash
cd backend
python -m venv .venv && . .venv/bin/activate
pip install -e ".[dev]"
export DATABASE_URL="sqlite+pysqlite:///./yagl.db"   # or a local Postgres URL
alembic upgrade head
uvicorn app.main:app --reload
pytest
```

## Mobile / web app

See [`mobile/README.md`](mobile/README.md) for running the Flutter app on a device,
in the browser, and pointing it at your API.

## Repository layout

```
backend/   FastAPI service (API, models, services, importers, migrations, tests)
mobile/    Flutter app (iOS + Android + web)
docker-compose.yml
```
