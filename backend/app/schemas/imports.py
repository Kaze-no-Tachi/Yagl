from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class SteamImportRequest(BaseModel):
    # SteamID64, or a vanity profile name (resolved server-side).
    steam_id: str = Field(min_length=2, max_length=64)
    # Persist the connection so it can be re-synced later.
    save_connection: bool = True


class CsvColumnMapping(BaseModel):
    """Which CSV header maps to which Item field. Only `title` is required."""

    title: str
    platform: str | None = None
    store_app_id: str | None = None


class CsvImportRequest(BaseModel):
    csv_text: str
    mapping: CsvColumnMapping
    # Store games are digital by default; overridable.
    default_format: str = "digital"
    source: str = "csv"


class ImportResult(BaseModel):
    provider: str
    fetched: int          # how many owned titles the source returned
    created: int          # new items added
    skipped_duplicates: int
    unmatched: list[str] = []  # titles we could not match to IGDB (still created, no cover)


class StoreConnectionOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    provider: str
    external_account_id: str | None = None
    last_synced_at: datetime | None = None
