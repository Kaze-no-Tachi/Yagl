from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.config import settings
from app.core.db import get_db
from app.core.security import encrypt_secret
from app.models import StoreConnection, User
from app.schemas.imports import (
    CsvImportRequest,
    ImportResult,
    SteamImportRequest,
    StoreConnectionOut,
)
from app.services.importers.base import persist_owned_games
from app.services.importers.csv_import import CsvImporter
from app.services.importers.steam import SteamImporter, SteamImportError

router = APIRouter(prefix="/imports", tags=["imports"])


@router.post("/steam", response_model=ImportResult)
def import_steam(
    payload: SteamImportRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> ImportResult:
    if not settings.steam_enabled:
        raise HTTPException(
            status.HTTP_503_SERVICE_UNAVAILABLE,
            "Steam import is not configured (STEAM_API_KEY missing).",
        )
    importer = SteamImporter(steam_id=payload.steam_id)
    try:
        owned = importer.fetch_owned()
    except SteamImportError as exc:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, str(exc)) from exc

    result = persist_owned_games(db, user, "steam", owned, default_format="digital")

    if payload.save_connection:
        _upsert_connection(db, user, "steam", payload.steam_id, settings.steam_api_key)
    return result


@router.post("/csv", response_model=ImportResult)
def import_csv(
    payload: CsvImportRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> ImportResult:
    importer = CsvImporter(payload.csv_text, payload.mapping)
    try:
        owned = importer.fetch_owned()
    except ValueError as exc:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, str(exc)) from exc
    # The CSV's logical origin (epic/gog/csv) is recorded as the item source.
    provider = payload.source or "csv"
    return persist_owned_games(db, user, provider, owned, default_format=payload.default_format)


@router.get("/connections", response_model=list[StoreConnectionOut])
def list_connections(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> list[StoreConnection]:
    return list(
        db.scalars(select(StoreConnection).where(StoreConnection.user_id == user.id)).all()
    )


def _upsert_connection(
    db: Session, user: User, provider: str, account_id: str, credential: str | None
) -> None:
    conn = db.scalar(
        select(StoreConnection).where(
            StoreConnection.user_id == user.id, StoreConnection.provider == provider
        )
    )
    if conn is None:
        conn = StoreConnection(user_id=user.id, provider=provider)
        db.add(conn)
    conn.external_account_id = account_id
    if credential:
        conn.credential_enc = encrypt_secret(credential)
    conn.last_synced_at = datetime.now(timezone.utc)
    db.commit()
