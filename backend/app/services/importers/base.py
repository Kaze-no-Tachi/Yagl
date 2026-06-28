"""Importer connector interface + shared persistence (IGDB match + dedup).

Adding a new store is implementing `Importer.fetch_owned()` and returning a list
of `OwnedGame`; `persist_owned_games` handles IGDB enrichment, de-duplication,
and Item creation uniformly for every connector.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Protocol

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import Item, User
from app.schemas.imports import ImportResult
from app.services import igdb


@dataclass
class OwnedGame:
    title: str
    store_app_id: str | None = None
    platform_name: str | None = None
    extra: dict = field(default_factory=dict)


class Importer(Protocol):
    provider: str

    def fetch_owned(self) -> list[OwnedGame]:
        """Return the games owned in this store. May raise on auth/network errors."""


def persist_owned_games(
    db: Session,
    user: User,
    provider: str,
    owned: list[OwnedGame],
    default_format: str = "digital",
) -> ImportResult:
    created = 0
    skipped = 0
    unmatched: list[str] = []

    # Existing store_app_ids for this user+provider, for O(1) dedup.
    existing_app_ids = set(
        db.scalars(
            select(Item.store_app_id).where(
                Item.user_id == user.id,
                Item.source == provider,
                Item.store_app_id.is_not(None),
            )
        ).all()
    )
    # Fallback dedup by title for rows without a store_app_id.
    existing_titles = {
        t.lower()
        for t in db.scalars(
            select(Item.title).where(Item.user_id == user.id, Item.source == provider)
        ).all()
    }

    for game in owned:
        if game.store_app_id and game.store_app_id in existing_app_ids:
            skipped += 1
            continue
        if not game.store_app_id and game.title.lower() in existing_titles:
            skipped += 1
            continue

        match = None
        try:
            results = igdb.search_games(game.title, limit=1)
            match = results[0] if results else None
        except Exception:  # IGDB hiccup must not abort the whole import
            match = None
        if match is None:
            unmatched.append(game.title)

        item = Item(
            user_id=user.id,
            kind="game",
            format=default_format,
            title=match.title if match else game.title,
            source=provider,
            store_app_id=game.store_app_id,
            igdb_id=match.igdb_id if match else None,
            cover_url=match.cover_url if match else None,
            summary=match.summary if match else None,
            release_date=match.release_date if match else None,
            genres=match.genres if match else None,
            condition="digital" if default_format == "digital" else None,
        )
        db.add(item)
        created += 1
        if game.store_app_id:
            existing_app_ids.add(game.store_app_id)
        existing_titles.add(game.title.lower())

    db.commit()
    return ImportResult(
        provider=provider,
        fetched=len(owned),
        created=created,
        skipped_duplicates=skipped,
        unmatched=unmatched,
    )
