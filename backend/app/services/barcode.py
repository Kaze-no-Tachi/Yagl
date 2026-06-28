"""Barcode (UPC/EAN) -> game candidate resolution chain.

Order of resolution:
  1. GameUPC  — purpose-built, human-verified UPC -> game (best signal).
  2. UPCItemDB — generic product DB; we take the product title and fuzzy-match
     it against IGDB to recover real game metadata.
  3. IGDB direct — last resort: treat the raw title (if any) as a search query.

Each step is best-effort; failures fall through to the next. The endpoint always
returns a (possibly empty) candidate list so the client can fall back to manual
search/entry.
"""
from __future__ import annotations

import httpx

from app.core.config import settings
from app.schemas.scan import GameCandidate
from app.services import igdb

_GAMEUPC_URL = "https://api.gameupc.com/v1/lookup"
_UPCITEMDB_TRIAL = "https://api.upcitemdb.com/prod/trial/lookup"


def _gameupc(barcode: str) -> list[GameCandidate]:
    if not settings.gameupc_api_key:
        return []
    try:
        with httpx.Client() as client:
            resp = client.get(
                _GAMEUPC_URL,
                params={"upc": barcode},
                headers={"Authorization": f"Bearer {settings.gameupc_api_key}"},
                timeout=12,
            )
            if resp.status_code != 200:
                return []
            data = resp.json()
    except httpx.HTTPError:
        return []

    out: list[GameCandidate] = []
    for g in data.get("games", []) or ([data] if data.get("title") else []):
        out.append(
            GameCandidate(
                title=g.get("title") or g.get("name") or "Unknown",
                platform_name=g.get("platform"),
                cover_url=g.get("cover") or g.get("image"),
                source="gameupc",
                confidence=0.85,
            )
        )
    return out


def _upcitemdb_title(barcode: str) -> str | None:
    try:
        with httpx.Client() as client:
            headers = {}
            url = _UPCITEMDB_TRIAL
            if settings.upcitemdb_api_key:
                headers["user_key"] = settings.upcitemdb_api_key
            resp = client.get(url, params={"upc": barcode}, headers=headers, timeout=12)
            if resp.status_code != 200:
                return None
            data = resp.json()
    except httpx.HTTPError:
        return None
    items = data.get("items") or []
    if not items:
        return None
    return items[0].get("title")


def resolve_barcode(barcode: str) -> list[GameCandidate]:
    barcode = barcode.strip()
    if not barcode:
        return []

    candidates = _gameupc(barcode)

    # Enrich/augment GameUPC hits with IGDB metadata by title, and provide the
    # IGDB-backed candidates which carry cover art + summary + igdb_id.
    seen_titles = {c.title.lower() for c in candidates}
    title = candidates[0].title if candidates else _upcitemdb_title(barcode)
    if title:
        for igdb_candidate in igdb.search_games(title, limit=5):
            if igdb_candidate.title.lower() not in seen_titles:
                candidates.append(igdb_candidate)
                seen_titles.add(igdb_candidate.title.lower())

    return candidates
