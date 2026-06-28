from datetime import date, datetime
from decimal import Decimal
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, computed_field

from app.core.config import settings
from app.schemas.loan import LoanOut

Kind = Literal["game", "hardware", "accessory"]
Format = Literal["physical", "digital", "retro"]
Condition = Literal["sealed", "cib", "loose", "digital", "damaged"]


class PlatformOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    igdb_platform_id: int | None = None


class PhotoOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    path: str = Field(exclude=True)
    is_primary: bool

    @computed_field  # type: ignore[prop-decorator]
    @property
    def url(self) -> str:
        base = settings.media_url_base.rstrip("/")
        return f"{base}/{self.path.lstrip('/')}"


class ItemBase(BaseModel):
    kind: Kind = "game"
    format: Format = "physical"
    title: str = Field(min_length=1, max_length=500)
    platform_id: int | None = None
    barcode: str | None = None
    region: str | None = None
    condition: Condition | None = None
    condition_notes: str | None = None
    igdb_id: int | None = None
    cover_url: str | None = None
    summary: str | None = None
    release_date: date | None = None
    genres: list[str] | None = None
    acquired_date: date | None = None
    price_paid: Decimal | None = None
    storage_location: str | None = None
    notes: str | None = None


class ItemCreate(ItemBase):
    source: Literal["manual", "scan", "steam", "gog", "epic", "csv"] = "manual"
    store_app_id: str | None = None


class ItemUpdate(BaseModel):
    # All optional — partial update.
    kind: Kind | None = None
    format: Format | None = None
    title: str | None = Field(default=None, min_length=1, max_length=500)
    platform_id: int | None = None
    barcode: str | None = None
    region: str | None = None
    condition: Condition | None = None
    condition_notes: str | None = None
    cover_url: str | None = None
    summary: str | None = None
    release_date: date | None = None
    genres: list[str] | None = None
    acquired_date: date | None = None
    price_paid: Decimal | None = None
    storage_location: str | None = None
    notes: str | None = None


class ItemOut(ItemBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    source: str
    store_app_id: str | None = None
    platform: PlatformOut | None = None
    photos: list[PhotoOut] = []
    loans: list[LoanOut] = []
    created_at: datetime
    updated_at: datetime


class ItemList(BaseModel):
    items: list[ItemOut]
    total: int
