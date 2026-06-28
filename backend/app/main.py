"""FastAPI application entrypoint: middleware, routers, media mount, startup seed."""
import os
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.api import auth, imports, items, loans, metadata, photos, scan
from app.core.config import settings
from app.core.db import SessionLocal
from app.seed import seed_platforms


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Serve uploaded photos from the local media root (when using local storage).
    already_mounted = any(getattr(r, "name", None) == "media" for r in app.routes)
    if settings.storage_backend == "local" and not already_mounted:
        os.makedirs(settings.media_root, exist_ok=True)
        app.mount(
            settings.media_url_base, StaticFiles(directory=settings.media_root), name="media"
        )
    with SessionLocal() as db:
        seed_platforms(db)
    yield


app = FastAPI(title=f"{settings.app_name} API", version="0.1.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origin_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(items.router)
app.include_router(photos.router)
app.include_router(loans.router)
app.include_router(scan.router)
app.include_router(metadata.router)
app.include_router(imports.router)


@app.get("/health", tags=["meta"])
def health() -> dict[str, object]:
    return {
        "status": "ok",
        "igdb": settings.igdb_enabled,
        "steam": settings.steam_enabled,
    }
