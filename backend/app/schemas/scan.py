from datetime import date

from pydantic import BaseModel


class ScanRequest(BaseModel):
    barcode: str


class GameCandidate(BaseModel):
    """A possible match for a scanned barcode or a manual search query.

    The client shows these for the user to confirm before an Item is created.
    """

    title: str
    igdb_id: int | None = None
    platform_name: str | None = None
    platform_id: int | None = None
    cover_url: str | None = None
    summary: str | None = None
    release_date: date | None = None
    genres: list[str] | None = None
    source: str  # which resolver produced it: gameupc | upcitemdb | igdb
    confidence: float = 0.0


class ScanResponse(BaseModel):
    barcode: str
    candidates: list[GameCandidate]


class MetadataSearchResponse(BaseModel):
    query: str
    candidates: list[GameCandidate]
