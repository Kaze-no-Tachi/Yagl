"""Seed the platforms table. Idempotent — safe to run on every startup."""
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import Platform

# (name, IGDB platform id). IGDB ids from https://api-docs.igdb.com/#platform
PLATFORMS: list[tuple[str, int | None]] = [
    ("PC (Microsoft Windows)", 6),
    ("Mac", 14),
    ("Linux", 3),
    ("Nintendo Entertainment System", 18),
    ("Super Nintendo", 19),
    ("Nintendo 64", 4),
    ("Nintendo GameCube", 21),
    ("Wii", 5),
    ("Wii U", 41),
    ("Nintendo Switch", 130),
    ("Nintendo Switch 2", None),
    ("Game Boy", 33),
    ("Game Boy Advance", 24),
    ("Nintendo DS", 20),
    ("Nintendo 3DS", 37),
    ("Sega Genesis/Mega Drive", 29),
    ("Sega Dreamcast", 23),
    ("PlayStation", 7),
    ("PlayStation 2", 8),
    ("PlayStation 3", 9),
    ("PlayStation 4", 48),
    ("PlayStation 5", 167),
    ("PlayStation Portable", 38),
    ("PlayStation Vita", 46),
    ("Xbox", 11),
    ("Xbox 360", 12),
    ("Xbox One", 49),
    ("Xbox Series X|S", 169),
    ("Atari 2600", 59),
]


def seed_platforms(db: Session) -> int:
    existing = set(db.scalars(select(Platform.name)).all())
    added = 0
    for name, igdb_id in PLATFORMS:
        if name not in existing:
            db.add(Platform(name=name, igdb_platform_id=igdb_id))
            added += 1
    if added:
        db.commit()
    return added
