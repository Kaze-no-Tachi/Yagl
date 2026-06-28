from fastapi import APIRouter, Depends, Query
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.db import get_db
from app.models import Platform, User
from app.schemas.item import PlatformOut
from app.schemas.scan import MetadataSearchResponse
from app.services import igdb

router = APIRouter(tags=["metadata"])


@router.get("/metadata/search", response_model=MetadataSearchResponse)
def search_metadata(
    q: str = Query(min_length=1),
    _: User = Depends(get_current_user),
) -> MetadataSearchResponse:
    """Manual IGDB search — the fallback path for retro/unscannable items."""
    return MetadataSearchResponse(query=q, candidates=igdb.search_games(q))


@router.get("/platforms", response_model=list[PlatformOut])
def list_platforms(
    db: Session = Depends(get_db),
    _: User = Depends(get_current_user),
) -> list[Platform]:
    return list(db.scalars(select(Platform).order_by(Platform.name)).all())
