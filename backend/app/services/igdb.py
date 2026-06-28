"""IGDB metadata client.

Auth uses Twitch's OAuth2 client-credentials flow; the resulting app access
token lives ~60 days so we cache it in memory and refresh on expiry. If IGDB
credentials are not configured, search returns an empty list (manual add still
works) instead of raising.
"""
from __future__ import annotations

import time
from datetime import date, datetime, timezone

import httpx

from app.core.config import settings
from app.schemas.scan import GameCandidate

_TWITCH_TOKEN_URL = "https://id.twitch.tv/oauth2/token"
_IGDB_BASE = "https://api.igdb.com/v4"
# IGDB cover image_id -> usable cover URL (t_cover_big ~ 264x374).
_COVER_TMPL = "https://images.igdb.com/igdb/image/upload/t_cover_big/{image_id}.jpg"

# Module-level token cache: (access_token, expires_at_epoch).
_token_cache: tuple[str, float] | None = None


class IgdbError(RuntimeError):
    pass


def _get_token(client: httpx.Client) -> str:
    global _token_cache
    now = time.time()
    if _token_cache and _token_cache[1] - 60 > now:
        return _token_cache[0]
    resp = client.post(
        _TWITCH_TOKEN_URL,
        params={
            "client_id": settings.igdb_client_id,
            "client_secret": settings.igdb_client_secret,
            "grant_type": "client_credentials",
        },
        timeout=15,
    )
    resp.raise_for_status()
    data = resp.json()
    token = data["access_token"]
    _token_cache = (token, now + int(data.get("expires_in", 3600)))
    return token


def _headers(token: str) -> dict[str, str]:
    return {"Client-ID": settings.igdb_client_id or "", "Authorization": f"Bearer {token}"}


def _to_candidate(game: dict, source: str = "igdb", confidence: float = 0.6) -> GameCandidate:
    cover_url = None
    cover = game.get("cover")
    if isinstance(cover, dict) and cover.get("image_id"):
        cover_url = _COVER_TMPL.format(image_id=cover["image_id"])

    release_date: date | None = None
    if game.get("first_release_date"):
        release_date = datetime.fromtimestamp(
            game["first_release_date"], tz=timezone.utc
        ).date()

    platforms = game.get("platforms") or []
    platform_name = None
    if platforms and isinstance(platforms[0], dict):
        platform_name = platforms[0].get("name")

    genres = [g.get("name") for g in (game.get("genres") or []) if isinstance(g, dict)]

    return GameCandidate(
        title=game.get("name", "Unknown"),
        igdb_id=game.get("id"),
        platform_name=platform_name,
        cover_url=cover_url,
        summary=game.get("summary"),
        release_date=release_date,
        genres=genres or None,
        source=source,
        confidence=confidence,
    )


_FIELDS = (
    "fields name, summary, first_release_date, "
    "cover.image_id, genres.name, platforms.name;"
)


def search_games(query: str, limit: int = 10) -> list[GameCandidate]:
    """Free-text search against IGDB. Empty list if IGDB is not configured."""
    if not settings.igdb_enabled or not query.strip():
        return []
    with httpx.Client() as client:
        token = _get_token(client)
        # `search` ranks by relevance; escape embedded quotes.
        safe = query.replace('"', "")
        body = f'search "{safe}"; {_FIELDS} limit {limit};'
        resp = client.post(
            f"{_IGDB_BASE}/games", headers=_headers(token), content=body, timeout=15
        )
        resp.raise_for_status()
        return [_to_candidate(g) for g in resp.json()]


def get_game(igdb_id: int) -> GameCandidate | None:
    if not settings.igdb_enabled:
        return None
    with httpx.Client() as client:
        token = _get_token(client)
        body = f"{_FIELDS} where id = {int(igdb_id)};"
        resp = client.post(
            f"{_IGDB_BASE}/games", headers=_headers(token), content=body, timeout=15
        )
        resp.raise_for_status()
        rows = resp.json()
        return _to_candidate(rows[0], confidence=0.9) if rows else None
